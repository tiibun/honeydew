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
