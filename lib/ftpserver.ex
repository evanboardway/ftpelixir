defmodule Ftpserver do
  def start_server do
    case :gen_tcp.listen(3000, [:binary, reuseaddr: true]) do
      {:ok, socket} ->
        for _unusedvar <- 0..10 do
          spawn(fn ->
            server_handler(socket)
          end)
        end

        Process.sleep(:infinity)

      {:error, err} ->
        IO.puts(err)
    end
  end

  # This is the process that is spawned 10 times.
  defp server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    :ok = :gen_tcp.send(socket, "== CONNECTION ESTABLISHED")

    receive do
      {:tcp, ^socket, "LIST"} ->
        :ok = :gen_tcp.send(socket, "LIST")

      {:tcp, ^socket, "RETRIEVE"} ->
        :ok = :gen_tcp.send(socket, "RETR")

      {:tcp, ^socket, "STORE"} ->
        :ok = :gen_tcp.send(socket, "STORE")

      {:tcp, ^socket, "QUIT"} ->
        :ok = :gen_tcp.shutdown(socket, :read_write)

      {:tcp, ^socket, data} ->
        :ok = :gen_tcp.send(socket, data)
    end

    :ok = :gen_tcp.shutdown(socket, :read_write)
    server_handler(listen_socket)
  end

  defp handle_request(socket, "LIST") do

  end

  defp handle_request(socket, "RETRIEVE") do

  end

  defp handle_request(socket, "STORE") do

  end

end

Ftpserver.start_server()


defmodule Ftpclient do
  def start_client do

    data = IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()
      |> String.split()
      |> IO.inspect()



    case data do
      ["CONNECT", ip_address, port] ->
        case :gen_tcp.connect(ip_address, port, [:binary, active: true]) do
          {:ok, socket} -> client_handler(socket)
          {:error, _} ->
            IO.puts "Error connecting to host"
            start_client()
        end
      _ ->
        IO.puts "Unexpected input"
        start_client()
      end
  end

  defp client_handler(socket) do
    receive do
      {:tcp, ^socket, data} ->
        IO.write data
        client_handler(socket)
      {:tcp_closed, ^socket} -> IO.puts "CLOSED"
    end
  end
end

Ftpclient.start_client()
