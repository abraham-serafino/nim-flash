import sequtils, random

randomize()

proc unshift* [T] (ary: var seq[T], howMany: int = 1): seq[T] =
  let len = ary.len
  if len <= 0: return @[]

  let lastIdx = if howMany - 1 >= len: len - 1
                else: howMany - 1

  result = ary[0..lastIdx]
  ary.delete(0..lastIdx)

proc shuffle* [T] (ary: var seq[T]) =
  let len = ary.len

  for i in 0 ..< len:
    let swapIndex = rand(i ..< ary.len)

    (ary[i], ary[swapIndex]) =
      (ary[swapIndex], ary[i])
