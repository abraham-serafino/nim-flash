import
  db_connector/db_sqlite,
  times,
  strutils,
  sequtils,
  lib/sqlutils,
  lib/operators

type
  CardRank* = enum
    New,
    Learning,
    Hard,
    Medium,
    Easy,
    Mastering,
    Mastered

  Card* = object
    id*: string
    front*: string
    back*: string
    rank*: CardRank

proc createCard*(db: DbConn, front: string, back: string) =
  currentTime := now().utc

  query := setParams("""
    INSERT INTO card
    (front, back, last_seen, rank_id)
    VALUES ($#, $#, $#, $#)
  """, front, back, $currentTime, $ord(New))

  db.exec(sql(query))

template startOfUtcDay (dt: DateTime): DateTime =
  parse(dt.format("yyyy-MM-dd"), "yyyy-MM-dd").utc

proc getTodaysCards*(db: DBConn): seq[Card] =
  now := now().utc.toTime()

  today := toUnix(now)
  twoDaysAgo := toUnix(now - 2.days)
  fourDaysAgo := toUnix(now - 4.days)
  lastWeek := toUnix(now - 1.weeks)
  threeWeeksAgo := toUnix(now - 3.weeks)
  sixWeeksAgo := toUnix(now - 6.weeks)

  query := setParams("""
    SELECT c.id, front, back, rank_id
      FROM card c
      WHERE rank_id = $#
        OR (rank_id = $# AND last_seen <= $#)
        OR (rank_id = $# AND last_seen <= $#)
        OR (rank_id = $# AND last_seen <= $#)
        OR (rank_id = $# AND last_seen <= $#)
        OR (rank_id = $# AND last_seen <= $#)
        OR last_seen <= $#
  """, $ord(New), $ord(Learning), $today, $ord(Hard), $twoDaysAgo,
    $ord(Medium), $fourDaysAgo, $ord(Easy), $lastWeek, $ord(Mastering),
    $threeWeeksAgo, $sixWeeksAgo)

  echo query

  rows := db.getAllRows(sql(query))

  for row in items(rows):
    var card = Card()
    card.id = row[0]
    card.front = row[1]
    card.back = row[2]
    card.rank = cast[CardRank](parseInt(row[3]))

    result.add(card)
# /proc getTodaysCards

proc updateRanks(db: DBConn, cards: seq[Card]) =
  len := cards.len
  if len <= 0: return

  var query = setParams("""
    UPDATE card
      SET rank_id = rs.rank_id, last_seen = $#
      FROM (
  """, $now().utc)

  for i in 0 ..< len:
    card := cards[i]
    if i != 0: query &= " UNION "

    query &= setParams("SELECT $# AS id, $# AS rank_id ",
      card.id, $ord(card.rank))

  query &= " ) rs WHERE card.id = rs.id"

  db.exec(sql(query))
# /proc updateRanks

proc incrementRanks*(db: DBConn, cards: var seq[Card]) =
  newCards := cards.map(proc (card: Card): Card =
    result = card

    if card.rank < Mastered:
      result.rank = cast[CardRank](ord(card.rank) + 1)
  )

  updateRanks(db, newCards)

proc decrementRanks*(db: DBConn, cards: var seq[Card],
    amount:int = 1) =

  newCards := cards.map(proc (card: Card): Card =
    result = card

    if ord(card.rank) - amount >= ord(New):
      result.rank = cast[CardRank](ord(card.rank) - amount)
  )

  updateRanks(db, newCards)
