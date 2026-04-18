# honeydew User Manual — Design Spec

**Date:** 2026-04-18  
**Status:** Approved

## Problem Statement

honeydew is an interactive TUI database client for SQLite, PostgreSQL, and MySQL written in MoonBit. It currently has no user-facing documentation beyond a short README. End users need a structured reference that covers installation, daily usage, and all features of the application.

## Proposed Approach

Produce an English-language mdBook manual targeting end users of the honeydew database client. The structure is **hybrid**: a linear Getting Started tutorial guides new users through their first session, dedicated Screens sections describe each UI panel as a reference, Workflows cover cross-cutting tasks, and a Reference section provides a complete keybinding table.

## Book Location

```
docs/
  book.toml
  src/
    SUMMARY.md
    introduction.md
    getting-started/
    screens/
    workflows/
    reference/
  book/             # generated output — added to .gitignore
```

The `docs/` folder is created at the repository root. Generated output (`docs/book/`) is git-ignored.

## Chapter Structure

### Introduction (`src/introduction.md`)
What honeydew is, supported databases (SQLite, PostgreSQL, MySQL), and a brief orientation to the two main screens.

### Getting Started
| File | Content |
|---|---|
| `installation.md` | Prerequisites (MoonBit toolchain, native libs), building from source with `moon build` |
| `first-connection.md` | Launching honeydew, creating a connection profile, connecting to a database |
| `first-query.md` | Typing SQL in the editor, running with `Ctrl+Enter`, reading the results |

### Screens (UI reference)
| File | Content |
|---|---|
| `connect-screen.md` | Profile list navigation, connection form fields, keyring-backed password storage, saving and deleting profiles |
| `main-screen.md` | 3-pane layout overview (Objects / Editor / Results), menu bar, status bar, transaction indicator |
| `schema-browser.md` | Objects panel, expanding/collapsing tables and views, column listing, refresh with `Ctrl+L` |
| `sql-editor.md` | Multi-line editing, SQL syntax highlighting, in-editor search (`Ctrl+F`, `n`/`N`), query history recall (↑/↓ at buffer boundary) |
| `results-panel.md` | Keyboard navigation in result grid, copying a cell (`y`) or row (`Y`) to clipboard |

### Workflows (task-oriented guides)
| File | Content |
|---|---|
| `transactions.md` | Beginning (`Ctrl+B`), committing (`Ctrl+M`), and rolling back (`Ctrl+R`) a transaction; transaction indicator in the menu bar |
| `export.md` | Exporting results as CSV (`Ctrl+S`) and as JSON (`Ctrl+J`) |
| `explain.md` | Running `EXPLAIN` for the statement at the cursor with `Ctrl+X` |
| `parameterized-queries.md` | Using `?` placeholders in SQL; the auto-generated parameter form overlay |
| `load-sql-file.md` | Loading a `.sql` file from disk into the editor with `Ctrl+O` |

### Reference
| File | Content |
|---|---|
| `key-bindings.md` | Complete keybinding tables for the Connect screen and the Main screen |

## book.toml Configuration

```toml
[book]
title = "honeydew User Manual"
authors = []
language = "en"
src = "docs/src"

[build]
build-dir = "docs/book"

[output.html]
git-repository-url = "https://github.com/tiibun/honeydew"
edit-url-template = "https://github.com/tiibun/honeydew/edit/main/{path}"
```

## Writing Conventions

- **Language:** English
- **Code blocks:** use language tags `sql`, `text`, or `moonbit`
- **Keybindings:** always formatted as `Ctrl+Enter`, `F1`, `↑`/`↓` (backtick-quoted in prose)
- **Screen examples:** ASCII/text representations of the TUI — no screenshots
- **Tone:** concise and instructional; one idea per sentence

## Build Commands

```sh
mdbook build docs   # build the book
mdbook serve docs   # live-reload preview at http://localhost:3000
```

## Hosting

Hosting destination is undecided. The book is self-contained HTML and can be served from GitHub Pages or any static host without changes.

## Out of Scope

- honeytui library API documentation (separate audience: library developers)
- Automated CI deployment pipeline (to be decided later)
- Non-English translations
