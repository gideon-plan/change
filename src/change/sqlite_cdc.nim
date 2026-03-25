## sqlite_cdc.nim -- SQLite update hook -> SP publish.
{.experimental: "strict_funcs".}

import event
type SqliteHookFn* = proc(callback: proc(op: int, db, table: string, rowid: int64)) {.raises: [].}
proc sqlite_op_to_cdc*(op: int): CdcOp =
  case op
  of 18: cdcInsert   # SQLITE_INSERT
  of 23: cdcUpdate   # SQLITE_UPDATE
  of 9: cdcDelete    # SQLITE_DELETE
  else: cdcInsert
