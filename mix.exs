defmodule Pagefind.MixProject do
  use Mix.Project

  def project do
    [
      app: :pagefind,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Mix task for installing and invoking the pagefind",
      package: [
        links: %{
          "GitHub" => "https://github.com/quexpl/pagefind",
          "pagefind" => "https://pagefind.app/"
        },
        maintainers: ["Piotr Baj"],
        licenses: ["MIT"]
      ],
      docs: [
        main: "Pagefind",
        extras: ["CHANGELOG.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, inets: :optional, ssl: :optional],
      mod: {Pagefind, []},
      env: [default: []]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
