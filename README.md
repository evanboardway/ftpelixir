# Ftpelixir

A simple FTP server and client written in Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ftpelixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ftpelixir, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ftpelixir](https://hexdocs.pm/ftpelixir).

## How to run

Run each file on its respective machine using `elixir lib/<filename.exs>`

Running a file within the `lib` folder will cause errors in file reading / writing.

## File storage

Files for the client should be stored in /client_files
Files for the server should be stored in /server_files