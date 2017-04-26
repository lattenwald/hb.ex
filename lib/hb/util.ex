defmodule Hb.Util do
  require Logger

  @cookies_file "cookies.json"
  @db_file "db"

  def read_cookies(fname \\ @cookies_file) do
    File.read!(fname)
    |> Poison.decode!
  end

  def cookies_for_domain(domain, cookies_file \\ @cookies_file) do
    fltr = fn %{"domain" => d} ->
      if String.first(d) == "." do
        String.ends_with?(domain, d)
        || "." <> domain == d
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
        |> Enum.sum
      else
        err -> 0
      end
    else
      with {:ok, %{size: size, type: :regular}} <- File.lstat(path) do
        size
      else
        err -> 0
      end
    end
  end

  defp collect(tasks), do: collect(tasks, [])
  defp collect(tasks, acc) when map_size(tasks) == 0, do: acc
  defp collect(tasks, acc) do
    receive do
      {ref, res} ->
        if Map.has_key?(tasks, ref) do
          collect(Map.delete(tasks, ref), [res | acc])
        else
          "unexpected ref"
        end
      {:DOWN, _, _, _, _} ->
        collect(tasks, acc)
      other ->
        "unexpected message: #{inspect other}"
    after
      5000 ->
        Logger.warn "failed to collect #{inspect tasks}"
        acc
    end
  end

  def para(stuff, timeout \\ 5000) do
    # TODO: make it use limited pool
    stuff
    |> Enum.map(fn fun ->
      Task.async(fn ->
        res = fun.()
        send(self(), res)
      end)
    end)
    |> Enum.map(&{&1.ref, &1})
    |> Enum.into(%{})
    |> collect
  end

  def md5(path) do
    File.stream!(path, [], 4096)
    |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final
    |> Base.encode16(case: :lower)
  end

  # returns true-ish value if file exists and checksum ok or (checksum bad and file deleted)
  # returns false if file needs to be cleared (file exists, checksum bad, file not removed)
  # TODO: code is ugly, make it pretty
  def check_file(f=%{"md5" => md5_checksum, "dl_fname" => fname}, opts \\ []) do
    if File.exists?(fname) do
      calculated_md5 = md5(fname)
      if calculated_md5 == md5_checksum do
        if Keyword.get(opts, :save) do
          save_data(f)
        end
        :checksum_ok
      else
        Logger.debug "bad checksum #{fname}, expected #{md5_checksum}, got #{calculated_md5}"
        if Keyword.get(opts, :remove) do
          Logger.info "removing #{fname}"
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

  def save_data(%{"dl_fname" => dl_fname, "md5" => md5_checksum}) do
    data = load_data()

    if data[dl_fname] != md5_checksum do
      new_data = Map.put(data, dl_fname, md5_checksum)
      File.write!(@db_file, :erlang.term_to_binary(new_data))
    end
  end

  def load_data() do
    File.read(@db_file)
    |> case do
         {:ok, contents} -> :erlang.binary_to_term(contents)
         {:error, :enoent} -> %{}
       end
  end

end
