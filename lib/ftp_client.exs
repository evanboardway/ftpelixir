defmodule FtpClient do
  def start_client do
    IO.puts "Enter client info: CONNECT <IPV4> PORT"
    data =
      IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()
      |> String.split()

    case data do
      ["CON"] ->
        case :gen_tcp.connect('localhost', 9, [:binary, active: true]) do
          {:ok, socket} ->
            client_handler(socket)

          {:error, err} ->
            IO.puts("Error connecting to host. Reason: #{err}")
            start_client()
        end

      ["CONNECT", ip_address, port] ->
        # TODO: pattern match ip_addr and port to regex.
        p = Integer.parse(port) |> elem(0)

        case :gen_tcp.connect(String.to_charlist(ip_address), p, [:binary, active: true]) do
          {:ok, socket} ->
            client_handler(socket)

          {:error, err} ->
            IO.puts("Error connecting to host. Reason: #{err}")
            start_client()
        end

      _ ->
        IO.puts("Unexpected input")
        start_client()
    end
  end

  # Responsible for handling input upon tcp connection.
  defp client_handler(socket) do
    # See if server sent a message.
    receive do
      {:tcp, ^socket, data} ->
        IO.write(data)

      {:tcp_closed, ^socket} ->
        IO.puts("CONNECTION CLOSED")
      after
        # receive is a halting function, so lets give it a timeout of 1 second.
        1000 -> nil
    end

    # Accept and trim command line input
    command_line_input =
      IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()

    case String.upcase(command_line_input) |> String.split() do
      ["STORE"|_] ->
        # Generate a random port number
        port = Enum.random(1024..65535)
        # Set up a listener on the randomly generated port for file transfer.
        case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
          {:ok, transfer_socket} ->
            # Tell the server the command, what IP address and port number the client is listening on
            :gen_tcp.send(socket, "STORE localhost #{port}")
            send_file(transfer_socket)

          {:error, err} ->
            IO.puts(err)
        end


      _ -> # Send command line input to the stream
        case :gen_tcp.send(socket, command_line_input) do
          :ok -> nil
          {:error, err} ->
            IO.puts "Connection dropped. Reason: #{err}"
            start_client()
        end
    end

    client_handler(socket)
  end

  defp send_file(transfer_socket) do
    # Wait for server to try to connect to the new socket.
    {:ok, socket} = :gen_tcp.accept(transfer_socket)

    case :gen_tcp.send(socket, "CONNECTION ESTABLISHED \n") do
      :ok -> nil
      {:error, err} ->
        IO.puts "Message not sent. Reason: #{err}"
    end

    receive do
      {:tcp, ^transfer_socket, data} ->
        IO.inspect(data)

      {:tcp_closed, ^transfer_socket} ->
        IO.puts("CLOSING TRANSFER PORT")
      after
        # receive is a halting function, so lets give it a timeout of 1 second.
        1000 -> IO.puts "TIMEOUT"
    end
  end

  defp get_current_ip_address do
    :inet.getifaddrs()
    |> elem(1)
    |> Map.new()
    |> Map.get('en1')
    |> Keyword.get_values(:addr)
    |> Enum.find(&match?({_, _, _, _}, &1))
    |> Tuple.to_list()
    |> Enum.join(".")
  end

end


FtpClient.start_client()
