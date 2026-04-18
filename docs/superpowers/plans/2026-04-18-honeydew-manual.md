# honeydew User Manual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete mdBook user manual for the honeydew TUI database client, covering installation, all UI screens, common workflows, and a full keybinding reference.

**Architecture:** A `docs/` directory at the repo root holds `book.toml` and a `src/` tree of Markdown files. The book is organised into four sections — Introduction, Getting Started, Screens, Workflows — plus a Reference chapter. Each task creates one or more Markdown files and verifies the book still builds.

**Tech Stack:** mdBook, Markdown

---

## File Map

| Action | Path |
|---|---|
| Create | `docs/book.toml` |
| Create | `docs/src/SUMMARY.md` |
| Create | `docs/src/introduction.md` |
| Create | `docs/src/getting-started/installation.md` |
| Create | `docs/src/getting-started/first-connection.md` |
| Create | `docs/src/getting-started/first-query.md` |
| Create | `docs/src/screens/connect-screen.md` |
| Create | `docs/src/screens/main-screen.md` |
| Create | `docs/src/screens/schema-browser.md` |
| Create | `docs/src/screens/sql-editor.md` |
| Create | `docs/src/screens/results-panel.md` |
| Create | `docs/src/workflows/transactions.md` |
| Create | `docs/src/workflows/export.md` |
| Create | `docs/src/workflows/explain.md` |
| Create | `docs/src/workflows/parameterized-queries.md` |
| Create | `docs/src/workflows/load-sql-file.md` |
| Create | `docs/src/reference/key-bindings.md` |
| Modify | `.gitignore` (root) — add `docs/book/` |

---

## Task 1: mdBook scaffold (book.toml + SUMMARY.md + .gitignore)

**Files:**
- Create: `docs/book.toml`
- Create: `docs/src/SUMMARY.md`
- Modify: `.gitignore`

- [ ] **Step 1: Install mdBook if not present**

```sh
cargo install mdbook
# verify
mdbook --version   # should print mdbook v0.4.x
```

- [ ] **Step 2: Create `docs/book.toml`**

```toml
[book]
title = "honeydew User Manual"
authors = []
language = "en"
src = "src"

[build]
build-dir = "book"

[output.html]
git-repository-url = "https://github.com/tiibun/honeydew"
edit-url-template = "https://github.com/tiibun/honeydew/edit/main/docs/{path}"
```

- [ ] **Step 3: Create `docs/src/SUMMARY.md`**

```markdown
# Summary

[Introduction](introduction.md)

# Getting Started

- [Installation](getting-started/installation.md)
- [Your First Connection](getting-started/first-connection.md)
- [Your First Query](getting-started/first-query.md)

# Screens

- [Connect Screen](screens/connect-screen.md)
- [Main Screen](screens/main-screen.md)
- [Schema Browser](screens/schema-browser.md)
- [SQL Editor](screens/sql-editor.md)
- [Results Panel](screens/results-panel.md)

# Workflows

- [Transactions](workflows/transactions.md)
- [Exporting Results](workflows/export.md)
- [EXPLAIN](workflows/explain.md)
- [Parameterized Queries](workflows/parameterized-queries.md)
- [Loading SQL from a File](workflows/load-sql-file.md)

# Reference

- [Key Bindings](reference/key-bindings.md)
```

- [ ] **Step 4: Create stub files for all chapters so mdBook can build**

Create each file listed below with just a `# Title` heading (they will be filled in subsequent tasks):

```sh
mkdir -p docs/src/getting-started docs/src/screens docs/src/workflows docs/src/reference

echo '# Introduction' > docs/src/introduction.md

echo '# Installation' > docs/src/getting-started/installation.md
echo '# Your First Connection' > docs/src/getting-started/first-connection.md
echo '# Your First Query' > docs/src/getting-started/first-query.md

echo '# Connect Screen' > docs/src/screens/connect-screen.md
echo '# Main Screen' > docs/src/screens/main-screen.md
echo '# Schema Browser' > docs/src/screens/schema-browser.md
echo '# SQL Editor' > docs/src/screens/sql-editor.md
echo '# Results Panel' > docs/src/screens/results-panel.md

echo '# Transactions' > docs/src/workflows/transactions.md
echo '# Exporting Results' > docs/src/workflows/export.md
echo '# EXPLAIN' > docs/src/workflows/explain.md
echo '# Parameterized Queries' > docs/src/workflows/parameterized-queries.md
echo '# Loading SQL from a File' > docs/src/workflows/load-sql-file.md

echo '# Key Bindings' > docs/src/reference/key-bindings.md
```

