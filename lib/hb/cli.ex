defmodule Hb.CLI do
  @moduledoc """
  Usage: hbex --platform android --to dl/
  """
  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  def parse_args(argv) do
    {parsed, _rest, invalid} = OptionParser.parse(
      argv,
      switches: [ help: :boolean,
                  platform: :string,
                  limit: :integer,
                  to: :string ],
      aliases: [ h: :help,
                 p: :platform,
                 l: :limit,
                 t: :to ])
    cond do
      length(invalid) > 0 ->
        {:invalid_opts, invalid}
      parsed[:help] ->
        :help
      true ->
        parsed
        |> Keyword.put_new(:to, "dl")
        |> Keyword.put_new(:platform, "android")
        |> Keyword.put_new(:limit, 10000000000)
    end
  end

  def process({:invalid_opts, invalid}) do
    invalid_str =
      invalid
      |> Enum.map(fn {key, _val} -> key end)
      |> Enum.join(", ")
    IO.puts """
    Unknown options: #{invalid_str}
    """
    System.halt(1)
  end

  def process(:help) do
    IO.puts "Nobody will help you" # TODO:
    System.halt(0)
  end

  def process(opts) do
    Hb.run(opts)
  end

end
