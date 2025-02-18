defmodule Pagefind do
  @latest_version "1.3.0"
  @moduledoc """
  Pagefind is an installer and runner for [Pagefind](https://pagefind.app/)

  It will always download the `pagefind_extended` release,
  which includes specialized support for indexing Chinese and Japanese pages.


  ## Pagefind configuration

  There are the global configurations for the pagefind application:

    * `:version` - the expected pagefind version, defaults to `#{@latest_version}`
      the latest known version at the time of publishing this package.

    * `:path` - the path to find the pagefind executable at. By
      default, it is automatically downloaded and placed inside
      the `_build` directory of your current app

    * `:target` - the target architecture for the pagefind executable.
      For example `"x86_64-unknown-linux-musl"`. By default, it is automatically
      detected based on system information.

    * `:args` - the default arguments to pass to the pagefind executable.
      By default, it is an empty list.
      Read the [pagefind documentation](https://pagefind.app/docs/config-options/) for
      more information on the available arguments.

    * `:env` - optional environment variables to pass to the pagefind executable.

          config :pagefind,
            args: ~w(
              --site _site
            ),
            env: %{"PAGEFIND_OUTPUT_SUBDIR" => "pagefind"}

    Overriding the `:path` is not recommended, as we will automatically
    download and manage `pagefind` for you. But in case you can't download
    it (for example, GitHub behind a proxy), you may want to
    set the `:path` to a configurable system location.

    You can check the [pagefind docs](https://pagefind.app/docs/installation/) for
    more information on how to install it.

        config :pagefind, path: "/path/to/pagefind"
  """

  use Application
  require Logger

  @doc false
  def start(_, _) do
    unless Application.get_env(:pagefind, :path) do
      unless Application.get_env(:pagefind, :version) do
        Logger.warning("""
        pagefind version is not configured. Please set it in your config files:

            config :pagefind, :version, "#{latest_version()}"
        """)
      end

      configured_version = configured_version()

      case bin_version() do
        {:ok, ^configured_version} ->
          :ok

        {:ok, version} ->
          Logger.warning("""
          Outdated pagefind version. Expected #{configured_version}, got #{version}. \
          Please run `mix pagefind.install` or update the version in your config files.\
          """)

        :error ->
          :ok
      end
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc false
  # Latest known version at the time of publishing.
  def latest_version, do: @latest_version

  @doc """
  Returns the configured pagefind version.
  """
  def configured_version do
    Application.get_env(:pagefind, :version, latest_version())
  end

  @doc """
  Returns the configured pagefind target. By default, it is automatically detected.
  """
  def configured_target do
    Application.get_env(:pagefind, :target, target())
  end

  @doc """
  Returns the path to the executable.

  The executable may not be available if it was not yet installed.
  """
  def bin_path do
    name = "pagefind-#{configured_target()}"

    Application.get_env(:pagefind, :path) ||
      if Code.ensure_loaded?(Mix.Project) do
        Path.join(Path.dirname(Mix.Project.build_path()), name)
      else
        Path.expand("_build/#{name}")
      end
  end

  @doc """
  Returns the version of the pagefind executable.

  Returns `{:ok, version_string}` on success or `:error` when the executable
  is not available.
  """
  def bin_version do
    path = bin_path()

    with true <- File.exists?(path),
         {out, 0} <- System.cmd(path, ["--version"]),
         [vsn] <- Regex.run(~r/pagefind ([^\s]+)/, out, capture: :all_but_first) do
      {:ok, vsn}
    else
      _ -> :error
    end
  end

  @doc """
  Runs the given command with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It
  returns the status of the underlying call.
  """
  def run(extra_args) when is_list(extra_args) do
    args = Application.get_env(:pagefind, :args, [])
    env = Application.get_env(:pagefind, :env, [])

    opts = [
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true,
      env: env
    ]

    bin_path()
    |> System.cmd(args ++ extra_args, opts)
    |> elem(1)
  end

  @doc """
  Installs, if not available, and then runs `pagefind`.

  Returns the same as `run/1`.
  """
  def install_and_run(args) do
    unless File.exists?(bin_path()) do
      install()
    end

    run(args)
  end

  @doc """
  The default URL to install Pagefind from.
  """
  def default_base_url do
    "https://github.com/CloudCannon/pagefind/releases/download/v$version/pagefind-v$version-$target.tar.gz"
  end

  @doc """
  Installs pagefind with `configured_version/0`.
  """
  def install(base_url \\ default_base_url()) do
    url = get_url(base_url)
    bin_path = bin_path()
    archive_binary = fetch_body!(url)
    File.mkdir_p!(Path.dirname(bin_path))

    # MacOS doesn't recompute code signing information if a binary
    # is overwritten with a new version, so we force creation of a new file
    if File.exists?(bin_path) do
      File.rm!(bin_path)
    end

    case :erl_tar.extract({:binary, archive_binary}, [:compressed, :memory]) do
      {:ok, [{_filename, binary}]} ->
        File.write!(bin_path, binary, [:binary])

      {:error, reason} ->
        raise "Failed to extract pagefind: #{inspect(reason)}"
    end

    File.chmod(bin_path, 0o755)
  end

  # Available targets:
  # aarch64-apple-darwin
  # aarch64-unknown-linux-musl
  # x86_64-apple-darwin
  # x86_64-pc-windows-msvc
  # x86_64-unknown-linux-musl
  defp target do
    arch_str = :erlang.system_info(:system_architecture)

    arch =
      arch_str
      |> List.to_string()
      |> String.split("-")
      |> hd()

    case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
      {{:win32, _}, _arch, 64} ->
        "x86_64-pc-windows-msvc"

      {{:unix, :darwin}, arch, 64} when arch in ~w(arm aarch64) ->
        "aarch64-apple-darwin"

      {{:unix, :darwin}, "x86_64", 64} ->
        "x86_64-apple-darwin"

      {{:unix, :linux}, "aarch64", 64} ->
        "aarch64-unknown-linux-musl"

      {{:unix, _osname}, arch, 64} when arch in ~w(x86_64 amd64) ->
        "x86_64-unknown-linux-musl"

      {_os, _arch, _wordsize} ->
        raise "pagefind is not available for architecture: #{arch_str}"
    end
  end

  defp fetch_body!(url, retry \\ true) when is_binary(url) do
    scheme = URI.parse(url).scheme
    url = String.to_charlist(url)
    Logger.debug("Downloading pagefind from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = proxy_for_scheme(scheme) do
      %{host: host, port: port} = URI.parse(proxy)
      Logger.debug("Using #{String.upcase(scheme)}_PROXY: #{proxy}")
      set_option = if "https" == scheme, do: :https_proxy, else: :proxy
      :httpc.set_options([{set_option, {{String.to_charlist(host), port}, []}}])
    end

    http_options =
      [
        ssl: [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          depth: 2,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ],
          versions: protocol_versions()
        ]
      ]
      |> maybe_add_proxy_auth(scheme)

    options = [body_format: :binary]

    case {retry, :httpc.request(:get, {url, []}, http_options, options)} do
      {_, {:ok, {{_, 200, _}, _headers, body}}} ->
        body

      {_, {:ok, {{_, 404, _}, _headers, _body}}} ->
        raise """
        The pagefind binary couldn't be found at: #{url}

        This could mean that you're trying to install a version that does not support the detected
        target architecture.

        You can see the available files for the configured version at:

        https://github.com/CloudCannon/pagefind/releases/download/v#{configured_version()}
        """

      {true, {:error, {:failed_connect, [{:to_address, _}, {inet, _, reason}]}}}
      when inet in [:inet, :inet6] and
             reason in [:ehostunreach, :enetunreach, :eprotonosupport, :nxdomain] ->
        :httpc.set_options(ipfamily: fallback(inet))
        fetch_body!(to_string(url), false)

      other ->
        raise """
        Couldn't fetch #{url}: #{inspect(other)}

        This typically means we cannot reach the source or you are behind a proxy.
        You can try again later and, if that does not work, you might:

          1. If behind a proxy, ensure your proxy is configured and that
             your certificates are set via OTP ca certfile overide via SSL configuration.

          2. Manually download the executable from the URL above and
             place it inside "_build/pagefind-#{configured_target()}"

          3. Install Pagefind manually by following the instructions at:
             https://pagefind.app/docs/installation/
        """
    end
  end

  defp fallback(:inet), do: :inet6
  defp fallback(:inet6), do: :inet

  defp proxy_for_scheme("http") do
    System.get_env("HTTP_PROXY") || System.get_env("http_proxy")
  end

  defp proxy_for_scheme("https") do
    System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")
  end

  defp maybe_add_proxy_auth(http_options, scheme) do
    case proxy_auth(scheme) do
      nil -> http_options
      auth -> [{:proxy_auth, auth} | http_options]
    end
  end

  defp proxy_auth(scheme) do
    with proxy when is_binary(proxy) <- proxy_for_scheme(scheme),
         %{userinfo: userinfo} when is_binary(userinfo) <- URI.parse(proxy),
         [username, password] <- String.split(userinfo, ":") do
      {String.to_charlist(username), String.to_charlist(password)}
    else
      _ -> nil
    end
  end

  defp protocol_versions do
    if otp_version() < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  end

  defp otp_version do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end

  defp get_url(base_url) do
    base_url
    |> String.replace("$version", configured_version())
    |> String.replace("$target", configured_target())
  end
end