- [ ] **Step 5: Add `docs/book/` to `.gitignore`**

Append to the root `.gitignore`:

```
docs/book/
```

- [ ] **Step 6: Verify the book builds**

```sh
mdbook build docs
```

Expected: exits 0, `docs/book/index.html` exists.

- [ ] **Step 7: Commit**

```sh
git add docs/ .gitignore
git commit -m "docs: scaffold mdBook for user manual"
```

---

## Task 2: Introduction

**Files:**
- Modify: `docs/src/introduction.md`

- [ ] **Step 1: Write `docs/src/introduction.md`**

```markdown
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

## Two screens

| Screen | Purpose |
|---|---|
| **Connect** | Manage connection profiles and open a database |
| **Main** | Browse schema, write SQL, inspect results |

Use `F1` at any time to see the available key bindings for the current screen.
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/introduction.md
git commit -m "docs: write Introduction chapter"
```

---

## Task 3: Installation

**Files:**
- Modify: `docs/src/getting-started/installation.md`

- [ ] **Step 1: Write `docs/src/getting-started/installation.md`**

```markdown
# Installation

## Prerequisites

| Requirement | Notes |
|---|---|
| [MoonBit toolchain](https://www.moonbitlang.com/download) | `moon` CLI must be on your `PATH` |
| C compiler | `gcc` or `clang` (used for native FFI) |
| **SQLite** (optional) | Bundled — no extra library needed |
| **libpq** (optional) | Required only for PostgreSQL connections |
| **MySQL client library** (optional) | Required only for MySQL connections |

Install `libpq` on macOS with Homebrew:

```sh
brew install libpq
```

Install `libpq` on Debian/Ubuntu:

```sh
sudo apt install libpq-dev
```

Install the MySQL client library on macOS:

```sh
brew install mysql-client
```

Install the MySQL client library on Debian/Ubuntu:

```sh
sudo apt install libmysqlclient-dev
```

## Build from source

Clone the repository and build with `moon`:

```sh
git clone https://github.com/tiibun/honeydew
cd honeydew
moon build --target native
```

The first build downloads MoonBit dependencies and compiles all packages.
It may take a minute.

## Running honeydew

After a successful build the executable is at:

```
_build/native/release/build/tiibun/honeydew/cmd/main/main.exe
```

Run it directly:

```sh
./_build/native/release/build/tiibun/honeydew/cmd/main/main.exe
```

Or use `moon run` from the workspace root:

```sh
moon run honeydew/cmd/main
```

> **Tip:** Create a shell alias for convenience:
> ```sh
> alias honeydew='./_build/native/release/build/tiibun/honeydew/cmd/main/main.exe'
> ```
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/getting-started/installation.md
git commit -m "docs: write Installation chapter"
```

---

## Task 4: First Connection

**Files:**
- Modify: `docs/src/getting-started/first-connection.md`

- [ ] **Step 1: Write `docs/src/getting-started/first-connection.md`**

