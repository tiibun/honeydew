# Connect Screen

The Connect screen is the entry point for honeydew. It has two panels side by side.

## Profile list (left panel)

Lists all saved connection profiles. Navigate with `↑` / `↓`.

| Key | Action |
|---|---|
| `↑` / `↓` | Move selection |
| `Enter` | Load the selected profile into the form |
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
| `↑` / `↓` | Change DB type (when on Database row) / move profile selection |
| `Enter` | Load selected profile or connect |
| `Ctrl+S` | Save profile |
| `d` | Delete selected profile |
| `q` / `Ctrl+Q` | Quit (from profile list / anywhere) |
| `F1` | Key bindings help |
