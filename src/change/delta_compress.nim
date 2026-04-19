## delta_compress.nim -- Delta-encode consecutive changesets.
##
## Uses the delta codec to compute binary diffs between consecutive
## changeset blobs, reducing transport size for incremental changes.

{.experimental: "strict_funcs".}

import basis/code/choice
import framing, cache

type
  DeltaCompressor* = object
    cache*: ChangesetCache

proc init_compressor*(cache_size: int = 64): DeltaCompressor =
  DeltaCompressor(cache: init_cache(cache_size))

proc compress*(dc: var DeltaCompressor, seq_no: uint64, data: seq[byte],
               encode_fn: proc(source, target: seq[byte]): string): Choice[ChangeFrame] =
  ## Delta-encode the current changeset against the previous one.
  ## If no previous changeset is cached, emit as raw.
  let prev = dc.cache.latest()
  dc.cache.put(seq_no, data)

  if prev.is_none or prev.val.data.len == 0:
    # No previous: emit raw
    return good(ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: seq_no, payload: data))

  # Delta-encode against previous
  let delta_str = encode_fn(prev.val.data, data)
  var delta_bytes = newSeq[byte](delta_str.len)
  for i, c in delta_str: delta_bytes[i] = byte(c)

  # Only use delta if it's smaller than raw
  if delta_bytes.len < data.len:
    good(ChangeFrame(tier: ChangeTier.Delta, kind: ChangeFrameKind.Changeset, seq_no: seq_no, payload: delta_bytes))
  else:
    good(ChangeFrame(tier: ChangeTier.Raw, kind: ChangeFrameKind.Changeset, seq_no: seq_no, payload: data))

proc decompress*(dc: DeltaCompressor, frame: ChangeFrame,
                 decode_fn: proc(source: seq[byte], delta: string): Choice[seq[byte]]): Choice[seq[byte]] =
  ## Decompress a delta-encoded frame using the cached previous changeset.
  if frame.tier == ChangeTier.Raw:
    return good(frame.payload)

  let prev = dc.cache.latest()
  if prev.is_none:
    return bad[seq[byte]]("change", "no previous changeset for delta decompression")

  var delta_str = newString(frame.payload.len)
  for i, b in frame.payload: delta_str[i] = char(b)
  decode_fn(prev.val.data, delta_str)