```markdown
# Your First Connection

When you launch honeydew you land on the **Connect screen**.

## Connect screen layout

```text
┌──────────────┬─────────────────────────────────────────┐
│  Profiles    │  New Connection                         │
│              │                                         │
│ (no profiles)│  Profile name  [                      ] │
│              │  Database      [SQLite                 ] │
│              │  Database file [:memory:               ] │
│              │                                         │
│              │  Ctrl+S=save  q=quit                    │
└──────────────┴─────────────────────────────────────────┘
```

The **left panel** lists saved profiles. The **right panel** shows the connection form for the selected or new connection.

## Connecting to an in-memory SQLite database

1. Leave the form at its defaults (Database: SQLite, file: `:memory:`).
2. Press `Enter` to connect.

honeydew opens the Main screen and creates a fresh in-memory database.

## Connecting to a PostgreSQL or MySQL server

1. In the form, press `↑` or `↓` on the **Database** row to change the database type.
2. Fill in the fields:

| Field | Description |
|---|---|
| Profile name | A label for saving this connection |
| Database | `SQLite`, `PostgreSQL`, or `MySQL` |
| Host | Server hostname (default: `localhost`) |
| Port | Server port (default varies by DB type) |
| Database | Database / schema name |
| Username | Login user |
| Password | Leave blank if none required |

3. Press `Enter` to connect.

## Saving a profile

Press `Ctrl+S` to save the current form as a named profile. The password is stored in the system keyring when available, otherwise in the profile file.

Saved profiles appear in the left panel on future launches. Select a profile with `↑`/`↓` and press `Enter` to connect without re-entering credentials.

## Deleting a profile

Select a profile in the left panel and press `d`.
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/getting-started/first-connection.md
git commit -m "docs: write First Connection chapter"
```

---

## Task 5: First Query

**Files:**
- Modify: `docs/src/getting-started/first-query.md`

- [ ] **Step 1: Write `docs/src/getting-started/first-query.md`**

```markdown
# Your First Query

After connecting you land on the **Main screen** with focus in the SQL editor.

## Writing SQL

Type your query in the editor pane. honeydew highlights SQL keywords as you type:

```sql
SELECT 1 + 1 AS result;
```

The editor supports multi-line input — press `Enter` to start a new line.

## Running the statement at the cursor

Press `Ctrl+Enter` to execute the statement the cursor is on.

The results appear in the bottom-right pane:

```text
 result
 ──────
 2
```

The status bar at the bottom shows the row count and execution time.

## Navigating the results

Move around the result grid with the arrow keys (`↑` `↓` `←` `→`).

## Running all statements

If the editor contains multiple statements separated by `;`, press `F5` to execute them all in sequence. honeydew shows a progress counter in the status bar while running.

## Cancelling a running query

Press `Ctrl+C` to cancel a query that is still running.

## Moving between panels

Press `Tab` to cycle focus between the Objects browser, the SQL editor, and the Results panel. The active panel is highlighted with a cyan border.

## Getting help

Press `F1` at any time to open the key bindings overlay for the current screen.
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/getting-started/first-query.md
git commit -m "docs: write First Query chapter"
```

---

## Task 6: Connect Screen (reference)

**Files:**
- Modify: `docs/src/screens/connect-screen.md`

- [ ] **Step 1: Write `docs/src/screens/connect-screen.md`**

```markdown
# Connect Screen

The Connect screen is the entry point for honeydew. It has two panels side by side.

## Profile list (left panel)

Lists all saved connection profiles. Navigate with `↑` / `↓`.

| Key | Action |
|---|---|
| `↑` / `↓` | Move selection |
| `Enter` | Load and connect with selected profile |
| `Tab` | Move focus to the connection form |
| `d` | Delete selected profile |

## Connection form (right panel)

| Field | Description |
|---|---|
| **Profile name** | Label used to identify the saved profile |
| **Database** | Database type: `SQLite`, `PostgreSQL`, or `MySQL` |
| **Host** | Server hostname (PostgreSQL/MySQL only) |
| **Port** | Server port (defaults: PostgreSQL=5432, MySQL=3306) |
| **Database** | File path or `:memory:` (SQLite); schema name (PostgreSQL/MySQL) |
| **Username** | Login user (PostgreSQL/MySQL only) |
| **Password** | Login password — leave blank if not required |

Navigate fields with `Tab` / `Shift+Tab`. On the **Database** row, press `↑` / `↓` to cycle through database types; the port and database defaults update automatically.

## Connecting

Press `Enter` on any field to connect with the current form values.

## Saving a profile

Press `Ctrl+S` to save the current form as a profile. The password is stored in the system keyring when available.

## Key bindings

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | Next / previous field |
| `↑` / `↓` | Change DB type (when on Database row) |
| `Enter` | Connect |
| `Ctrl+S` | Save profile |
| `d` | Delete selected profile |
| `q` / `Ctrl+Q` | Quit |
| `F1` | Key bindings help |
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/screens/connect-screen.md
git commit -m "docs: write Connect Screen chapter"
```

