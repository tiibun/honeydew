# Main Screen

The Main screen is the primary working area. It contains a menu bar, three panes, and a status bar.

## Layout

```text
┌─────────────────────────────────────────────────────────────┐
│ profile-name  db@host             F1=Help  Ctrl+Q=Quit      │ ← menu bar
├────────────┬────────────────────────────────────────────────┤
│  Objects   │  SQL (Ctrl+Enter=run current  F5=run all)      │
│            │                                                 │
│            │                                                 │  SQL editor
│            │                                                 │
│            ├────────────────────────────────────────────────┤
│            │  col1 │ col2 │ col3                            │
│            │  ...  │ ...  │ ...                             │  Results
│            │                                                 │
└────────────┴────────────────────────────────────────────────┘
│ status text                                                  │ ← status bar
└─────────────────────────────────────────────────────────────┘
```

## Menu bar

The menu bar always appears at the top. It shows:

- **Left side:** profile name and connection info (host, database)
- **Right side:** `F1=Help  Ctrl+Q=Quit`

When a transaction is active the menu bar turns **yellow** as a visual warning.

## Panels

| Panel | Description |
|---|---|
| **Objects** (left, ~28%) | Schema browser — tables, views, columns |
| **SQL editor** (top-right, ~35%) | Multi-line SQL editor with syntax highlighting |
| **Results** (bottom-right, ~65%) | Query result grid |

Press `Tab` to move focus to the next panel. The focused panel has a **cyan** border.

## Status bar

The status bar shows the current state:

- Row count and execution time after a successful query
- `Running query… Ctrl+C to cancel` while a query executes
- Error summary (press `Ctrl+E` to see the full error)

## Returning to the Connect screen

Press `Ctrl+D` to disconnect and return to the Connect screen.
