defmodule Hb.CLI do
  require Logger

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
                  limit: :string,
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
        |> Keyword.put_new(:limit, "10G")
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
    normalized_opts =
      Keyword.put(opts, :limit, size_to_int(opts[:limit]))

    opts_str =
      normalized_opts
      |> Enum.map(fn {k, v} -> "--#{k} #{v}" end)
      |> Enum.join(" ")
    Logger.info "Running with options: #{opts_str}"

    Hb.run(normalized_opts)
  end

  def size_to_int(s) do
    Regex.named_captures(~r/^(?<size>\d+)(?<unit>(?:[GMKB]|))?$/, s)
    |> case do
         %{"unit" => unit, "size" => size} -> String.to_integer(size) * size_int(unit)
         other -> raise "failed parsing size limit #{inspect s} #{inspect other}"
       end
  end

  defp size_int("G"), do: 1000000000
  defp size_int("M"), do: 1000000
  defp size_int("K"), do: 1000
  defp size_int("B"), do: 1
  defp size_int(""),  do: 1

end
