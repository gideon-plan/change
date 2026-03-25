## pg_cdc.nim -- PostgreSQL LISTEN/NOTIFY -> SP publish.
{.experimental: "strict_funcs".}
import std/strutils
import basis/code/choice, event
type
  PgNotification* = object
    channel*: string
    payload*: string
proc parse_pg_notify*(notif: PgNotification): Choice[CdcEvent] =
  let parts = notif.payload.split("|")
  if parts.len < 3:
    return bad[CdcEvent]("dbcdc", "invalid pg notify")
  let op = case parts[0]
    of "INSERT": cdcInsert
    of "UPDATE": cdcUpdate
    of "DELETE": cdcDelete
    else: cdcInsert
  good(
    CdcEvent(op: op, db: "postgres", table_name: parts[1], row_key: parts[2]))
