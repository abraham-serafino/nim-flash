import db_connector/db_sqlite,
  noise,
  strformat,
  sequtils,
  lib/aryutils,
  lib/operators,
  db as database,
  cardsModel

var db: DBConn = nil
var isEof = false
var nimNoise = Noise.init()

template getLine (prompt: string): string =
  nimNoise.setPrompt(prompt)

  let ok = nimNoise.readLine()
  isEof = not ok

  nimNoise.getLine

proc addCards () =
  assert(db != nil, "Database must be initialized.")

  var totalCards = 0

  echo ""
  echo "Press 'Ctrl+D' when you are finished entering cards"
  echo ""

  while true:
    front := getLine("front: ")
    if isEof: break

    back := getLine("back: ")
    if isEof: break

    while not isEof:
      input := getLine(&"front: {front} - back: {back} (Y/n) ")

      if input == "n": break

      if input == "y" or input == "":
        createCard(db, front, back)
        inc totalCards

        if totalCards == 1: echo "Added 1 card."
        else: echo &"Added {totalCards} cards so far."

        break
    # /while not isEof

    echo ""
  # /while true
# /proc addCards

proc reviewSingleCard (card: Card, reviewList: var seq[Card]): bool =
  answer := getLine(&"{card.front}\n-> ")
  if isEof: return false

  if answer != card.back:
    reviewList.add(card)
    echo &"({card.back})"
    result = false
  else:
    echo "Right!"
    result = true

  echo ""
# /proc reviewSingleCard

proc reviewCards (reviewList: var seq[Card],
    singleIteration: bool = false) =

  var reviewLen = reviewList.len
  if reviewLen <= 0: return

  shuffle[Card](reviewList)

  var cardsReviewed = 0
  var cards = unshift[Card](reviewList)

  while cards.len >= 1:
    card := cards[0]

    discard reviewSingleCard(card, reviewList)
    if isEof: return

    inc cardsReviewed
    cards = unshift[Card](reviewList)

    if cards.len >= 1 and cardsReviewed >= reviewLen:
      if singleIteration:
        reviewList.add(cards[0])
        break
      else:
        reviewLen = reviewList.len
        shuffle[Card](reviewList)
  # /while cards.len >= 1
# /proc reviewCards

proc practice () =
  assert(db != nil, "Database must be initialized.")

  var allCards = getTodaysCards(db)
  shuffle[Card](allCards)

  var firstTen = unshift[Card](ary = allCards, howMany = 10)

  while firstTen.len > 0:
    len := allCards.len + firstTen.len

    echo ""
    if len == 1: echo "1 card left to review..."
    else: echo &"{len} cards left to review..."
    echo ""

    var complete: seq[Card] = @[]
    var reviewList: seq[Card] = @[]
    var incorrectCards: seq[Card] = @[]

    # first pass: separate correct from incorrect
    for card in items(firstTen):
      isCorrectAnswer := reviewSingleCard(card, reviewList)
      if isEof: return

      if isCorrectAnswer:
        if card.rank == New: reviewList.add(card)
        complete.add(card)
      else:
        incorrectCards.add(card)

    reviewList = reviewList.concat(incorrectCards)

    # second pass: do not decrement ranks yet
    reviewCards(reviewList = reviewList, singleIteration = true)

    var stillIncorrect = reviewList.filter(proc (card: Card): bool =
      return incorrectCards.count(card) > 0
    )

    # third pass: continue cycling through the cards until there are
    # none left.
    reviewCards(reviewList)

    incrementRanks(db, complete)
    decrementRanks(db, incorrectCards)
    decrementRanks(db, stillIncorrect, 2)

    firstTen = unshift[Card](ary = allCards, howMany = 10)
  # /while firstTen.len > 0
# /proc practice

template displayOptions () =
  echo "What would you like to do?"
  echo "(A)dd cards manually"
  echo "(P)ractice"
  echo "(Q)uit"
  echo ""

proc showMenu*() =
  db = getDb()
  defer: db.close()

  while true:
    displayOptions()

    input := getLine("(P) ")
    if isEof: break

    case input
    of "A", "a": addCards()
    of "P", "p", "": practice()
    of "Q", "q": break
    else: echo ""
  # /while true
# /proc showMenu
