import
  db_connector/db_sqlite,
  times,
  lib/operators,
  lib/sqlutils

type CardRow = object
  id: string
  lastSeen: string

db := open("cards.db", "", "", "")

template toTimestamp(lastSeen: string): int =
  parseTime(lastSeen, "yyyy-MM-dd'T'HH:mm:ss'Z'", utc()).toUnix()

proc main =
  findQuery := """
    SELECT id, last_seen
    FROM card
  """

  rows := db.getAllRows(sql(findQuery))

  var insertQuery = """
    UPDATE card
    SET id = rs.id, last_seen = rs.last_seen
    FROM (
  """

  rowsLen := rows.len - 1

  for i in 0 .. rowsLen:
    row := rows[i]
    if i != 0: insertQuery &= " UNION "

    insertQuery &= setParams("SELECT $# as id, $# as last_seen",
      row[0], $toTimestamp(row[1]))

  insertQuery &=  ") rs WHERE card.id = rs.id"

  # echo insertQuery
  db.exec(sql(insertQuery))

main()
