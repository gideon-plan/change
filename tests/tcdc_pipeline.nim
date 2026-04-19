{.experimental: "strictFuncs".}
## Tests for change pipeline: framing, chunking, cache, receiver.

import std/[unittest, strutils]
import change/framing
import change/chunking
import change/cache
import change/receiver
import basis/code/choice

# =====================================================================================================================
# framing
# =====================================================================================================================

suite "framing":
  test "encode/decode round-trip":
    let frame = ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: 42,
                         payload: @[1'u8, 2, 3, 4, 5])
    let encoded = encode_frame(frame)
    let decoded = decode_frame(encoded)
    check decoded.is_good
    check decoded.val.tier == ChangeTier.Raw
    check decoded.val.kind == ChangeFrameKind.Changeset
    check decoded.val.seq_no == 42
    check decoded.val.payload == @[1'u8, 2, 3, 4, 5]

  test "empty payload":
    let frame = ChangeFrame(tier: ChangeTier.Delta, kind: ChangeFrameKind.Ack, seq_no: 1, payload: @[])
    let encoded = encode_frame(frame)
    let decoded = decode_frame(encoded)
    check decoded.is_good
    check decoded.val.payload.len == 0

  test "truncated frame returns bad":
    let result = decode_frame(@[0'u8, 1, 2])
    check result.is_bad

# =====================================================================================================================
# chunking
# =====================================================================================================================

suite "chunking":
  test "small frame produces single chunk":
    let frame = ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: 1,
                         payload: @[1'u8, 2, 3])
    let chunks = split_frame(frame)
    check chunks.len == 1
    check chunks[0].total_chunks == 1

  test "reassemble single chunk":
    let frame = ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: 1,
                         payload: @[10'u8, 20, 30])
    let chunks = split_frame(frame)
    let result = reassemble_chunks(chunks)
    check result.is_good
    check result.val.seq_no == 1
    check result.val.payload == @[10'u8, 20, 30]

  test "large frame splits and reassembles":
    var payload = newSeq[byte](200)
    for i in 0 ..< 200: payload[i] = byte(i mod 256)
    let frame = ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: 99, payload: payload)
    let chunks = split_frame(frame, max_size = 100)
    check chunks.len > 1
    let result = reassemble_chunks(chunks)
    check result.is_good
    check result.val.seq_no == 99
    check result.val.payload == payload

# =====================================================================================================================
# cache
# =====================================================================================================================

suite "cache":
  test "put and get":
    var c = init_cache(10)
    c.put(1, @[1'u8, 2, 3])
    let r = c.get(1)
    check r.is_good
    check r.val == @[1'u8, 2, 3]

  test "get missing returns none":
    let c = init_cache(10)
    check c.get(99).is_none

  test "eviction on capacity":
    var c = init_cache(2)
    c.put(1, @[1'u8])
    c.put(2, @[2'u8])
    c.put(3, @[3'u8])  # evicts seq 1
    check c.get(1).is_none
    check c.get(2).is_good
    check c.get(3).is_good

  test "latest":
    var c = init_cache(10)
    c.put(5, @[5'u8])
    c.put(10, @[10'u8])
    let r = c.latest()
    check r.is_good
    check r.val.seq_no == 10

  test "evict before seq":
    var c = init_cache(10)
    c.put(1, @[1'u8])
    c.put(5, @[5'u8])
    c.put(10, @[10'u8])
    c.evict(6)
    check c.get(1).is_none
    check c.get(5).is_none
    check c.get(10).is_good

# =====================================================================================================================
# receiver
# =====================================================================================================================

suite "receiver":
  test "dispatch to handler":
    var received_seq: uint64 = 0
    var recv = init_receiver()
    recv.set_handler(ChangeTier.Raw, proc(f: ChangeFrame): Choice[bool] {.raises: [].} =
      received_seq = f.seq_no
      good(true)
    )
    let frame = ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: 42, payload: @[])
    let encoded = encode_frame(frame)
    let result = recv.dispatch(encoded)
    check result.is_good
    check received_seq == 42

  test "no handler returns bad":
    let recv = init_receiver()
    let frame = ChangeFrame(tier: ChangeTier.Delta, kind: ChangeFrameKind.Changeset, seq_no: 1, payload: @[])
    let encoded = encode_frame(frame)
    let result = recv.dispatch(encoded)
    check result.is_bad

# =====================================================================================================================
# negotiate
# =====================================================================================================================

import change/negotiate

suite "negotiate":
  test "encode/decode capability round-trip":
    let cap = Capability(tiers: {ChangeTier.Raw, ChangeTier.Delta}, schema_version: 3, last_seq: 42)
    let encoded = encode_capability(cap)
    let decoded = decode_capability(encoded)
    check decoded.is_good
    check ChangeTier.Raw in decoded.val.tiers
    check ChangeTier.Delta in decoded.val.tiers
    check ChangeTier.Compact notin decoded.val.tiers
    check decoded.val.schema_version == 3
    check decoded.val.last_seq == 42

  test "negotiate common tiers":
    let sender = Capability(tiers: {ChangeTier.Raw, ChangeTier.Delta}, schema_version: 2, last_seq: 10)
    let receiver = Capability(tiers: {ChangeTier.Delta, ChangeTier.Compact}, schema_version: 3, last_seq: 5)
    let resp = negotiate(sender, receiver)
    check resp.accepted
    check ChangeTier.Delta in resp.receiver_caps.tiers
    check resp.resume_from == 10

  test "negotiate no common tiers":
    let sender = Capability(tiers: {ChangeTier.Raw}, schema_version: 1, last_seq: 0)
    let receiver = Capability(tiers: {ChangeTier.Compact}, schema_version: 1, last_seq: 0)
    let resp = negotiate(sender, receiver)
    check not resp.accepted

# =====================================================================================================================
# sp_binding
# =====================================================================================================================

import change/sp_binding

suite "sp_binding":
  test "make negotiate frame":
    let cap = Capability(tiers: {ChangeTier.Raw}, schema_version: 1, last_seq: 0)
    let frame = make_negotiate_frame(cap)
    check frame.kind == ChangeFrameKind.Sync
    check frame.payload.len == 13

  test "make ack frame":
    let frame = make_ack_frame(42)
    check frame.kind == ChangeFrameKind.Ack
    check frame.seq_no == 42

  test "make changeset frame":
    let frame = make_changeset_frame(ChangeTier.Delta, 10, @[1'u8, 2, 3])
    check frame.tier == ChangeTier.Delta
    check frame.kind == ChangeFrameKind.Changeset
    check frame.seq_no == 10
    check frame.payload == @[1'u8, 2, 3]

# =====================================================================================================================
# changeset_change
# =====================================================================================================================

import change/changeset_change

suite "changeset_change":
  test "publish and cache":
    var pub = init_changeset_publisher("tcp://localhost:9000")
    let data = @[10'u8, 20, 30]
    let result = pub.publish_changeset(data)
    check result.is_good
    check result.val.seq_no == 1
    check result.val.payload == data
    let cached = pub.get_cached(1)
    check cached.is_good
    check cached.val == data

  test "sequence increments":
    var pub = init_changeset_publisher("tcp://localhost:9000")
    discard pub.publish_changeset(@[1'u8])
    let r2 = pub.publish_changeset(@[2'u8])
    check r2.is_good
    check r2.val.seq_no == 2

# =====================================================================================================================
# delta_compress
# =====================================================================================================================

import change/delta_compress

suite "delta_compress":
  test "first message emits raw":
    var dc = init_compressor()
    let r = dc.compress(1, @[1'u8, 2, 3], proc(s, t: seq[byte]): string = "delta")
    check r.is_good
    check r.val.tier == ChangeTier.Raw

  test "second message uses delta if smaller":
    var dc = init_compressor()
    let big = newSeq[byte](100)
    discard dc.compress(1, big, proc(s, t: seq[byte]): string = "small")
    let r = dc.compress(2, big, proc(s, t: seq[byte]): string = "small")
    check r.is_good
    check r.val.tier == ChangeTier.Delta

  test "falls back to raw if delta is larger":
    var dc = init_compressor()
    let small = @[1'u8, 2]
    discard dc.compress(1, small, proc(s, t: seq[byte]): string = "this delta is much larger than the original data!!!")
    let r = dc.compress(2, small, proc(s, t: seq[byte]): string = "this delta is much larger than the original data!!!")
    check r.is_good
    check r.val.tier == ChangeTier.Raw

# =====================================================================================================================
# replay
# =====================================================================================================================

import change/replay

suite "replay":
  test "replay insert":
    let stmt = replay_insert("users", @["id", "name"], @["1", "'alice'"])
    check stmt.sql.contains("INSERT INTO users")
    check stmt.sql.contains("1, 'alice'")

  test "replay delete":
    let stmt = replay_delete("users", @["id"], @["1"])
    check stmt.sql.contains("DELETE FROM users")
    check stmt.sql.contains("id = 1")

  test "replay update":
    let stmt = replay_update("users", @["id"], @["1"], @["name"], @["'bob'"])
    check stmt.sql.contains("UPDATE users SET")
    check stmt.sql.contains("name = 'bob'")
    check stmt.sql.contains("id = 1")

  test "wrap transaction":
    let stmts = wrap_transaction(@[
      ReplayStatement(sql: "INSERT INTO t VALUES(1)"),
      ReplayStatement(sql: "INSERT INTO t VALUES(2)"),
    ])
    check stmts.len == 4
    check stmts[0].sql == "BEGIN"
    check stmts[3].sql == "COMMIT"
