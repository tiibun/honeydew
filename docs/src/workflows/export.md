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
