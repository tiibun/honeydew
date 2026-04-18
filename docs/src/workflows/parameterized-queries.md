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
│  Tab=next  Enter=run  Ctrl+S=save preset  Ctrl+P=presets  Esc=cancel │
└──────────────────────────────────────────┘
```

Fill in each field and press `Enter` to execute. Values are substituted as-is (no quoting is added), so include quotes in string values:

| Placeholder | Value to enter |
|---|---|
| integer | `42` |
| string | `'Alice'` |
| NULL | `NULL` |

## Saving and loading presets

Press `Ctrl+S` to save the current parameter values as a named preset. Press `Ctrl+P` to open the preset list and load previously saved values.

## Navigation in the form

| Key | Action |
|---|---|
| `Tab` | Next field |
| `Enter` | Execute with the supplied values |
| `Ctrl+S` | Save current values as a named preset |
| `Ctrl+P` | Open preset list |
| `Esc` | Cancel and return to the editor |
