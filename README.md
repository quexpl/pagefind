# Pagefind

[![Actions Status](https://github.com/quexpl/pagefind/workflows/CI/badge.svg)](https://github.com/quexpl/pagefind/actions?query=workflow%3ACI)
[![Hex pm](https://img.shields.io/hexpm/v/pagefind.svg?style=flat)](https://hex.pm/packages/pagefind)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/pagefind)

Mix task for installing and invoking [pagefind](https://www.pagefind.app).
Heavily inspired by tailwind and esbuild.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pagefind` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pagefind, "~> 0.1.0"}
  ]
end
```

Once installed, change your `config/config.exs` and pick a version for the pagefind CLI of your choice:

```elixir
config :pagefind, version: "1.3.0"
```

Now you can install pagefind by running:

```
$ mix pagefind.install
```

And invoke pagefind with:
```
$ mix pagefind --site dist --output-subdir search --exclude-selectors "#my_navigation, blockquote > span, [id^='prefix-']"
```
The executable is kept at `_build/pagefind-TARGET`. Where `TARGET` is your system target architecture.

## Adding to Tableau

To add `pagefind` to an application using Tableau, you need only two steps:

First add a new extension which will trigger Pagefind in `lib/extensions/pagefind_extension.ex`:

```elixir
defmodule MyAapp.PagefindExtension do
  use Tableau.Extension, enabled: true, type: :post_write, key: :search, priority: 500

  def run(token) do
    Pagefind.install_and_run([]);
    {:ok, token}
  end
end
```

Now let's change `config/config.exs` to configure `pagefind`:

```elixir
config :pagefind, version: "1.3.0", args: ["--site", "_site"]
```

That's all.

## License

Copyright (c) 2025 Piotr Baj.

pagefind source code is licensed under the [MIT License](LICENSE.md).
