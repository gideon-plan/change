## receiver.nim -- Tier dispatcher.
##
## Routes incoming change frames to the appropriate handler based on tier.

{.experimental: "strict_funcs".}

import basis/code/choice
import framing

type
  TierHandler* = proc(frame: ChangeFrame): Choice[bool] {.raises: [].}

  changeReceiver* = object
    handlers*: array[ChangeTier, TierHandler]

proc init_receiver*(): changeReceiver =
  discard  # handlers default to nil

proc set_handler*(recv: var changeReceiver, tier: ChangeTier, handler: TierHandler) =
  recv.handlers[tier] = handler

proc dispatch*(recv: changeReceiver, data: openArray[byte]): Choice[bool] =
  ## Decode a frame and dispatch to the appropriate tier handler.
  let frame = decode_frame(data)
  if frame.is_bad: return bad[bool](frame.err)
  let handler = recv.handlers[frame.val.tier]
  if handler == nil:
    return bad[bool]("change", "no handler for tier " & $frame.val.tier)
  handler(frame.val)
