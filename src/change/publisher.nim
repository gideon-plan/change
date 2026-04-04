## publisher.nim -- Generic change event -> SP PUBSUB frame.
{.experimental: "strict_funcs".}
import std/[strutils, tables]
import basis/code/choice, event
type SpPublishFn* = proc(topic, payload: string): Choice[bool] {.raises: [].}
proc change_topic*(event: ChangeEvent): string =
  "change/" & event.db & "/" & event.table_name
proc encode_event*(event: ChangeEvent): string =
  var lines: seq[string]
  lines.add("op=" & $event.op)
  lines.add("key=" & event.row_key)
  for k, v in event.new_values: lines.add(k & "=" & v)
  lines.join("\n")
proc publish_event*(pub_fn: SpPublishFn, event: ChangeEvent): Choice[bool] =
  pub_fn(change_topic(event), encode_event(event))
