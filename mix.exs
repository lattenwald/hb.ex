defmodule Hb.Mixfile do
  use Mix.Project

  def project do
    [app: :hb,
     version: "0.1.1",
     elixir: "~> 1.7",
     escript: [main_module: Hb.CLI, name: "hb.ex"],
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:httpoison, "~> 1.4"},
      {:poison, "~> 4.0"},
      {:progress_bar, "~> 1.6"},
    ]
  end
end
