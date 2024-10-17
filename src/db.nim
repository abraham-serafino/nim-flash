import db_connector/db_sqlite

var db: DbConn = nil

proc getDb* (): DbConn =
  if db == nil:
    db = open("cards.db", "", "", "")

  result = db

  db.exec(sql"""
    CREATE TABLE IF NOT EXISTS card_rank (
      id INTEGER PRIMARY KEY,
      label TEXT
    );
    """)

  db.exec(sql"""
    CREATE TABLE IF NOT EXISTS card (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      front TEXT,
      back TEXT,
      last_seen TEXT,
      rank_id INTEGER REFERENCES card_rank(id)
    )
  """)

  let queryResult = db.getAllRows(sql"""
    SELECT * FROM card_rank
  """)

  if queryResult.len < 1:
    db.exec(sql"""
      INSERT INTO card_rank (id, label) VALUES
        (0, 'New'),
        (1, 'Learning'),
        (2, 'Hard'),
        (3, 'Medium'),
        (4, 'Easy'),
        (5, 'Mastering'),
        (6, 'Mastered')
    """)
