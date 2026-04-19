## sp_binding.nim -- SP PUBSUB/REQREP/PUSH binding for change.
##
## Maps change operations onto SP topology patterns:
## - REQREP: negotiate, sync, ack
## - PUBSUB: changeset broadcast
## - PUSH: one-way changeset delivery

{.experimental: "strict_funcs".}

import basis/code/choice
import framing, negotiate

type
  HydraBindKind* {.pure.} = enum
    PubSub    ## Fan-out broadcast
    ReqRep    ## Request-response (negotiate, ack)
    Push      ## One-way delivery

  HydraChangeBinding* = object
    kind*: HydraBindKind
    endpoint*: string
    active*: bool

func new_pubsub_binding*(endpoint: string): HydraChangeBinding =
  HydraChangeBinding(kind: HydraBindKind.PubSub, endpoint: endpoint, active: false)

func new_reqrep_binding*(endpoint: string): HydraChangeBinding =
  HydraChangeBinding(kind: HydraBindKind.ReqRep, endpoint: endpoint, active: false)

func new_push_binding*(endpoint: string): HydraChangeBinding =
  HydraChangeBinding(kind: HydraBindKind.Push, endpoint: endpoint, active: false)

func make_negotiate_frame*(caps: Capability): ChangeFrame =
  ## Build a negotiate request frame.
  ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Sync, seq_no: 0,
           payload: encode_capability(caps))

func make_ack_frame*(seq_no: uint64): ChangeFrame =
  ## Build an ack frame for a given sequence number.
  ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Ack, seq_no: seq_no, payload: @[])

func make_nack_frame*(seq_no: uint64): ChangeFrame =
  ## Build a negative ack frame.
  ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Nack, seq_no: seq_no, payload: @[])

func make_changeset_frame*(tier: ChangeTier, seq_no: uint64, data: seq[byte]): ChangeFrame =
  ## Build a changeset data frame.
  ChangeFrame(tier: tier, kind: ChangeFrameKind.Changeset, seq_no: seq_no, payload: data)
