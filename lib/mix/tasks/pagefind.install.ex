defmodule Mix.Tasks.Pagefind.Install do
  @moduledoc """
  Installs pagefind executable.

      $ mix pagefind.install
      $ mix pagefind.install --if-missing

  By default, it installs #{Pagefind.latest_version()} but you
  can configure it in your config files, such as:

      config :pagefind, :version, "#{Pagefind.latest_version()}"

  To install the Pagefind binary from a custom URL (e.g. if your platform isn't
  officially supported by Pagefind), you can supply a third party path to the
  binary (beware that we cannot guarantee the compatibility of any third party
  executable):

  ```bash
  $ mix pagefind.install https://example.com/path/to/pagefind_extended-v1.3.0-aarch64-unknown-linux-musl.tar.gz
  ```

  > **Note**: Make sure to use archived and compressed version of the `pagefind_extended` binary.

  ## Options

      * `--if-missing` - install only if the given version does not exist

  """

  use Mix.Task

  @impl true
  def run(args) do
    valid_options = [if_missing: :boolean]

    {opts, base_url} =
      case OptionParser.parse_head!(args, strict: valid_options) do
        {opts, []} ->
          {opts, Pagefind.default_base_url()}

        {opts, [base_url]} ->
          {opts, base_url}

        {_, _} ->
          Mix.raise("""
          Invalid arguments to pagefind.install, expected one of:

              mix pagefind.install
              mix pagefind.install 'https://github.com/CloudCannon/pagefind/releases/download/v$version/pagefind_extended-v$version-$target.tar.gz'
              mix pagefind.install --if-missing
          """)
      end

    if opts[:if_missing] && latest_version?() do
      :ok
    else
      if function_exported?(Mix, :ensure_application!, 1) do
        Mix.ensure_application!(:inets)
        Mix.ensure_application!(:ssl)
      end

      Mix.Task.run("loadpaths")
      Pagefind.install(base_url)
    end
  end

  defp latest_version?() do
    version = Pagefind.configured_version()
    match?({:ok, ^version}, Pagefind.bin_version())
  end
end
