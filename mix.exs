defmodule Hb.Mixfile do
  use Mix.Project

  def project do
    [app: :hb,
     version: "0.1.0",
     elixir: "~> 1.4",
     escript: [main_module: Hb.CLI, name: "hb.ex"],
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, "~> 0.11.1"},
      {:poison, "~> 3.1"},
      {:flow, "~> 0.11.1"},
    ]
  end
end
