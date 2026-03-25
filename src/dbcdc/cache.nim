## cache.nim -- Sender-side changeset cache.
##
## Keeps recent changesets for delta encoding against subsequent ones.

{.experimental: "strict_funcs".}

import basis/code/choice

type
  CacheEntry* = object
    seq_no*: uint64
    data*: seq[byte]

  ChangesetCache* = object
    entries*: seq[CacheEntry]
    max_entries*: int

proc init_cache*(max_entries: int = 64): ChangesetCache =
  ChangesetCache(entries: @[], max_entries: max_entries)

proc put*(cache: var ChangesetCache, seq_no: uint64, data: seq[byte]) =
  ## Store a changeset in the cache.
  if cache.entries.len >= cache.max_entries:
    cache.entries.delete(0)  # evict oldest
  cache.entries.add(CacheEntry(seq_no: seq_no, data: data))

proc get*(cache: ChangesetCache, seq_no: uint64): Choice[seq[byte]] =
  ## Retrieve a cached changeset by sequence number.
  for entry in cache.entries:
    if entry.seq_no == seq_no:
      return good(entry.data)
  none[seq[byte]]()

proc latest*(cache: ChangesetCache): Choice[CacheEntry] =
  ## Get the most recent cache entry.
  if cache.entries.len > 0:
    good(cache.entries[^1])
  else:
    none[CacheEntry]()

proc evict*(cache: var ChangesetCache, before_seq: uint64) =
  ## Remove all entries with seq_no < before_seq.
  var i = 0
  while i < cache.entries.len:
    if cache.entries[i].seq_no < before_seq:
      cache.entries.delete(i)
    else:
      inc i
