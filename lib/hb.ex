defmodule Hb do
  require Logger

  def run(opts) do
    platform = opts[:platform]
    dir = opts[:to]
    size_limit = opts[:limit]

    File.cd!(dir)

    IO.puts "fetching bundles info"

    flattened = Hb.Dl.bundles |> Hb.Dl.filter_platform(platform) |> Hb.Dl.flatten_bundles()
    IO.puts "checking existing files"

    flattened |> Hb.Util.check_files(remove: true, save: true)

    IO.puts "choosing files to download"

    dir_size = Hb.Util.dir_size(".")

    free_size = size_limit - dir_size

    saved_data = Hb.Util.load_data()

    IO.puts "total count #{length flattened}"

    not_yet_downloaded = flattened |> Enum.filter(&(!Map.has_key?(saved_data, &1["dl_fname"])))

    IO.puts "not yet downloaded #{length not_yet_downloaded}"

    to_download = not_yet_downloaded |> Hb.Dl.filter_size(free_size)

    IO.puts "to download #{length to_download}"

    IO.puts "downloading"

    to_download
    |> Enum.map(&(fn ->
          hname = &1["download"]["subproduct"]["human_name"]
          IO.puts "downloading #{hname} (#{&1["human_size"]})"
          Hb.Dl.download(&1)
          |> case do
               :ok ->
                 Hb.Util.save_data(&1)
                 IO.puts "finished with #{hname}"
               _other ->
                 Logger.warn "failed downloading #{inspect &1}"
             end
        end))
    |> Hb.Para.para(timeout: 60*60*1000, num: 4)
  end

end