---

## Task 7: Main Screen Overview

**Files:**
- Modify: `docs/src/screens/main-screen.md`

- [ ] **Step 1: Write `docs/src/screens/main-screen.md`**

```markdown
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
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/screens/main-screen.md
git commit -m "docs: write Main Screen chapter"
```

---

## Task 8: Schema Browser

**Files:**
- Modify: `docs/src/screens/schema-browser.md`

- [ ] **Step 1: Write `docs/src/screens/schema-browser.md`**

```markdown
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
```

Top-level nodes group objects by type (Tables, Views). Expand a table to see its columns and their types.

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
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/screens/schema-browser.md
git commit -m "docs: write Schema Browser chapter"
```

---

## Task 9: SQL Editor

**Files:**
- Modify: `docs/src/screens/sql-editor.md`

- [ ] **Step 1: Write `docs/src/screens/sql-editor.md`**

```markdown
# SQL Editor

The SQL editor is the top-right pane of the Main screen. It is a full multi-line text editor with SQL syntax highlighting.

## Editing

Type SQL directly. Press `Enter` for new lines. Standard cursor movement works with the arrow keys.

Keywords such as `SELECT`, `FROM`, `WHERE`, `JOIN`, `INSERT`, `UPDATE`, and `DELETE` are highlighted automatically.

## Running queries

| Key | Action |
|---|---|
| `Ctrl+Enter` | Run the statement the cursor is on |
| `F5` | Run all statements in the buffer |
| `Ctrl+C` | Cancel a running query |
| `Ctrl+X` | Run `EXPLAIN` for the statement at the cursor |

## Search

Press `Ctrl+F` to open the search bar below the editor.

| Key | Action |
|---|---|
| `Ctrl+F` | Open search bar |
| `Enter` | Close search bar / accept and jump to first match |
| `n` | Jump to next match |
| `N` | Jump to previous match |

Matches are highlighted in the editor while the search bar is open.

## Query history

honeydew records every executed statement. When the cursor is on the **first line** of the editor, press `↑` to recall the previous history entry. When the cursor is on the **last line**, press `↓` to move forward through history.

## Loading SQL from a file

Press `Ctrl+O` to open a file-path prompt. Enter the path to a `.sql` file and press `Enter`; its contents are inserted into the editor. See [Loading SQL from a File](../workflows/load-sql-file.md).
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/screens/sql-editor.md
git commit -m "docs: write SQL Editor chapter"
```

---

## Task 10: Results Panel

**Files:**
- Modify: `docs/src/screens/results-panel.md`

- [ ] **Step 1: Write `docs/src/screens/results-panel.md`**

```markdown
# Results Panel

The Results panel occupies the bottom-right area of the Main screen. It displays query output as a scrollable grid.

## Navigation

| Key | Action |
|---|---|
| `↑` / `↓` | Move row selection up / down |
| `←` / `→` | Scroll columns left / right |
| `Tab` | Move focus to the Objects panel |

## Copying to clipboard

| Key | Action |
|---|---|
| `y` | Copy the selected **cell** value to the clipboard |
| `Y` | Copy the entire selected **row** as tab-separated text |

## Exporting results

Press `Ctrl+S` to export the full result set as a CSV file, or `Ctrl+J` to export as JSON. See [Exporting Results](../workflows/export.md).

## NULL values

`NULL` database values are displayed as `NULL` in the result grid.
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/screens/results-panel.md
git commit -m "docs: write Results Panel chapter"
```

---

## Task 11: Transactions Workflow

**Files:**
- Modify: `docs/src/workflows/transactions.md`

- [ ] **Step 1: Write `docs/src/workflows/transactions.md`**

```markdown
# Transactions

honeydew provides keyboard shortcuts for manual transaction control. A transaction groups multiple SQL statements into a single atomic unit.

