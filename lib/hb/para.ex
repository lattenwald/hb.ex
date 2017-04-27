defmodule Hb.Para do
  require Logger

  defp run([], tasks, results, _opts)
  when map_size(tasks) == 0, do: results

  defp run(todo, tasks, results, opts) do
    max_num = Keyword.get(opts, :num, 5)
    if map_size(tasks) < max_num and length(todo) > 0 do
      [fun|new_todo] = todo
      task = Task.async(fn ->
        res = fun.()
        send(self(), res)
      end)
      new_tasks = Map.put(tasks, task.ref, task)
      run(new_todo, new_tasks, results, opts)
    else
      receive do
        {ref, res} ->
          if Map.has_key?(tasks, ref) do
            run(todo, Map.delete(tasks, ref), [res|results], opts)
          else
            Logger.warn "unexpected ref"
          end
        {:DOWN, _, _, _, _} ->
          run(todo, tasks, results, opts)
        other ->
          Logger.warn "unexpected message: #{inspect other}"
      after
        Keyword.get(opts, :timeout, 5000) ->
          Logger.warn "timeout, #{length todo} stuffs todo left, failed to collect #{map_size tasks}"
          results
      end
    end
  end

  def para(stuff, opts \\ []) do
    run(stuff, %{}, [], opts)
  end

end
