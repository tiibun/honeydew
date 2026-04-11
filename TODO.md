# Missing Features — honeydew DB Client

## Schema Browser (Objects panel)

- [ ] 6.Show columns under each table (name + type, as child nodes in the tree)
- [ ] 5.Show views separately from tables
- [ ] 4.Refresh schema without reconnecting
- [ ] 7.Enter on a table auto-fills `SELECT * FROM <table> LIMIT 100` in the editor

## SQL Editor

- [x] 17.Syntax highlighting (colorize keywords, strings, comments — not just range highlight)
- [x] 16.Query history — recall previous executed queries with Up/Down (or dedicated keybind)
- [ ] 2.Run all statements (not just the one at cursor)

## Results Panel

- [x] 13.Show execution time (e.g. "42 ms")
- [x] 14.Show affected rows for INSERT / UPDATE / DELETE
- [ ] 8.Distinguish NULL from empty string visually
- [x] 15.Copy selected cell value to clipboard
- [x] 18.Export results as CSV

## Connection / Session

- [ ] 3.Disconnect and return to Connect screen without quitting
- [ ] 9.Reconnect on lost connection (auto-detect and prompt)
- [ ] 10.Connection indicator in menu bar (database name + connected status)
- [x] 12.Transaction shortcuts: Ctrl+B=BEGIN, Ctrl+M=COMMIT, Ctrl+R=ROLLBACK (with indicator when inside a transaction)

## General UX

- [ ] 11.Cancel a running query (Ctrl+C while query is in flight)
- [x] 1.Error detail overlay (full error message when it is truncated in status bar)
