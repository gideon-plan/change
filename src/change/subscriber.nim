## subscriber.nim -- SP subscriber dispatching CDC events.
{.experimental: "strict_funcs".}
import std/[strutils, tables]
import basis/code/choice, event
type
  CdcHandler* = proc(event: CdcEvent) {.raises: [].}
proc parse_event*(topic, payload: string): Choice[CdcEvent] =
  let parts = topic.split("/")
  if parts.len < 3:
    return bad[CdcEvent]("dbcdc", "invalid topic: " & topic)
  let db = parts[1]
  let table = parts[2]
  var op = cdcInsert
  var key = ""
  var values: Table[string, string]
  for line in payload.splitLines():
    let eq = line.find('=')
    if eq > 0:
      let k = line[0 ..< eq]
      let v = line[eq+1 ..< line.len]
      if k == "op":
        case v
        of "cdcInsert": op = cdcInsert
        of "cdcUpdate": op = cdcUpdate
        of "cdcDelete": op = cdcDelete
        else: discard
      elif k == "key": key = v
      else: values[k] = v
  good(
    CdcEvent(op: op, db: db, table_name: table, row_key: key, new_values: values))
