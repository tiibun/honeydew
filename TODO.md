# TODO

Potential improvements across the codebase, organized by area.

---

## Bug fixes / correctness

### Statement splitter is not comment-aware
`find_statement_boundaries` in `honeydew/cmd/main/main.mbt` treats every unquoted `;`
as a statement boundary, but does not skip `--` line comments or `/* */` block
comments.  A `;` inside a comment is incorrectly treated as a separator.

```sql
-- end of query; next line is not a new statement
SELECT 1
```

Fix: share the same FSM state (Normal / StringLiteral / BlockComment / LineComment)
that the SQL highlighter already implements.

### Statement splitter does not handle double-quoted identifiers
A double-quoted identifier (`"my;col"`) containing a semicolon breaks the splitter.
PostgreSQL uses double quotes for identifiers; MySQL uses backticks.
Both should be treated as opaque token boundaries just like single-quoted strings.

---

## UI / UX

### NULL vs empty-string visual distinction in results
`display_rows` converts the `null_value` sentinel to the plain string `"NULL"`,
which is then rendered with the same style as any other cell.  A genuine `"NULL"`
string value is visually identical.

Render actual-NULL cells in a dimmed / italic style (e.g. `BrightBlack` foreground)
so they are clearly distinguishable from the string `"NULL"`.

### Copy full row to clipboard
`y` copies only the currently selected cell.  A second binding (e.g. `Y` or
`Ctrl+Y`) should copy the entire selected row as tab-separated or CSV text,
useful for pasting into spreadsheets or other tools.

### Mouse click support in the results table
Mouse clicks on the schema panel are handled (`handle_schema_click`), but clicks
inside the results table are ignored — the table only gains focus, not a specific
cell selection.  Implement `Table::handle_click` similar to `Tree::handle_click`.

### EXPLAIN shortcut
Add a key binding (e.g. `F2` or `Ctrl+X`) that prefixes the statement at the
cursor with `EXPLAIN ` (or `EXPLAIN ANALYZE ` on PostgreSQL) and runs it, so the
user can inspect query plans without editing the buffer.

### Line numbers in the SQL editor
Display 1-based line numbers in the left gutter of the `TextArea` widget.  This
helps when debugging multi-statement scripts and correlates error messages that
cite a line number.

### Find / search in editor
Add an in-editor search bar (e.g. `Ctrl+F`) that highlights occurrences and
lets the user jump between them with `n`/`N`.

---

## Schema browser

### Show indexes, triggers, and routines
The schema tree currently shows Tables and Views.  For a more complete picture,
also introspect and display:

- **Indexes** (per table, at depth 3)
- **Triggers** (per table or top-level group)
- **Functions / Stored procedures** (where the backend supports it)

Each backend's `DbConn` implementation would need corresponding query helpers.

### Lazy column loading in the schema tree
All columns for every table are fetched eagerly on connect/refresh.  For
databases with many tables this can be slow.  Load column metadata only when
the user expands a table node.

---

## SQL keyword highlighting

Many common keywords are missing from `is_sql_keyword` in
`honeydew/cmd/main/sql_highlight.mbt`.  Consider adding:

`WITH`, `UNION`, `ALL`, `EXCEPT`, `INTERSECT`, `CASE`, `WHEN`, `THEN`,
`ELSE`, `END`, `EXISTS`, `IN`, `LIKE`, `ILIKE`, `BETWEEN`, `IS`, `TRUE`,
`FALSE`, `TRANSACTION`, `INDEX`, `CONSTRAINT`, `PRIMARY`, `FOREIGN`, `KEY`,
`REFERENCES`, `DEFAULT`, `UNIQUE`, `CROSS`, `FULL`, `USING`, `RETURNING`,
`OVER`, `PARTITION`, `WINDOW`, `CAST`, `COALESCE`, `NULLIF`, `TRUNCATE`,
`EXPLAIN`, `ANALYZE`, `VACUUM`, `GRANT`, `REVOKE`, `SAVEPOINT`, `RELEASE`.

---

## Export

### Export as JSON
`AppState::export_results_csv` writes only CSV.  Add a JSON export option
(e.g. an array of objects keyed by column name) accessible via a menu or a
second binding (`Ctrl+J`).

### Load SQL from file
Add a command (e.g. `Ctrl+O`) that opens a file-path prompt, reads a `.sql`
file from disk, and inserts its content into the editor.  Complements the CSV
export for scripted workflows.

---

## Connection form

### SSL / TLS options
The connection form has no SSL/TLS fields.  PostgreSQL and MySQL both support
encrypted connections.  Add a toggle and optional certificate-path fields,
mapped through to the backend connect calls.

### Connection timeout field
Allow the user to set a connect timeout (seconds) in the form.  Currently the
backends use their library defaults, which can be long on unreachable hosts.

---

## Code quality

### `is_write_statement` is incomplete
`db/db.mbt:is_write_statement` recognises only `INSERT`, `UPDATE`, and
`DELETE`.  Statements like `CREATE`, `DROP`, `ALTER`, `TRUNCATE`, and `REPLACE`
also write data or modify schema, so they should be treated as writes too (e.g.
for SQLite's WAL mode and for `async_result` routing).

### Hardcoded layout ratios
Schema width (28%), editor height (35%), and results height (65%) are
duplicated between `honeydew/ui/main_screen.mbt` and `honeydew/app/state.mbt`
(`handle_schema_click`).  Extract them to named constants so both places stay
in sync.
