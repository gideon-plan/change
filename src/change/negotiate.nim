## negotiate.nim -- Capability and sync exchange over SP REQREP.
##
## Before streaming changesets, sender and receiver negotiate:
## - Supported tiers (raw, delta, compact)
## - Schema version
## - Last known sequence number (for resume)

{.experimental: "strict_funcs".}

import std/strutils
import basis/code/choice
import framing

type
  Capability* = object
    tiers*: set[ChangeTier]
    schema_version*: int
    last_seq*: uint64

  NegotiateRequest* = object
    sender_caps*: Capability

  NegotiateResponse* = object
    accepted*: bool
    receiver_caps*: Capability
    resume_from*: uint64  ## sequence number to resume from

func encode_capability*(cap: Capability): seq[byte] =
  ## Encode capability to bytes: [tier_mask:1][schema:4][last_seq:8]
  result = newSeq[byte](13)
  var mask: byte = 0
  if tierRaw in cap.tiers: mask = mask or 1
  if tierDelta in cap.tiers: mask = mask or 2
  if tierCompact in cap.tiers: mask = mask or 4
  result[0] = mask
  let sv = uint32(cap.schema_version)
  result[1] = byte(sv shr 24)
  result[2] = byte(sv shr 16)
  result[3] = byte(sv shr 8)
  result[4] = byte(sv)
  for i in 0 ..< 8:
    result[5 + i] = byte(cap.last_seq shr ((7 - i) * 8))

func decode_capability*(data: openArray[byte]): Choice[Capability] =
  ## Decode capability from bytes.
  if data.len < 13:
    return bad[Capability]("change", "capability too short")
  var tiers: set[ChangeTier] = {}
  if (data[0] and 1) != 0: tiers.incl(tierRaw)
  if (data[0] and 2) != 0: tiers.incl(tierDelta)
  if (data[0] and 4) != 0: tiers.incl(tierCompact)
  let sv = (uint32(data[1]) shl 24) or (uint32(data[2]) shl 16) or
           (uint32(data[3]) shl 8) or uint32(data[4])
  var last_seq: uint64 = 0
  for i in 0 ..< 8:
    last_seq = (last_seq shl 8) or uint64(data[5 + i])
  good(Capability(tiers: tiers, schema_version: int(sv), last_seq: last_seq))

func negotiate*(sender, receiver: Capability): NegotiateResponse =
  ## Determine the negotiated parameters.
  let common_tiers = sender.tiers * receiver.tiers
  if common_tiers.len == 0:
    return NegotiateResponse(accepted: false, receiver_caps: receiver, resume_from: 0)
  let resume = max(sender.last_seq, receiver.last_seq)
  NegotiateResponse(
    accepted: true,
    receiver_caps: Capability(tiers: common_tiers,
                              schema_version: min(sender.schema_version, receiver.schema_version),
                              last_seq: resume),
    resume_from: resume
  )
