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
| Database file / name | File path or `:memory:` (SQLite); schema name (PostgreSQL/MySQL) |
| Username | Login user |
| Password | Leave blank if none required |

3. Press `Enter` to connect.

## Saving a profile

Press `Ctrl+S` to save the current form as a named profile. The password is stored in the system keyring when available, otherwise in the profile file.

Saved profiles appear in the left panel on future launches. Select a profile with `↑`/`↓` and press `Enter` to connect without re-entering credentials.

## Deleting a profile

Select a profile in the left panel and press `d`.