## sp_binding.nim -- SP PUBSUB/REQREP/PUSH binding for CDC.
##
## Maps CDC operations onto SP topology patterns:
## - REQREP: negotiate, sync, ack
## - PUBSUB: changeset broadcast
## - PUSH: one-way changeset delivery

{.experimental: "strict_funcs".}

import basis/code/choice
import framing, negotiate

type
  SpBindingKind* = enum
    sbkPubSub    ## Fan-out broadcast
    sbkReqRep    ## Request-response (negotiate, ack)
    sbkPush      ## One-way delivery

  SpCdcBinding* = object
    kind*: SpBindingKind
    endpoint*: string
    active*: bool

func new_pubsub_binding*(endpoint: string): SpCdcBinding =
  SpCdcBinding(kind: sbkPubSub, endpoint: endpoint, active: false)

func new_reqrep_binding*(endpoint: string): SpCdcBinding =
  SpCdcBinding(kind: sbkReqRep, endpoint: endpoint, active: false)

func new_push_binding*(endpoint: string): SpCdcBinding =
  SpCdcBinding(kind: sbkPush, endpoint: endpoint, active: false)

func make_negotiate_frame*(caps: Capability): CdcFrame =
  ## Build a negotiate request frame.
  CdcFrame(tier: tierRaw, kind: fkSync, seq_no: 0,
           payload: encode_capability(caps))

func make_ack_frame*(seq_no: uint64): CdcFrame =
  ## Build an ack frame for a given sequence number.
  CdcFrame(tier: tierRaw, kind: fkAck, seq_no: seq_no, payload: @[])

func make_nack_frame*(seq_no: uint64): CdcFrame =
  ## Build a negative ack frame.
  CdcFrame(tier: tierRaw, kind: fkNack, seq_no: seq_no, payload: @[])

func make_changeset_frame*(tier: CdcTier, seq_no: uint64, data: seq[byte]): CdcFrame =
  ## Build a changeset data frame.
  CdcFrame(tier: tier, kind: fkChangeset, seq_no: seq_no, payload: data)
