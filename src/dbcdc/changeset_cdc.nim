## changeset_cdc.nim -- SQLite Session hook -> tiered publish.
##
## Bridges SQLite's Session Extension changeset output to the CDC
## tiered transport. Captures changesets and publishes them as
## CdcFrames via the framing layer.

{.experimental: "strict_funcs".}

import basis/code/choice
import framing, cache, sp_binding

type
  ChangesetPublisher* = object
    cache*: ChangesetCache
    next_seq*: uint64
    tier*: CdcTier
    binding*: SpCdcBinding

proc init_changeset_publisher*(endpoint: string, tier: CdcTier = tierRaw,
                                cache_size: int = 64): ChangesetPublisher =
  ChangesetPublisher(
    cache: init_cache(cache_size),
    next_seq: 1,
    tier: tier,
    binding: new_pubsub_binding(endpoint)
  )

proc publish_changeset*(pub: var ChangesetPublisher, data: seq[byte]): Choice[CdcFrame] =
  ## Accept a raw changeset blob, cache it, and produce a CdcFrame for transport.
  let seq_no = pub.next_seq
  inc pub.next_seq
  pub.cache.put(seq_no, data)
  let frame = make_changeset_frame(pub.tier, seq_no, data)
  good(frame)

proc get_cached*(pub: ChangesetPublisher, seq_no: uint64): Choice[seq[byte]] =
  ## Retrieve a cached changeset for retransmission or delta encoding.
  pub.cache.get(seq_no)
