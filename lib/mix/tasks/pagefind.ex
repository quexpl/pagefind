defmodule Mix.Tasks.Pagefind do
  @moduledoc """
  Invokes pagefind with given args.

  Usage:

      $ mix pagefind PAGEFIND_ARGS

  Example:

      $ mix pagefind --site "public"

  If pagefind is not installed, it is automatically downloaded.
  Note the arguments given to this task will be appended
  to any configured arguments.
  """

  use Mix.Task

  @impl true
  def run(args) do
    if function_exported?(Mix, :ensure_application!, 1) do
      Mix.ensure_application!(:inets)
      Mix.ensure_application!(:ssl)
    end

    Mix.Task.run("loadpaths")
    Application.ensure_all_started(:pagefind)

    Mix.Task.reenable("pagefind")
    install_and_run(args)
  end

  defp install_and_run(args) do
    case Pagefind.install_and_run(args) do
      0 -> :ok
      status -> Mix.raise("`mix pagefind #{Enum.join(args, " ")}` exited with #{status}")
    end
  end
end
