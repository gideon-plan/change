{.experimental: "strict_funcs".}
import std/[unittest, strutils, tables]
import change
suite "event":
  test "create insert event":
    let e = insert_event("sqlite", "users", "1", {"name": "alice"}.toTable)
    check e.op == changeOp.ChangeInsert
    check e.table_name == "users"
suite "publisher":
  test "change topic":
    let e = insert_event("pg", "orders", "42", initTable[string, string]())
    check change_topic(e) == "change/pg/orders"
  test "encode event":
    let e = insert_event("pg", "t", "1", {"x": "2"}.toTable)
    let enc = encode_event(e)
    check enc.contains("op=changeOp.ChangeInsert")
    check enc.contains("key=1")
suite "subscriber":
  test "parse event":
    let r = parse_event("change/pg/users", "op=changeOp.ChangeInsert\nkey=1\nname=alice")
    check r.is_good
    check r.val.db == "pg"
    check r.val.table_name == "users"
    check r.val.row_key == "1"
suite "sqlite_change":
  test "op mapping":
    check sqlite_op_to_change(18) == changeOp.ChangeInsert
    check sqlite_op_to_change(23) == changeOp.ChangeUpdate
    check sqlite_op_to_change(9) == changeOp.ChangeDelete
suite "pg_change":
  test "parse pg notify":
    let r = parse_pg_notify(PgNotification(channel: "changes", payload: "INSERT|users|42"))
    check r.is_good
    check r.val.op == changeOp.ChangeInsert
    check r.val.table_name == "users"
