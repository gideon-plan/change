{.experimental: "strict_funcs".}
import std/[unittest, strutils, tables]
import change
suite "event":
  test "create insert event":
    let e = insert_event("sqlite", "users", "1", {"name": "alice"}.toTable)
    check e.op == changeInsert
    check e.table_name == "users"
suite "publisher":
  test "change topic":
    let e = insert_event("pg", "orders", "42", initTable[string, string]())
    check change_topic(e) == "change/pg/orders"
  test "encode event":
    let e = insert_event("pg", "t", "1", {"x": "2"}.toTable)
    let enc = encode_event(e)
    check enc.contains("op=changeInsert")
    check enc.contains("key=1")
suite "subscriber":
  test "parse event":
    let r = parse_event("change/pg/users", "op=changeInsert\nkey=1\nname=alice")
    check r.is_good
    check r.val.db == "pg"
    check r.val.table_name == "users"
    check r.val.row_key == "1"
suite "sqlite_change":
  test "op mapping":
    check sqlite_op_to_change(18) == changeInsert
    check sqlite_op_to_change(23) == changeUpdate
    check sqlite_op_to_change(9) == changeDelete
suite "pg_change":
  test "parse pg notify":
    let r = parse_pg_notify(PgNotification(channel: "changes", payload: "INSERT|users|42"))
    check r.is_good
    check r.val.op == changeInsert
    check r.val.table_name == "users"
