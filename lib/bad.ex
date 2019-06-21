defmodule Bad do
  def cast(address) when is_binary(address) do
    is_v6 = address =~ ":"

    [address, netmask] =
      case String.split(address, "/") do
        [address, netmask] -> [address, netmask]
        [address] -> [address, if(is_v6, do: "128", else: "32")]
      end

    netmask = String.to_integer(netmask)

    with {:ok, address} <- address |> String.to_charlist() |> :inet.parse_address() do
      {:ok, %{address: address, netmask: netmask}}
    else
      _ ->
        error_response(is_v6, netmask)
    end
  end

  defp error_response(false, 24) do
    {:error, :invalid_address}
  end

  defp error_response(true, 128) do
    {:error, :invalid_address}
  end

  defp error_response(_, _) do
    {:error, :invalid_network}
  end
end
