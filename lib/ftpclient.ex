defmodule Ftpclient do
  def start_client do
    data =
      IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()
      |> String.split()
      |> IO.inspect()

    case data do
      ["CONNECT", ip_address, port] ->
        po = Integer.parse(port) |> elem(0)

        case :gen_tcp.connect(String.to_charlist(ip_address), po, [:binary, active: true]) do
          {:ok, socket} ->
            client_handler(socket)

          {:error, _} ->
            IO.puts("Error connecting to host")
            start_client()
        end

      _ ->
        IO.puts("Unexpected input")
        start_client()
    end
  end

  defp client_handler(socket) do
    receive do
      {:tcp, ^socket, data} ->
        IO.write(data)
        client_handler(socket)

      {:tcp_closed, ^socket} ->
        IO.puts("CLOSED")
    end
  end
end

Ftpclient.start_client()
