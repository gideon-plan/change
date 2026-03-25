## Tests for CDC pipeline: framing, chunking, cache, receiver.

import std/unittest
import dbcdc/framing
import dbcdc/chunking
import dbcdc/cache
import dbcdc/receiver
import basis/code/choice

# =====================================================================================================================
# framing
# =====================================================================================================================

suite "framing":
  test "encode/decode round-trip":
    let frame = CdcFrame(tier: tierRaw, kind: fkChangeset, seq_no: 42,
                         payload: @[1'u8, 2, 3, 4, 5])
    let encoded = encode_frame(frame)
    let decoded = decode_frame(encoded)
    check decoded.is_good
    check decoded.val.tier == tierRaw
    check decoded.val.kind == fkChangeset
    check decoded.val.seq_no == 42
    check decoded.val.payload == @[1'u8, 2, 3, 4, 5]

  test "empty payload":
    let frame = CdcFrame(tier: tierDelta, kind: fkAck, seq_no: 1, payload: @[])
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
    let frame = CdcFrame(tier: tierRaw, kind: fkChangeset, seq_no: 1,
                         payload: @[1'u8, 2, 3])
    let chunks = split_frame(frame)
    check chunks.len == 1
    check chunks[0].total_chunks == 1

  test "reassemble single chunk":
    let frame = CdcFrame(tier: tierRaw, kind: fkChangeset, seq_no: 1,
                         payload: @[10'u8, 20, 30])
    let chunks = split_frame(frame)
    let result = reassemble_chunks(chunks)
    check result.is_good
    check result.val.seq_no == 1
    check result.val.payload == @[10'u8, 20, 30]

  test "large frame splits and reassembles":
    var payload = newSeq[byte](200)
    for i in 0 ..< 200: payload[i] = byte(i mod 256)
    let frame = CdcFrame(tier: tierRaw, kind: fkChangeset, seq_no: 99, payload: payload)
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
    recv.set_handler(tierRaw, proc(f: CdcFrame): Choice[bool] {.raises: [].} =
      received_seq = f.seq_no
      good(true)
    )
    let frame = CdcFrame(tier: tierRaw, kind: fkChangeset, seq_no: 42, payload: @[])
    let encoded = encode_frame(frame)
    let result = recv.dispatch(encoded)
    check result.is_good
    check received_seq == 42

  test "no handler returns bad":
    let recv = init_receiver()
    let frame = CdcFrame(tier: tierDelta, kind: fkChangeset, seq_no: 1, payload: @[])
    let encoded = encode_frame(frame)
    let result = recv.dispatch(encoded)
    check result.is_bad