## Starting a transaction

Press `Ctrl+B` to execute `BEGIN`. The menu bar turns **yellow** to indicate an active transaction.

## Committing

Press `Ctrl+M` to execute `COMMIT`. The menu bar returns to its normal cyan colour.

## Rolling back

Press `Ctrl+R` to execute `ROLLBACK` and discard all changes made since `BEGIN`.

## Transaction indicator

The yellow menu bar is a persistent reminder that uncommitted changes exist. It is visible regardless of which panel is focused.

## Key bindings

| Key | Action |
|---|---|
| `Ctrl+B` | BEGIN |
| `Ctrl+M` | COMMIT |
| `Ctrl+R` | ROLLBACK |

> **Note:** SQLite autocommits by default. Use `BEGIN` when you want to batch multiple writes or preview changes before committing.
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/workflows/transactions.md
git commit -m "docs: write Transactions chapter"
```

---

## Task 12: Exporting Results

**Files:**
- Modify: `docs/src/workflows/export.md`

- [ ] **Step 1: Write `docs/src/workflows/export.md`**

```markdown
# Exporting Results

After running a query you can export the result set to a file.

## CSV export

Press `Ctrl+S` to export the current results as a CSV file.

honeydew opens a file-path prompt. Enter the destination path (e.g. `results.csv`) and press `Enter`.

```text
Export path: results.csv
```

The file is written with a header row containing the column names, followed by one row per result row. Values are quoted as needed.

## JSON export

Press `Ctrl+J` to export the current results as a JSON file.

honeydew opens a file-path prompt. Enter the destination path (e.g. `results.json`) and press `Enter`.

The output is a JSON array of objects, each object keyed by column name:

```json
[
  {"id": 1, "name": "Alice", "email": "alice@example.com"},
  {"id": 2, "name": "Bob",   "email": "bob@example.com"}
]
```

## Key bindings

| Key | Action |
|---|---|
| `Ctrl+S` | Export as CSV |
| `Ctrl+J` | Export as JSON |
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/workflows/export.md
git commit -m "docs: write Exporting Results chapter"
```

---

## Task 13: EXPLAIN

**Files:**
- Modify: `docs/src/workflows/explain.md`

- [ ] **Step 1: Write `docs/src/workflows/explain.md`**

```markdown
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
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/workflows/explain.md
git commit -m "docs: write EXPLAIN chapter"
```

---

## Task 14: Parameterized Queries

**Files:**
- Modify: `docs/src/workflows/parameterized-queries.md`

- [ ] **Step 1: Write `docs/src/workflows/parameterized-queries.md`**

```markdown
# Parameterized Queries

When a SQL statement contains `?` placeholders, honeydew shows a parameter form before execution. This lets you supply values interactively without editing the SQL.

## Writing a parameterized statement

Use standard `?` placeholders:

```sql
SELECT * FROM users WHERE id = ? AND active = ?;
```

## Supplying values

Press `Ctrl+Enter` (or `F5`) to run the statement. honeydew detects the placeholders and opens the parameter overlay:

```text
┌─── Run with Parameters ──────────────────┐
│  ?1  [                                  ]│
│  ?2  [                                  ]│
│                                          │
│  Tab=next  Shift+Tab=prev  Enter=run  Esc=cancel │
└──────────────────────────────────────────┘
```

Fill in each field and press `Enter` to execute. Values are substituted as-is (no quoting is added), so include quotes in string values:

| Placeholder | Value to enter |
|---|---|
| integer | `42` |
| string | `'Alice'` |
| NULL | `NULL` |

## Navigation in the form

| Key | Action |
|---|---|
| `Tab` | Next field |
| `Shift+Tab` | Previous field |
| `Enter` | Execute with the supplied values |
| `Esc` | Cancel and return to the editor |
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/workflows/parameterized-queries.md
git commit -m "docs: write Parameterized Queries chapter"
```

---

## Task 15: Loading SQL from a File

**Files:**
- Modify: `docs/src/workflows/load-sql-file.md`

- [ ] **Step 1: Write `docs/src/workflows/load-sql-file.md`**

```markdown
# Loading SQL from a File

