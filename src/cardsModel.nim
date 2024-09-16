import db_connector/db_sqlite,
  times,
  strutils,
  sequtils,
  lib/sqlutils,
  lib/operators

type CardRank* = enum
  New,
  Learning,
  Hard,
  Medium,
  Easy,
  Mastering,
  Mastered

type Card* = object
  id*: string
  front*: string
  back*: string
  rank*: CardRank

proc createCard*(db: DbConn, front: string, back: string) =
  currentTime := now().utc

  query := setParams("""
    INSERT INTO card
    (front, back, last_seen, rank_id)
    VALUES ($1, $2, $3, $4)
  """, front, back, $currentTime, $ord(New))

  db.exec(sql(query))

template startOfUtcDay (dt: DateTime): DateTime =
  parse(dt.format("yyyy-MM-dd"), "yyyy-MM-dd").utc

proc getTodaysCards*(db: DBConn): seq[Card] =
  now := now()
  today := startOfUtcDay(now)
  twoDaysAgo := startOfUtcDay((now - 2.days))
  fourDaysAgo := startOfUtcDay((now - 4.days))
  lastWeek := startOfUtcDay((now - 1.weeks))
  threeWeeksAgo := startOfUtcDay((now - 3.weeks))
  sixWeeksAgo := startOfUtcDay((now - 6.weeks))

  query := setParams("""
    SELECT c.id, front, back, rank_id
      FROM card c
      JOIN card_rank r
        ON r.id = rank_id
      WHERE r.label = 'New'
        OR (r.label = 'Learning' AND last_seen >= $1)
        OR (r.label = 'Hard' AND last_seen >= $2)
        OR (r.label = 'Medium' AND last_seen >= $3)
        OR (r.label = 'Easy' AND last_seen >= $4)
        OR (r.label = 'Mastering' AND last_seen >= $5)
        OR last_seen >= $6
  """, $today, $twoDaysAgo, $fourDaysAgo, $lastWeek, $threeWeeksAgo,
    $sixWeeksAgo)

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
      SET rank_id = rs.rank_id, last_seen = $1
      FROM (
  """, $now().utc)

  for i in 0 ..< len:
    card := cards[i]
    if i != 0: query &= " UNION "

    query &= setParams("SELECT $1 AS id, $2 AS rank_id ",
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
