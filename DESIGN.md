# honeydew Design

## Overview

This repository is a MoonBit workspace with two modules:

| Module | Role |
|---|---|
| `honeytui` | Terminal UI toolkit: terminal I/O, diff-based rendering, layout, styles, and widgets |
| `honeydew` | Database client built on `honeytui` for SQLite, PostgreSQL, and MySQL |

The current codebase is no longer just a small TUI library prototype. It is a layered application where `honeytui` provides reusable UI primitives and `honeydew` uses them to implement an interactive SQL client.

## Workspace Layout

```text
moon.work
├── honeytui/   # reusable TUI library
└── honeydew/   # database client application
```

Each module has its own `moon.mod.json`, and the workspace ties them together through `moon.work`.

## High-Level Architecture

```text
keyboard / resize / mouse
          |
          v
  honeytui/terminal
          |
          v
     AppState + key handlers
          |
    +-----+------------------------+
    |                              |
    v                              v
DB drivers / async polling       UI rendering
    |                              |
    v                              v
 DbConn trait                 honeytui widgets
    |                              |
    +-----------+------------------+
                |
                v
         Frame -> Buffer -> diff -> ANSI output
```

`honeydew/cmd/main` owns the event loop and routes input based on the active screen, focused panel, and query state. `AppState` is the source of truth for connection settings, schema tree, SQL editor content, query history, results, overlays, and transaction state.

## `honeytui` Design

`honeytui` is the rendering and interaction layer.

### Core responsibilities

| Package | Responsibility |
|---|---|
| `terminal` | Raw mode, key decoding, resize handling, ANSI output |
| `buffer` | Cell grid, string width handling, diff rendering |
| `layout` | Rect splitting and placement helpers |
| `style` | Colors and text modifiers |
| `widget` | Reusable widgets such as `Block`, `Input`, `List`, `Paragraph`, `Table`, `TextArea`, and `Tree` |
| root package | `Terminal`, `Frame`, and `FocusRing` |

### Rendering model

`Terminal` owns a current and previous `Buffer`. A draw pass renders widgets into the current buffer, computes the diff against the previous buffer, and writes only changed cells to stdout. This keeps redraws small and makes the widgets independent from terminal escape-code details.

### Interaction model

`terminal/read_key` normalizes raw input into `terminal.Key`. Widgets such as `Input`, `TextArea`, `List`, `Table`, and `Tree` implement their own key handling so higher-level application code can compose them without duplicating cursor or selection logic.

## `honeydew` Design

`honeydew` is a stateful database client with two main screens:

1. **Connect screen** for profile selection and connection form editing
2. **Main screen** for schema browsing, SQL editing, and result inspection

### Main packages

| Package | Responsibility |
|---|---|
| `app` | `AppState`, connection flow, profile management, schema refresh, query history, transaction state, CSV export, clipboard copy |
| `ui` | Rendering of the connect screen, main screen, menu bar, help overlay, and error overlay |
| `db` | Shared database abstraction (`DbConn`, `QueryResult`, `ColumnInfo`) |
| `db/sqlite` | SQLite driver and native async query support |
| `db/postgres` | PostgreSQL driver built on `moonbit-community/postgres` |
| `db/mysql` | MySQL driver and native async query support |
| `config` | Profile persistence, keyring integration, clipboard helpers, CSV export helpers |
| `cmd/main` | Event loop, focus switching, SQL execution, polling, statement parsing, and status updates |

## State Model

`app/AppState` holds the runtime state for the whole client:

- active screen and focused panel
- current database connection
- connection form and saved profiles
- schema tree
- SQL editor (`widget.TextArea`)
- query history and history navigation draft
- results table
- status text and overlays
- transaction state
- running query state, cancellation flag, and reconnect flag

Keeping this state centralized lets the event loop stay simple: read input, update `AppState`, then render from state.

## Query Execution Flow

### Single statement

1. The editor keeps multi-line SQL in `widget.TextArea`.
2. `cmd/main` finds the statement at the cursor and starts execution through `DbConn`.
3. The running query is tracked in `AppState.running_query`.
4. The event loop polls the active driver until the query finishes.
5. Results are converted into a `widget.Table`, status text is updated, and transaction flags are synchronized.

### Run-all flow

`cmd/main` can also split the editor content into multiple statements and execute them sequentially, accumulating results and affected-row counts across the batch.

## Current UX Features

The current implementation includes:

- saved connection profiles
- keyring-backed password storage when available
- schema browser with tables, views, and columns
- multi-line SQL editor
- SQL syntax highlighting
- execution of the statement at the cursor and execution of all statements
- query history recall
- result grid navigation
- copy selected cell to clipboard
- export results as CSV
- transaction shortcuts and transaction indicator
- reconnect flow after connection loss
- cancellation of in-flight queries
- help and error overlays

## Design Principles

1. **Keep terminal concerns in `honeytui`** so application code deals with widgets and state instead of ANSI details.
2. **Keep database-specific logic behind `DbConn`** so the UI and app layers stay backend-agnostic.
3. **Render from immutable-style state updates** so input handling remains predictable.
4. **Prefer reusable widgets over screen-specific drawing code** to keep the application composable.
