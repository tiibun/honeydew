# Introduction

**honeydew** is an interactive terminal database client built with [MoonBit](https://moonbitlang.com).
It runs entirely in the terminal and supports three database backends:

- **SQLite** — file-based and in-memory databases
- **PostgreSQL** — local or remote servers
- **MySQL** — local or remote servers

## How it looks

honeydew uses a three-pane layout:

```text
┌─────────────────────────────────────────────────────────────┐
│ my-profile                          F1=Help  Ctrl+Q=Quit    │ ← menu bar
├────────────┬────────────────────────────────────────────────┤
│  Objects   │  SQL (Ctrl+Enter=run  Ctrl+F=find  F5=run all) │
│            │                                                 │
│ ▶ Tables   │  SELECT * FROM users;                          │
│   users    │                                                 │
│   orders   │                                                 │
│            ├────────────────────────────────────────────────┤
│            │  id │ name  │ email                            │
│            │  1  │ Alice │ alice@example.com                │
│            │  2  │ Bob   │ bob@example.com                  │
│            │                                                 │
└────────────┴────────────────────────────────────────────────┘
│ 2 rows                                                       │ ← status bar
└─────────────────────────────────────────────────────────────┘
```

- **Left pane** — Objects browser (tables, views, columns)
- **Top-right pane** — SQL editor with syntax highlighting
- **Bottom-right pane** — Query results

> The editor title bar shows only a selection of shortcuts. See [Key Bindings](reference/key-bindings.md) for the full list.

## Two screens

| Screen | Purpose |
|---|---|
| **Connect** | Manage connection profiles and open a database |
| **Main** | Browse schema, write SQL, inspect results |

Use `F1` at any time to see the available key bindings for the current screen.
