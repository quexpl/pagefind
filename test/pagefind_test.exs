defmodule PagefindTest do
  use ExUnit.Case, async: true

  @version Pagefind.latest_version()

  setup do
    Application.put_env(:pagefind, :version, @version)
    :ok
  end

  test "run pagefind" do
    Mix.Task.rerun("pagefind.install", ["--if-missing"])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Pagefind.run(["--version"]) == 0
           end) =~ @version
  end

  test "updates on install" do
    Application.put_env(:pagefind, :version, "1.2.0")
    Mix.Task.rerun("pagefind.install", ["--if-missing"])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Pagefind.run(["--version"]) == 0
           end) =~ "1.2.0"
  end

  test "installs with custom URL" do
    assert :ok =
             Mix.Task.rerun("pagefind.install", [
               "https://github.com/CloudCannon/pagefind/releases/download/v1.1.1/pagefind-v1.1.1-$target.tar.gz"
             ])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Pagefind.run(["--version"]) == 0
           end) =~ "1.1.1"
  end
end
