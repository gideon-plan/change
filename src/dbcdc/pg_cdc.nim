## pg_cdc.nim -- PostgreSQL LISTEN/NOTIFY -> SP publish.
{.experimental: "strict_funcs".}
import std/strutils
import lattice, event
type
  PgNotification* = object
    channel*: string
    payload*: string
proc parse_pg_notify*(notif: PgNotification): Result[CdcEvent, BridgeError] =
  let parts = notif.payload.split("|")
  if parts.len < 3:
    return Result[CdcEvent, BridgeError].bad(BridgeError(msg: "invalid pg notify"))
  let op = case parts[0]
    of "INSERT": cdcInsert
    of "UPDATE": cdcUpdate
    of "DELETE": cdcDelete
    else: cdcInsert
  Result[CdcEvent, BridgeError].good(
    CdcEvent(op: op, db: "postgres", table_name: parts[1], row_key: parts[2]))
