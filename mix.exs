defmodule UzuParser.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/rpmessner/uzu_parser"

  def project do
    [
      app: :uzu_parser,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "UzuParser",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Parser for Uzu pattern mini-notation, used in live coding and algorithmic music.
    Converts text-based patterns into timed musical events.
    """
  end

  defp package do
    [
      name: "uzu_parser",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
