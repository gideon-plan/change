## publisher.nim -- Generic CDC event -> SP PUBSUB frame.
{.experimental: "strict_funcs".}
import std/[strutils, tables]
import lattice, event
type SpPublishFn* = proc(topic, payload: string): Result[void, BridgeError] {.raises: [].}
proc cdc_topic*(event: CdcEvent): string =
  "cdc/" & event.db & "/" & event.table_name
proc encode_event*(event: CdcEvent): string =
  var lines: seq[string]
  lines.add("op=" & $event.op)
  lines.add("key=" & event.row_key)
  for k, v in event.new_values: lines.add(k & "=" & v)
  lines.join("\n")
proc publish_event*(pub_fn: SpPublishFn, event: CdcEvent): Result[void, BridgeError] =
  pub_fn(cdc_topic(event), encode_event(event))
