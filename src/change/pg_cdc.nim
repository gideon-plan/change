## pg_change.nim -- PostgreSQL LISTEN/NOTIFY -> SP publish.
{.experimental: "strict_funcs".}
import std/strutils
import basis/code/choice, event

type
  PgNotification* = object
    channel*: string
    payload*: string

proc parse_pg_notify*(notif: PgNotification): Choice[ChangeEvent] =
  let parts = notif.payload.split("|")
  if parts.len < 3:
    return bad[ChangeEvent]("change", "invalid pg notify")
  let op = case parts[0]
    of "INSERT": changeOp.ChangeInsert
    of "UPDATE": changeOp.ChangeUpdate
    of "DELETE": changeOp.ChangeDelete
    else: changeOp.ChangeInsert
  good(
    ChangeEvent(op: op, db: "postgres", table_name: parts[1], row_key: parts[2]))
