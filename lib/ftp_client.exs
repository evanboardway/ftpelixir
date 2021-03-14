defmodule FtpClient do
  def start_client do
    data =
      IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()
      |> String.split()

    case data do
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

    # Send command line input to the stream
    case :gen_tcp.send(socket, command_line_input) do
      :ok -> nil
      {:error, err} ->
        IO.puts "Connection dropped. Reason: #{err}"
        start_client()
    end

    client_handler(socket)

    # Recieve response
  end

end


FtpClient.start_client()
