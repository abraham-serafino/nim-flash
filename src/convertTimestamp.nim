import
  db_connector/db_sqlite,
  times,
  lib/sqlutils

type
  CardRow = object
    id: string
    lastSeen: string

let db = open("cards.db", "", "", "")

template toTimestamp (lastSeen: string): int =
  parseTime(lastSeen, "yyyy-MM-dd'T'HH:mm:ss'Z'", utc()).toUnix()

proc main () =
  let
    findQuery = """
      SELECT id, last_seen
      FROM card
    """

    rows = db.getAllRows(sql(findQuery))
    rowsLen = rows.len - 1

  var insertQuery = """
    UPDATE card
    SET id = rs.id, last_seen = rs.last_seen
    FROM (
  """

  for i, row in rows:
    if i != 0: insertQuery &= " UNION "

    insertQuery &= setParams("SELECT $# as id, $# as last_seen",
      row[0], $toTimestamp(row[1]))

  insertQuery &=  ") rs WHERE card.id = rs.id"

  db.exec(sql(insertQuery))

main()
