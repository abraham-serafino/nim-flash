import strutils, strformat, operators

type SqlParamError = object of CatchableError

proc setParams*(s: string, args: varargs[string]): string =
  len := args.len
  result = s

  for i in 0 ..< len:
    placeholder := fmt"${i + 1}"

    if not s.contains(placeholder):
      raise newException(SqlParamError,
        "Mismatch between number of params and number of placeholders")

    escaped := args[i].replace("'", "''")
    result = result.replace(placeholder, fmt"'{escaped}'")
