# Installation

## Prerequisites

| Requirement | Notes |
|---|---|
| [MoonBit toolchain](https://www.moonbitlang.com/download) | `moon` CLI must be on your `PATH` |
| C compiler | `gcc` or `clang` (used for native FFI) |
| **SQLite** | Bundled — no extra library needed |
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