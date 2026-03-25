## event.nim -- CDC event types.
{.experimental: "strict_funcs".}
import std/tables
type
  CdcOp* = enum
    cdcInsert, cdcUpdate, cdcDelete
  CdcEvent* = object
    op*: CdcOp
    db*: string
    table_name*: string
    row_key*: string
    old_values*: Table[string, string]
    new_values*: Table[string, string]
proc insert_event*(db, table, key: string, values: Table[string, string]): CdcEvent =
  CdcEvent(op: cdcInsert, db: db, table_name: table, row_key: key, new_values: values)
proc update_event*(db, table, key: string, old_vals, new_vals: Table[string, string]): CdcEvent =
  CdcEvent(op: cdcUpdate, db: db, table_name: table, row_key: key, old_values: old_vals, new_values: new_vals)
proc delete_event*(db, table, key: string): CdcEvent =
  CdcEvent(op: cdcDelete, db: db, table_name: table, row_key: key)
