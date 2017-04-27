defmodule Hb do
  require Logger

  def run(opts) do
    platform = opts[:platform]
    dir = opts[:to]
    size_limit = opts[:limit]

    File.cd!(dir)

    Logger.warn "fetching bundles info"

    flattened = Hb.Dl.bundles |> Hb.Dl.filter_platform(platform) |> Hb.Dl.flatten_bundles()
    Logger.warn "checking existing files"

    flattened |> Hb.Util.check_files(remove: true, save: true)

    Logger.warn "choosing files to download"

    dir_size = Hb.Util.dir_size(".")

    free_size = size_limit - dir_size

    to_download = flattened |> Hb.Dl.filter_size(free_size)

    Logger.warn "downloading"

    to_download
    |> Enum.map(&(fn ->
          Hb.Dl.download(&1)
          |> case do
               :ok -> Hb.Util.save_data(&1)
               _other ->
                 Logger.warn "failed downloading #{inspect &1}"
             end
        end))
    |> Hb.Para.para(timeout: 60*60*1000, num: 4)
  end

end
