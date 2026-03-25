{.experimental: "strict_funcs".}
import std/[unittest, strutils, tables]
import change
suite "event":
  test "create insert event":
    let e = insert_event("sqlite", "users", "1", {"name": "alice"}.toTable)
    check e.op == cdcInsert
    check e.table_name == "users"
suite "publisher":
  test "cdc topic":
    let e = insert_event("pg", "orders", "42", initTable[string, string]())
    check cdc_topic(e) == "cdc/pg/orders"
  test "encode event":
    let e = insert_event("pg", "t", "1", {"x": "2"}.toTable)
    let enc = encode_event(e)
    check enc.contains("op=cdcInsert")
    check enc.contains("key=1")
suite "subscriber":
  test "parse event":
    let r = parse_event("cdc/pg/users", "op=cdcInsert\nkey=1\nname=alice")
    check r.is_good
    check r.val.db == "pg"
    check r.val.table_name == "users"
    check r.val.row_key == "1"
suite "sqlite_cdc":
  test "op mapping":
    check sqlite_op_to_cdc(18) == cdcInsert
    check sqlite_op_to_cdc(23) == cdcUpdate
    check sqlite_op_to_cdc(9) == cdcDelete
suite "pg_cdc":
  test "parse pg notify":
    let r = parse_pg_notify(PgNotification(channel: "changes", payload: "INSERT|users|42"))
    check r.is_good
    check r.val.op == cdcInsert
    check r.val.table_name == "users"
