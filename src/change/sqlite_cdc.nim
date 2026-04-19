## sqlite_change.nim -- SQLite update hook -> SP publish.
{.experimental: "strict_funcs".}

import event
type SqliteHookFn* = proc(callback: proc(op: int, db, table: string, rowid: int64)) {.raises: [].}
proc sqlite_op_to_change*(op: int): changeOp =
  case op
  of 18: changeOp.ChangeInsert   # SQLITE_INSERT
  of 23: changeOp.ChangeUpdate   # SQLITE_UPDATE
  of 9: changeOp.ChangeDelete    # SQLITE_DELETE
  else: changeOp.ChangeInsert
