## replay.nim -- Apply changeset/RBU to target SQLite.
##
## Takes a decoded Changeset and generates SQL to replay it against
## a target database. Supports both direct apply and RBU staging.

{.experimental: "strict_funcs".}

import std/strutils
import basis/code/choice

type
  ReplayMode* {.pure.} = enum
    Direct   ## Generate INSERT/UPDATE/DELETE SQL directly
    Rbu      ## Generate RBU staging database SQL

  ReplayStatement* = object
    sql*: string

func quote_sql(s: string): string =
  "'" & s.replace("'", "''") & "'"

func replay_insert*(table: string, col_names: seq[string], values: seq[string]): ReplayStatement =
  ## Generate INSERT SQL.
  var sql = "INSERT INTO " & table & " ("
  for i, name in col_names:
    if i > 0: sql.add(", ")
    sql.add(name)
  sql.add(") VALUES (")
  for i, v in values:
    if i > 0: sql.add(", ")
    sql.add(v)
  sql.add(")")
  ReplayStatement(sql: sql)

func replay_delete*(table: string, pk_names, pk_values: seq[string]): ReplayStatement =
  ## Generate DELETE SQL using primary key.
  var sql = "DELETE FROM " & table & " WHERE "
  for i in 0 ..< pk_names.len:
    if i > 0: sql.add(" AND ")
    sql.add(pk_names[i] & " = " & pk_values[i])
  ReplayStatement(sql: sql)

func replay_update*(table: string, pk_names, pk_values: seq[string],
                    set_names, set_values: seq[string]): ReplayStatement =
  ## Generate UPDATE SQL.
  var sql = "UPDATE " & table & " SET "
  for i in 0 ..< set_names.len:
    if i > 0: sql.add(", ")
    sql.add(set_names[i] & " = " & set_values[i])
  sql.add(" WHERE ")
  for i in 0 ..< pk_names.len:
    if i > 0: sql.add(" AND ")
    sql.add(pk_names[i] & " = " & pk_values[i])
  ReplayStatement(sql: sql)

func wrap_transaction*(statements: seq[ReplayStatement]): seq[ReplayStatement] =
  ## Wrap statements in BEGIN/COMMIT.
  var result_stmts: seq[ReplayStatement] = @[]
  result_stmts.add(ReplayStatement(sql: "BEGIN"))
  for s in statements:
    result_stmts.add(s)
  result_stmts.add(ReplayStatement(sql: "COMMIT"))
  result_stmts
