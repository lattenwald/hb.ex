defmodule Hb do
  require Logger

  def run(opts) do
    platform = opts[:platform]
    dir = opts[:to]
    size_limit = opts[:limit]

    File.cd!(dir)

    flattened = Hb.Dl.bundles |> Hb.Dl.filter_platform(platform) |> Hb.Dl.flatten_bundles()

    flattened |> Hb.Util.check_files(remove: true, save: true)

    dir_size = Hb.Util.dir_size(".")

    free_size = size_limit - dir_size

    to_download = flattened |> Hb.Dl.filter_size(free_size)

    to_download
    |> Enum.map(fn f ->
      Hb.Dl.download(f)
      |> case do
           :ok -> Hb.Util.save_data(f)
           other ->
             Logger.warn "failed downloading #{inspect f}"
         end
    end)
  end

end
