defmodule Hb.CLI do
  require Logger

  @moduledoc """
  Usage: `hb.ex --platform android --to dl/ --limit 15G`

  Available platforms:

    * android
    * linux
    * mac
    * windows
    * ebook
    * audio

  --limit accepts maximum download directory size in formats

    * 10000 is 10000 bytes
    * 10000B is 10000 bytes
    * 10K is 10 kilobytes
    * 10M is 10 megabytes
    * 10G is 10 gigabytes

  Downloads directory (the one in `--to` parameter) should have `cookies.json` file
  with cookies for humblebundle.com in the following format:

      [
          {
              "domain": ".humblebundle.com",
              "name": "btIdentify",
              "value": "20fa45f4-1234-4236-db4f-327164388976qwr"
          },
          {
              "domain": "www.humblebundle.com",
              "name": "_simpleauth_sess",
              "value": "\"eyJ1c2VyX2NTU3fQ\\075\\075|1485690557|40dd0c1d5a0f18eb14bc7e3168e14850951ef2db\""
          },
          ...
      ]

  other fields in JSON structures are ignored. Recommended way to get cookies into this file is with [EditThisCookie](http://www.editthiscookie.com/) browser extension.

  Database of downloaded items is stored in downloads directory
  (the one in `--to` parameter) in file `db`. You can move downloaded stuff, while you leave database file in place nothing will be re-downloaded.

  Intended usage:

      ./hb.ex --platform android --to dl # download stuff into dl/ directory
      mv dl/android ~/cloud/             # move downloaded stuff to cloud storage
      ./hb.ex --platform android --to dl # download few gigabytes more
      # repeat
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
    IO.puts @moduledoc
    System.halt(0)
  end

  def process(opts) do
    normalized_opts =
      Keyword.put(opts, :limit, size_to_int(opts[:limit]))

    opts_str =
      normalized_opts
      |> Enum.map(fn {k, v} -> "--#{k} #{v}" end)
      |> Enum.join(" ")

    IO.puts "Running with options: #{opts_str}"

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
