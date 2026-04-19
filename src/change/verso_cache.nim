## verso_cache.nim -- Valkey changeset cache via verso/valkey_store.
{.experimental: "strict_funcs".}

import basis/code/verso

type
  ChangesetEntry* = object
    source_db*: string
    table_name*: string
    changeset_id*: string
    mutation*: Mutation

proc changeset_to_mutation*(source_db, table_name, changeset_id: string,
                            changes: seq[(string, string)], ts: int64): Mutation =
  var deltas: seq[Delta] = @[]
  for (col, val) in changes:
    deltas.add(delta_add(col, val))
  var m = Mutation(parent: "", actor: source_db, created: ts,
    plan_version: 1, space: "home", partition: Partition.Data,
    entities: @[entity(table_name, changeset_id)],
    deltas: deltas)
  stamp(m)
  m

proc cache_entry*(source_db, table_name, changeset_id: string,
                  changes: seq[(string, string)], ts: int64): ChangesetEntry =
  ChangesetEntry(
    source_db: source_db, table_name: table_name,
    changeset_id: changeset_id,
    mutation: changeset_to_mutation(source_db, table_name, changeset_id, changes, ts),
  )
