## chunking.nim -- Split/reassemble for size-limited transports.

{.experimental: "strict_funcs".}

import basis/code/choice
import framing

const
  DEFAULT_CHUNK_SIZE* = 65536  ## 64KB default max chunk

type
  Chunk* = object
    frame_seq*: uint64
    chunk_index*: uint16
    total_chunks*: uint16
    data*: seq[byte]

proc split_frame*(frame: ChangeFrame, max_size: int = DEFAULT_CHUNK_SIZE): seq[Chunk] =
  ## Split a frame into chunks if payload exceeds max_size.
  let encoded = encode_frame(frame)
  if encoded.len <= max_size:
    return @[Chunk(frame_seq: frame.seq_no, chunk_index: 0, total_chunks: 1, data: encoded)]
  let n_chunks = (encoded.len + max_size - 1) div max_size
  result = newSeq[Chunk](n_chunks)
  for i in 0 ..< n_chunks:
    let start = i * max_size
    let stop = min(start + max_size, encoded.len)
    var chunk_data = newSeq[byte](stop - start)
    for j in start ..< stop:
      chunk_data[j - start] = encoded[j]
    result[i] = Chunk(
      frame_seq: frame.seq_no,
      chunk_index: uint16(i),
      total_chunks: uint16(n_chunks),
      data: chunk_data
    )

proc reassemble_chunks*(chunks: seq[Chunk]): Choice[ChangeFrame] =
  ## Reassemble chunks into a frame.
  if chunks.len == 0:
    return bad[ChangeFrame]("change", "no chunks to reassemble")
  if chunks.len == 1 and chunks[0].total_chunks == 1:
    return decode_frame(chunks[0].data)
  # Sort by index and concatenate
  var sorted = chunks
  for i in 0 ..< sorted.len:
    for j in i + 1 ..< sorted.len:
      if sorted[j].chunk_index < sorted[i].chunk_index:
        swap(sorted[i], sorted[j])
  var total_len = 0
  for c in sorted: total_len += c.data.len
  var assembled = newSeq[byte](total_len)
  var pos = 0
  for c in sorted:
    for b in c.data:
      assembled[pos] = b
      inc pos
  decode_frame(assembled)
