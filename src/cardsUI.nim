import
  db_connector/db_sqlite,
  rdstdin,
  strformat,
  strutils,
  sequtils,
  lib/aryutils,
  db as database,
  cardsModel

let db = getDb()

proc getLine (prompt: string, input: var string): bool =
  var rawInput: string
  result = readLineFromStdin(prompt, rawInput)
  input = rawInput.toLowerAscii

proc addCards () =
  assert(db != nil, "Database must be initialized.")

  var totalCards = 0

  echo ""
  echo "Press 'Ctrl+D' when you are finished entering cards"
  echo ""

  var
    front: string
    back: string

  while true:
    if not getLine("front: ", front): break
    if not getLine("back: ", back): break

    var input: string

    while true:
      let ok =
        readLineFromStdin(&"front: {front} - back: {back} (Y/n) ",
          input)

      if not ok: break
      if input == "n": break

      if input == "y" or input == "":
        db.createCard(front, back)
        inc totalCards

        if totalCards == 1: echo "Added 1 card."
        else: echo &"Added {totalCards} cards so far."

        break
    # /while true

    echo ""
  # /while true
# /proc addCards

proc reviewSingleCard (card: Card, reviewList: var seq[Card]):
    (bool, bool) =

  var answer: string
  let ok = getLine(&"{card.front} -> ", answer)

  if answer == card.back:
    echo "Right!"
    result = (ok, true)
  else:
    reviewList.add(card)
    echo &"({card.back})"
    result = (ok, false)

  echo ""
# /proc reviewSingleCard

proc reviewCards (reviewList: var seq[Card],
    singleIteration: bool = false) =

  var reviewLen = reviewList.len
  if reviewLen <= 0: return

  shuffle(reviewList)

  var cardsReviewed = 0
  var cards = unshift(reviewList)

  while cards.len >= 1:
    let card = cards[0]

    let (ok, isCorrectAnswer) = reviewSingleCard(card, reviewList)
    if not ok: return

    inc cardsReviewed
    cards = unshift(reviewList)

    if cards.len >= 1 and cardsReviewed >= reviewLen:
      if singleIteration:
        reviewList.add(cards[0])
        break
      else:
        reviewLen = reviewList.len
        shuffle(reviewList)
  # /while cards.len >= 1
# /proc reviewCards

proc practice () =
  assert(db != nil, "Database must be initialized.")

  var allCards = getTodaysCards(db)
  shuffle(allCards)

  var firstTen = allCards.unshift(howMany = 10)

  while firstTen.len > 0:
    let len = allCards.len + firstTen.len

    echo ""
    if len == 1: echo "1 card left to review..."
    else: echo &"{len} cards left to review..."
    echo ""

    var complete: seq[Card] = @[]
    var reviewList: seq[Card] = @[]
    var incorrectCards: seq[Card] = @[]

    # first pass: separate correct from incorrect
    for card in items(firstTen):
      let (ok, isCorrectAnswer) = reviewSingleCard(card, reviewList)
      if not ok: return

      if isCorrectAnswer:
        if card.rank == New: reviewList.add(card)
        complete.add(card)

      else: incorrectCards.add(card)

    reviewList &= incorrectCards

    # second pass: do not decrement ranks yet
    reviewCards(reviewList, singleIteration = true)

    var stillIncorrect = reviewList.filter(
      proc (card: Card): bool =
        return card in incorrectCards
    )

    # third pass: continue cycling through the cards until there are
    # none left.
    reviewCards(reviewList)

    db.incrementRanks(complete)
    db.decrementRanks(incorrectCards)
    db.decrementRanks(stillIncorrect, 2)

    firstTen = allCards.unshift(howMany = 10)
  # /while firstTen.len > 0
# /proc practice

proc displayOptions () =
  echo "What would you like to do?"
  echo "(A)dd cards manually"
  echo "(P)ractice"
  echo "(Q)uit"
  echo ""

proc showMenu* () =
  var input: string

  while true:
    displayOptions()

    let ok = getLine("(P) ", input)
    if not ok: break

    case input
    of "a": addCards()
    of "p", "": practice()
    of "q": break
    else: echo ""
  # /while true
# /proc showMenu
