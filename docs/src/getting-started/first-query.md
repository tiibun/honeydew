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