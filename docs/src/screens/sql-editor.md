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
| `Ctrl+C` | Cancel a running query (exits honeydew when idle) |
| `Ctrl+X` | Run `EXPLAIN` for the statement at the cursor |

## Search

Press `Ctrl+F` to open the search bar below the editor.

| Key | Action |
|---|---|
| `Ctrl+F` | Open search bar |
| `Enter` | Close search bar and jump to first match |
| `n` | Jump to next match |
| `N` | Jump to previous match |

Matches are highlighted in the editor while the search bar is open.

## Query history

honeydew records every executed statement. When the cursor is on the **first line** of the editor, press `↑` to recall the previous history entry. When the cursor is on the **last line**, press `↓` to move forward through history.

## Loading SQL from a file

Press `Ctrl+O` to open a file-path prompt. Enter the path to a `.sql` file and press `Enter`; its contents are inserted into the editor. See [Loading SQL from a File](../workflows/load-sql-file.md).