You can load a `.sql` file from disk directly into the editor.

## Usage

1. Press `Ctrl+O` in the Main screen. A file-path prompt appears in the status bar:

```text
Open file: _
```

2. Type the path to the file (relative to the working directory, or absolute) and press `Enter`.

```text
Open file: ~/queries/report.sql
```

The file contents are inserted into the SQL editor. Any existing content in the editor is replaced.

3. Review the SQL and run with `Ctrl+Enter` or `F5`.

## Key bindings

| Key | Action |
|---|---|
| `Ctrl+O` | Open file-path prompt |
| `Enter` | Load the file |
| `Esc` | Cancel |
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/workflows/load-sql-file.md
git commit -m "docs: write Load SQL from File chapter"
```

---

## Task 16: Key Bindings Reference

**Files:**
- Modify: `docs/src/reference/key-bindings.md`

- [ ] **Step 1: Write `docs/src/reference/key-bindings.md`**

```markdown
# Key Bindings

## Connect screen

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | Next / previous field |
| `↑` / `↓` | Change DB type (when on Database row) / move profile selection |
| `Enter` | Connect / load selected profile |
| `Ctrl+S` | Save profile to keyring |
| `d` | Delete selected profile |
| `q` / `Ctrl+Q` | Quit |
| `F1` | Show / close key bindings help |

## Main screen — global

| Key | Action |
|---|---|
| `Tab` | Switch focus to next panel |
| `Ctrl+Q` | Quit |
| `Ctrl+D` | Disconnect (return to Connect screen) |
| `F1` | Show / close key bindings help |

## Main screen — SQL editor

| Key | Action |
|---|---|
| `Ctrl+Enter` | Run statement at cursor |
| `F5` | Run all statements |
| `Ctrl+C` | Cancel running query |
| `Ctrl+X` | Run EXPLAIN for statement at cursor |
| `Ctrl+F` | Open in-editor search bar |
| `Enter` | Close search bar / accept |
| `n` | Next search match |
| `N` | Previous search match |
| `Ctrl+O` | Load SQL from file |
| `↑` (at first line) | Recall previous history entry |
| `↓` (at last line) | Recall next history entry |

## Main screen — Results panel

| Key | Action |
|---|---|
| `↑` / `↓` | Move row selection |
| `←` / `→` | Scroll columns |
| `y` | Copy selected cell to clipboard |
| `Y` | Copy selected row (tab-separated) to clipboard |
| `Ctrl+S` | Export results as CSV |
| `Ctrl+J` | Export results as JSON |

## Main screen — Objects panel

| Key | Action |
|---|---|
| `↑` / `↓` | Move selection |
| `Space` / `Enter` | Expand or collapse node |
| `→` | Expand node |
| `←` | Collapse node |
| `Ctrl+L` | Refresh schema from database |

## Main screen — transactions

| Key | Action |
|---|---|
| `Ctrl+B` | BEGIN |
| `Ctrl+M` | COMMIT |
| `Ctrl+R` | ROLLBACK |

## Main screen — errors

| Key | Action |
|---|---|
| `Ctrl+E` | Show full error details overlay |
| any key | Close error overlay |
```

- [ ] **Step 2: Build and verify**

```sh
mdbook build docs
```

Expected: exits 0.

- [ ] **Step 3: Commit**

```sh
git add docs/src/reference/key-bindings.md
git commit -m "docs: write Key Bindings reference chapter"
```

---

## Task 17: Final polish

- [ ] **Step 1: Full build and link check**

```sh
mdbook build docs
# If mdbook-linkcheck is installed:
# mdbook-linkcheck docs
```

Expected: exits 0, no broken links.

- [ ] **Step 2: Spot-check rendered output**

```sh
mdbook serve docs
```

Open `http://localhost:3000` and verify:
- SUMMARY sidebar shows all chapters
- Introduction renders correctly
- Key Bindings tables are aligned
- No placeholder headings remain

- [ ] **Step 3: Commit any fixes, then final commit**

```sh
git add -A
git commit -m "docs: finalize honeydew user manual"
```
