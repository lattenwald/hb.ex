defmodule Hb do
  require Logger

  def run(opts) do
    platform = opts[:platform]
    dir = opts[:to]
    size_limit = opts[:limit]

    File.cd!(dir)
    {:ok, _pid} = Hb.Saver.start_link()

    flattened =
      ProgressBar.render_spinner(
        [
          frames: :braille,
          text: "Fetching bundles info",
          done: "✔ Fetching bundles info"
        ],
        fn ->
          Hb.Dl.bundles() |> Hb.Dl.filter_platform(platform) |> Hb.Dl.flatten_bundles()
        end
      )

    ProgressBar.render_spinner(
      [
        frames: :braille,
        text: "Checking existing files",
        done: "✔ Checking existing files"
      ],
      fn ->
        flattened |> Hb.Util.check_files(remove: true, save: true)
      end
    )

    {to_download, not_yet_downloaded, free_size} =
      ProgressBar.render_spinner(
        [
          frames: :braille,
          text: "Choosing files to download",
          done: "✔ Choosing files to download"
        ],
        fn ->
          dir_size = Hb.Util.dir_size(".")
          saved_data = Hb.Util.load_data()

          not_yet_downloaded =
            flattened |> Enum.filter(&(!Map.has_key?(saved_data, &1["dl_fname"])))

          not_yet_downloaded_size =
            not_yet_downloaded |> Enum.map(& &1["file_size"]) |> Enum.sum()

          free_size = min(size_limit - dir_size, not_yet_downloaded_size + 1)
          to_download = not_yet_downloaded |> Hb.Dl.filter_size(free_size)
          {to_download, not_yet_downloaded, free_size}
        end
      )

    IO.puts("Downloading #{length(to_download)}/#{length(not_yet_downloaded)} files")

    {:ok, dl_progress} = Agent.start_link(fn -> 0 end)

    {:ok, dl_files} = Agent.start_link(fn -> MapSet.new() end)

    to_download
    |> Task.async_stream(
      fn f ->
        hname = f["download"]["subproduct"]["human_name"]

        id_str = "#{hname} (#{f["human_size"]})"

        Agent.update(dl_files, &MapSet.put(&1, id_str))
        IO.puts("downloading #{id_str}")

        Hb.Dl.download(f, fn data ->
          Agent.update(dl_progress, &(&1 + byte_size(data)))
          ProgressBar.render(Agent.get(dl_progress, & &1), free_size)
        end)
        |> case do
          :ok ->
            Agent.update(dl_files, &MapSet.delete(&1, id_str))
            Hb.Util.save_data(f)
            IO.puts("\n")

          _other ->
            Logger.warn("failed downloading #{inspect(f)}")
        end
      end,
      max_concurrency: 5,
      timeout: :infinity
    )
    |> Stream.run()
  end
end
