## subscriber.nim -- SP subscriber dispatching change events.
{.experimental: "strict_funcs".}
import std/[strutils, tables]
import basis/code/choice, event
type
  changeHandler* = proc(event: ChangeEvent) {.raises: [].}
proc parse_event*(topic, payload: string): Choice[ChangeEvent] =
  let parts = topic.split("/")
  if parts.len < 3:
    return bad[ChangeEvent]("change", "invalid topic: " & topic)
  let db = parts[1]
  let table = parts[2]
  var op = changeOp.ChangeInsert
  var key = ""
  var values: Table[string, string]
  for line in payload.splitLines():
    let eq = line.find('=')
    if eq > 0:
      let k = line[0 ..< eq]
      let v = line[eq+1 ..< line.len]
      if k == "op":
        case v
        of "changeOp.ChangeInsert": op = changeOp.ChangeInsert
        of "changeOp.ChangeUpdate": op = changeOp.ChangeUpdate
        of "changeOp.ChangeDelete": op = changeOp.ChangeDelete
        else: discard
      elif k == "key": key = v
      else: values[k] = v
  good(
    ChangeEvent(op: op, db: db, table_name: table, row_key: key, new_values: values))
