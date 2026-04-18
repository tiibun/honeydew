# Feature Wishlist

Desired features for the honeydew DB client, organized by area.
Items marked `[ ]` are not yet implemented.

---

## SQL Placeholder Input

- [x] **Parameterized query runner**
  Add a `:placeholder` or `$1`-style syntax in the editor. When the user executes
  a statement containing unbound parameters, show an input form that prompts for
  each value before running the query. Supports:
  - Named placeholders: `:name` ✓, `{name}` (EF Core) ✓
  - Positional placeholders: `$1`, `$2` ✓, `?` ✓
  - `@name` is intentionally not supported (PostgreSQL interprets `@id` as absolute value)
  - Type hint annotation (e.g. `/* int */`) — not yet implemented

  Example workflow:
  ```sql
  SELECT * FROM orders WHERE user_id = :user_id AND status = :status
  ```
  → Overlay appears with fields `user_id` and `status` → user fills values → query runs.
  Also triggered by `Ctrl+X` (EXPLAIN) when placeholders are present.

- [ ] **Placeholder history**
  Remember previously entered values per placeholder name so the user can
  quickly re-run with the same inputs.

- [ ] **Named parameter sets (snapshots)**
  Let the user save a set of placeholder values under a name (e.g. "staging-user")
  and recall it from a list, similar to saved connection profiles.

---

## Editor Enhancements

- [ ] **SQL auto-complete**
  Suggest SQL keywords, table names, column names, and function names as the
  user types. Trigger on `Tab` or a configurable key. Use schema metadata already
  loaded in `AppState` to populate table/column candidates.

- [ ] **SQL formatter**
  Add a key binding (e.g. `Ctrl+Shift+F`) that formats / pretty-prints the
  statement at the cursor using indentation and keyword capitalisation.

- [ ] **Multi-cursor / column-edit mode**
  Allow placing multiple cursors with `Alt+Click` or `Ctrl+Alt+Down` to edit
  several lines at once (useful for bulk renaming in generated SQL).

- [ ] **Bracket / quote matching highlight**
  Highlight the matching `(`, `)`, `'`, or `"` when the cursor is on one.

- [ ] **Code folding**
  Allow folding long subqueries or CTE blocks in the editor to reduce visual noise.

- [ ] **Session-persistent scratch buffers**
  Auto-save editor content per connection profile on exit and restore it on
  the next connect, so the user never loses in-progress SQL.

---

## Result Grid

- [ ] **In-grid filtering**
  Press `/` to open a filter bar above the result table. Type a substring or
  regex; rows that do not match are hidden client-side (no re-query needed).

- [ ] **Column sort toggle**
  Click a column header (or press `s` with a column focused) to sort the
  displayed rows ascending / descending locally without re-running the query.

- [ ] **Column width resize**
  Allow the user to resize individual columns with `<` / `>` keys or mouse drag.

- [ ] **Freeze / pin columns**
  Pin one or more columns to the left so they stay visible while scrolling right
  in wide result sets.

- [ ] **Inline cell edit and UPDATE generation**
  Press `e` on a cell to enter edit mode. On confirm, generate and optionally
  execute an `UPDATE` statement for that row using primary-key columns.

- [ ] **Multiple result tabs**
  Keep results from previous executions in labelled tabs (one per statement run)
  so the user can compare outputs without re-running queries.

- [ ] **Pagination / limit control**
  Show a `LIMIT / OFFSET` control beneath the results grid so the user can page
  through large result sets without editing the query.

---

## Query Management

- [ ] **Bookmarked / favourite queries**
  Let the user save and name a query (e.g. `Ctrl+D`) from the editor. A
  bookmark panel lists saved queries; pressing Enter loads it back into the editor.

- [ ] **Query tags and search**
  Tag bookmarked queries and filter the bookmark list by tag or full-text search.

- [x] **Execution plan overlay (EXPLAIN)**
  Press `Ctrl+X` to run `EXPLAIN` (or `EXPLAIN ANALYZE` on PostgreSQL)
  for the statement at the cursor. Results are shown in the results pane
  (not a dedicated overlay). Placeholder detection also applies to EXPLAIN.

- [ ] **Query duration history chart**
  Track execution durations in the query history and show a small sparkline
  chart so the user can spot regressions across repeated runs.

---

## Schema Browser

- [ ] **Table row-count column**
  Show an estimated row count next to each table name in the schema tree (via
  `information_schema` statistics or `PRAGMA table_info`).

- [ ] **Schema diff view**
  Compare the current schema against a saved snapshot or a second connection
  and highlight added / removed / changed tables and columns.

- [ ] **Full-text search across schema**
  Press `/` in the schema panel to filter tables and columns by name substring.

- [ ] **Table preview on hover / key**
  Press `Space` on a table node to run `SELECT * FROM t LIMIT 10` and show the
  results in a preview overlay without leaving the schema panel.

- [ ] **Copy DDL**
  Press `d` on a table node to copy the `CREATE TABLE` DDL to the clipboard.

---

## Export and Import

- [x] **Export as JSON**
  Export query results as a JSON array of objects keyed by column name
  (`Ctrl+J`), in addition to the existing CSV export.

- [ ] **Export as Markdown table**
  Export results as a GitHub-flavored Markdown table for pasting into docs or
  PRs.

- [ ] **Import CSV into table**
  Provide a command that reads a local CSV file and generates / executes
  `INSERT` statements to load the data into a chosen table.

- [x] **Load SQL from file**
  Press `Ctrl+O` to open a file-path prompt, read a `.sql` file, and insert its
  content into the editor.

---

## Connection and Session

- [ ] **SSH tunnel support**
  Configure an SSH jump host in the connection form; the client establishes the
  tunnel before connecting to the database port.

- [ ] **Multiple simultaneous connections**
  Open more than one connection at a time and switch between them with a tab bar
  or key binding, each with its own schema tree, editor buffer, and results.

- [ ] **Read-only mode toggle**
  A global toggle that prevents executing write statements (`INSERT`, `UPDATE`,
  `DELETE`, DDL), acting as a safety net when browsing production databases.

- [ ] **Connection health indicator**
  Show a live connection-status badge (connected / idle / executing / lost) in
  the status bar, refreshed by periodic ping queries.

- [ ] **SSL / TLS options**
  Add SSL toggle and certificate-path fields to the connection form for
  encrypted connections to PostgreSQL and MySQL.

---

## Appearance and Accessibility

- [ ] **Color theme selector**
  Allow the user to choose from built-in themes (dark, light, solarized, etc.)
  and persist the selection in the config file.

- [ ] **Configurable key bindings**
  Let the user remap any key binding via a `keybindings.toml` config section
  without recompiling.

- [x] **Mouse click support in the results table**
  Clicking a cell in the results table should select that cell, mirroring the
  existing click handling in the schema tree.

- [ ] **Adjustable pane sizes**
  Allow the user to resize the schema, editor, and results panes interactively
  (mouse drag on the divider or `Alt+Arrow` keys).
