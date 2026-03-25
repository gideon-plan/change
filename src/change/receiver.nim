## receiver.nim -- Tier dispatcher.
##
## Routes incoming CDC frames to the appropriate handler based on tier.

{.experimental: "strict_funcs".}

import basis/code/choice
import framing

type
  TierHandler* = proc(frame: CdcFrame): Choice[bool] {.raises: [].}

  CdcReceiver* = object
    handlers*: array[CdcTier, TierHandler]

proc init_receiver*(): CdcReceiver =
  discard  # handlers default to nil

proc set_handler*(recv: var CdcReceiver, tier: CdcTier, handler: TierHandler) =
  recv.handlers[tier] = handler

proc dispatch*(recv: CdcReceiver, data: openArray[byte]): Choice[bool] =
  ## Decode a frame and dispatch to the appropriate tier handler.
  let frame = decode_frame(data)
  if frame.is_bad: return bad[bool](frame.err)
  let handler = recv.handlers[frame.val.tier]
  if handler == nil:
    return bad[bool]("dbcdc", "no handler for tier " & $frame.val.tier)
  handler(frame.val)
