## framing.nim -- Tier envelope for CDC messages.
##
## Each CDC message is wrapped in a tier envelope that indicates
## the transport tier and message type.

{.experimental: "strict_funcs".}

import basis/code/choice

type
  CdcTier* = enum
    tierRaw = 0       ## Raw changeset blob
    tierDelta = 1     ## Delta-encoded changeset
    tierCompact = 2   ## Compacted (multiple changesets merged)

  CdcFrameKind* = enum
    fkChangeset = 1   ## Changeset data
    fkAck = 2         ## Acknowledgement
    fkNack = 3        ## Negative acknowledgement
    fkSync = 4        ## Sync request
    fkPing = 5        ## Keepalive

  CdcFrame* = object
    tier*: CdcTier
    kind*: CdcFrameKind
    seq_no*: uint64
    payload*: seq[byte]

proc encode_frame*(frame: CdcFrame): seq[byte] =
  ## Encode a CDC frame to bytes: [tier:1][kind:1][seq_no:8][len:4][payload]
  result = newSeq[byte](14 + frame.payload.len)
  result[0] = byte(frame.tier)
  result[1] = byte(frame.kind)
  for i in 0 ..< 8:
    result[2 + i] = byte(frame.seq_no shr ((7 - i) * 8))
  let plen = uint32(frame.payload.len)
  result[10] = byte(plen shr 24)
  result[11] = byte(plen shr 16)
  result[12] = byte(plen shr 8)
  result[13] = byte(plen)
  for i, b in frame.payload:
    result[14 + i] = b

proc decode_frame*(data: openArray[byte]): Choice[CdcFrame] =
  ## Decode a CDC frame from bytes.
  if data.len < 14:
    return bad[CdcFrame]("dbcdc", "frame too short: " & $data.len)
  let tier = CdcTier(data[0])
  let kind = CdcFrameKind(data[1])
  var seq_no: uint64 = 0
  for i in 0 ..< 8:
    seq_no = (seq_no shl 8) or uint64(data[2 + i])
  let plen = (uint32(data[10]) shl 24) or (uint32(data[11]) shl 16) or
             (uint32(data[12]) shl 8) or uint32(data[13])
  if data.len < 14 + int(plen):
    return bad[CdcFrame]("dbcdc", "frame payload truncated")
  var payload = newSeq[byte](plen)
  for i in 0 ..< int(plen):
    payload[i] = data[14 + i]
  good(CdcFrame(tier: tier, kind: kind, seq_no: seq_no, payload: payload))
