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
