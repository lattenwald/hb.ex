defmodule Hb.Dl do
  require Logger

  @domain "www.humblebundle.com"
  @timeout 30000

  def url(path), do: "https://#{@domain}/#{path}"

  def get!(path) do
    Logger.info "fetching #{path}"
    HTTPoison.get!(
      url(path), %{},
      hackney: [cookie: [Hb.Util.cookie_header(@domain)], timeout: @timeout]
    )
  end

  def download!(url, fname) do
    begin_download = fn ->
      Logger.debug "begin_download"
      {:ok, 200, _headers, client} =
        :hackney.get(url, [], "")
      client
    end

    continue_download = fn client ->
      # Logger.debug "continue_download"
      :hackney.stream_body(client)
      |> case do
           {:ok, data} ->
             {[data], client}
           :done ->
             {:halt, client}
           {:error, reason} ->
             raise reason
         end
    end

    finish_download = fn _client ->
      Logger.debug "finish_download"
    end

    Path.dirname(fname) |> File.mkdir_p!

    Logger.info "downloading #{url}\n to #{fname}"
    Stream.resource(
      begin_download,
      continue_download,
      finish_download
    )
    |> Stream.into(File.stream!(fname))
    |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final |> Base.encode16(case: :lower)
  end

  def gamekeys do
    %{status_code: 200, body: body} =
      get!("home/library")

    Regex.named_captures(~r/var gamekeys =\s*\[(?<gamekeys>.*?)\]/, body)["gamekeys"]
    |> String.split(", ")
    |> Enum.map(&String.trim_leading(&1, "\""))
    |> Enum.map(&String.trim_trailing(&1, "\""))
  end

  def bundle(key) do
    %{status_code: 200, body: body} =
      get!("api/v1/order/#{key}?all_tpkds=true")

    body
    |> Poison.decode!
  end

  def bundles do
    gamekeys()
    |> Enum.map(&(fn -> bundle(&1) end))
    |> Hb.Util.para(30000)
  end

  def filter_platform(bundles, platform) when is_list(bundles) do
    bundles
    |> Stream.map(&filter_platform(&1, platform))
    |> Enum.filter(&not(is_nil(&1)))
  end
  def filter_platform(bundle, platform) do
    extract_platform_downloads = fn(subproduct) ->
      case Enum.filter(subproduct["downloads"], &(&1["platform"] == platform)) do
        [] -> nil
        dls -> %{subproduct | "downloads" => dls}
      end
    end

    bundle["subproducts"]
      |> Stream.map(&extract_platform_downloads.(&1))
      |> Enum.filter(&not(is_nil(&1)))
      |> case  do
           [] -> nil
           subproducts -> %{bundle | "subproducts" => subproducts}
         end
  end

  defp to_top(map, key, name) do
    new_map = Map.delete(map, key)
    Enum.map(map[key], &Map.put(&1, name, new_map))
  end

  def flatten_bundles(bundles) do
    bundles
    |> Stream.flat_map(&to_top(&1, "subproducts", "bundle"))
    |> Stream.flat_map(&to_top(&1, "downloads", "subproduct"))
    |> Stream.flat_map(&to_top(&1, "download_struct", "download"))
    |> Stream.filter(&Map.has_key?(&1, "url"))
    |> Stream.map(&Map.put(&1, "dl_fname",
        Path.join([
          &1["download"]["platform"],
          Regex.replace(
            ~r/[^\da-zA-Z \-_\.]/,
            &1["download"]["subproduct"]["human_name"],
            "_",
            global: true),
          URI.parse(&1["url"]["web"]).path
        ])))
    |> Enum.into([])
  end

  def filter_size(bundles, size_limit, initial_size \\ 0) do
    folder = fn flattened=%{"file_size" => fsize}, acc={bundles_acc, size_acc} ->
      if fsize + size_acc >= size_limit do
        acc
      else
        {[flattened | bundles_acc], fsize + size_acc}
      end
    end

    {files, _resulting_size} = bundles |> List.foldl({[], initial_size}, folder)
    files
  end

  def download(%{"url" => %{"web" => dl_url}, "dl_fname" => dl_fname, "md5" => expected_md5}) do
    calculated_md5 = download!(dl_url, dl_fname)
    if calculated_md5 == expected_md5 do
      :ok
    else
      File.rm! dl_fname
      {:error, :invalid_checksum}
    end
  end

end

# bundle = %{
#   "subproducts" => [
#   %{
#     "gamekey" => gamekey,
#     "human_name" => hname,
#     "downloads" => [
#     %{
#       "platform" => platform,
#       "machine_name" => mname,
#       "download_struct" => [
#         %{
#           "file_size" => fsize,
#           "url" => %{"web" => dlurl}
#         }]}
#   ]}
# ]}

# Hb.Dl.bundles |> Hb.Dl.filter_platform("android")
