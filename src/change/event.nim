## event.nim -- change event types.
{.experimental: "strict_funcs".}
import std/tables
type
  changeOp* = enum
    changeOp.ChangeInsert, changeOp.ChangeUpdate, changeOp.ChangeDelete
  ChangeEvent* = object
    op*: changeOp
    db*: string
    table_name*: string
    row_key*: string
    old_values*: Table[string, string]
    new_values*: Table[string, string]
proc insert_event*(db, table, key: string, values: Table[string, string]): ChangeEvent =
  ChangeEvent(op: changeOp.ChangeInsert, db: db, table_name: table, row_key: key, new_values: values)
proc update_event*(db, table, key: string, old_vals, new_vals: Table[string, string]): ChangeEvent =
  ChangeEvent(op: changeOp.ChangeUpdate, db: db, table_name: table, row_key: key, old_values: old_vals, new_values: new_vals)
proc delete_event*(db, table, key: string): ChangeEvent =
  ChangeEvent(op: changeOp.ChangeDelete, db: db, table_name: table, row_key: key)
