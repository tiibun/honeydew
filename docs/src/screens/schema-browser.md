# Schema Browser

The Objects panel on the left side of the Main screen displays the database schema as a collapsible tree.

## Tree structure

```text
▶ Tables
  ▼ users
    id       INTEGER
    name     TEXT
    email    TEXT
  ▶ orders
▶ Views
  ▶ active_users
▶ Routines
  report_summary
```

Top-level nodes group objects by type (Tables, Views, Routines). Expand a table to see its columns and their types. The Routines category is only shown when the database has stored procedures or functions (PostgreSQL/MySQL).

## Navigation

| Key | Action |
|---|---|
| `↑` / `↓` | Move selection up / down |
| `Space` or `Enter` | Expand or collapse the selected node |
| `→` | Expand the selected node |
| `←` | Collapse the selected node |
| `Tab` | Move focus to the SQL editor |

## Refreshing the schema

Press `Ctrl+L` to reload the schema from the database. This is useful after running DDL statements (`CREATE TABLE`, `ALTER TABLE`, etc.) that change the schema.
