import strutils

template escapeTicks (s: string): string =
  s.replace("'", "''")

proc sanitize (args: seq[string]): seq[string] =
  for i in 0 ..< args.len:
    result.add(escapeTicks(args[i]))

proc setParams*(query: string, params: varargs[string]): string =
  result = query.replace("$#", "'$#'") % sanitize(@params)
