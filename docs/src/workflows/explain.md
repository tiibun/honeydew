# EXPLAIN

The `EXPLAIN` shortcut lets you inspect the query plan for any statement without editing the SQL buffer.

## Usage

1. Place the cursor anywhere inside the statement you want to explain.
2. Press `Ctrl+X`.

honeydew prepends `EXPLAIN ` to the statement and executes it. The query plan appears in the Results panel.

```text
 selectid │ order │ from │ detail
 ─────────┼───────┼──────┼───────────────────────────────
 0        │ 0     │ 0    │ SCAN users
```

The original statement in the editor is **not modified**.

## PostgreSQL

On PostgreSQL, `Ctrl+X` uses `EXPLAIN` (not `EXPLAIN ANALYZE`). Run `EXPLAIN ANALYZE` manually in the editor if you need actual runtime statistics.

## Key bindings

| Key | Action |
|---|---|
| `Ctrl+X` | Run EXPLAIN for statement at cursor |
