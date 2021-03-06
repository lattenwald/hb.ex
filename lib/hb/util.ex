defmodule Hb.Util do
  require Logger

  @cookies_file "cookies.json"

  def read_cookies(fname \\ @cookies_file) do
    File.read!(fname)
    |> Poison.decode!()
  end

  def cookies_for_domain(domain, cookies_file \\ @cookies_file) do
    fltr = fn %{"domain" => d} ->
      if String.first(d) == "." do
        String.ends_with?(domain, d) || "." <> domain == d
      else
        domain == d
      end
    end

    read_cookies(cookies_file)
    |> Enum.filter(&fltr.(&1))
  end

  def cookie_header(domain, cookies_file \\ @cookies_file) do
    cookies_for_domain(domain, cookies_file)
    |> Stream.map(fn %{"name" => n, "value" => v} -> "#{n}=#{v}" end)
    |> Enum.join("; ")
  end

  def dir_size(path) do
    if File.dir?(path) do
      with {:ok, %{type: :directory}} <- File.lstat(path) do
        File.ls!(path)
        |> Enum.map(&dir_size(Path.join(path, &1)))
        |> Enum.sum()
      else
        _err -> 0
      end
    else
      with {:ok, %{size: size, type: :regular}} <- File.lstat(path) do
        size
      else
        _err -> 0
      end
    end
  end

  def md5(path) do
    File.stream!(path, [], 4096)
    |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  # returns true-ish value if file exists and checksum ok or (checksum bad and file deleted)
  # returns false if file needs to be cleared (file exists, checksum bad, file not removed)
  # TODO: code is ugly, make it pretty
  def check_file(f = %{"md5" => md5_checksum, "dl_fname" => fname}, opts \\ []) do
    if File.exists?(fname) do
      calculated_md5 = md5(fname)

      if calculated_md5 == md5_checksum do
        if Keyword.get(opts, :save) do
          save_data(f)
        end

        :checksum_ok
      else
        Logger.debug("bad checksum #{fname}, expected #{md5_checksum}, got #{calculated_md5}")

        if Keyword.get(opts, :remove) do
          Logger.warn("removing #{fname}")
          File.rm!(fname)
          :removed
        else
          false
        end
      end
    else
      :no_file
    end
  end

  def check_files(flattened_bundles, opts \\ []) do
    flattened_bundles |> Enum.map(&check_file(&1, opts))
  end

  def save_data(f) do
    Hb.Saver.save(f)
  end

  def load_data() do
    Hb.Saver.load()
  end
end

defmodule Hb.Saver do
  require Logger

  @db_file "db"

  use GenServer

  def start_link() do
    Logger.info("Starting #{__MODULE__}")
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def save(f) do
    GenServer.call(__MODULE__, {:save, f})
  end

  def load() do
    GenServer.call(__MODULE__, :load)
  end

  defp do_load() do
    File.read(@db_file)
    |> case do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      {:error, :enoent} -> %{}
    end
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_call(
        {:save, %{"dl_fname" => dl_fname, "md5" => md5_checksum}},
        _from,
        state
      ) do
    data = do_load()

    if data[dl_fname] != md5_checksum do
      new_data = Map.put(data, dl_fname, md5_checksum)
      File.write!(@db_file, :erlang.term_to_binary(new_data))
    end

    {:reply, :ok, state}
  end

  def handle_call(:load, _from, state) do
    data = do_load()
    {:reply, data, state}
  end
end
