defmodule CoverIssueTest do
  use ExUnit.Case
  doctest Good
  doctest Bad

  test "cast address" do
    assert Bad.cast("192.168.1.2") == {:ok, %{address: {192, 168, 1, 2}, netmask: 32}}
    assert Good.cast("192.168.1.2") == {:ok, %{address: {192, 168, 1, 2}, netmask: 32}}
  end
end
