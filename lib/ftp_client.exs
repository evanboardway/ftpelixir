defmodule FtpClient do
  def start_client do
    IO.puts("Enter client info: CONNECT <IPV4> PORT")

    data =
      IO.gets("\n> ")
      |> String.trim()
      |> String.upcase()
      |> String.split()

    case data do
      # This is for quick testing to avoid typing "connect localhost 3001" every time
      ["CON"] ->
        case :gen_tcp.connect('localhost', 3001, [:binary, active: true]) do
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
        start_client()
    after
      # receive is a halting function, so lets give it a timeout of 1 second.
      1000 -> nil
    end

    # Accept and trim command line input
    command_line_input =
      IO.gets("\n> ")
      |> String.trim()

    case String.split(command_line_input) do
      ["STORE", filename] ->
        # Check to see that the file exists before proceeding
        if File.ls!("./client_files/") |> Enum.member?(filename) do
          # Generate a random port number
          port = Enum.random(1024..65535)
          # Set up a listener on the randomly generated port for file transfer.
          case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
            {:ok, transfer_socket} ->
              # Tell the server the command, what IP address and port number the client is listening on
              :gen_tcp.send(socket, "STORE localhost #{port}")
              send_file(transfer_socket, filename)

            {:error, err} ->
              IO.puts(err)
          end
        else
          IO.puts("File #{filename} not found.")
        end

      # Send command line input to the stream
      _ ->
        case :gen_tcp.send(socket, command_line_input) do
          :ok ->
            nil

          {:error, err} ->
            IO.puts("Connection dropped. Reason: #{err}")
            start_client()
        end
    end

    client_handler(socket)
  end

  # Sends the file to the server over the new socket
  defp send_file(transfer_socket, filename) do
    # Wait for server to try to connect to the new socket.
    case :gen_tcp.accept(transfer_socket) do
      {:ok, socket} ->
        # Check for server response upon accepting connection.
        receive do
          {:tcp, ^socket, data} ->
            # Read the contents of the file and send it over the transfer socket
            {:ok, contents} = File.read("./client_files/" <> filename)

            :gen_tcp.send(socket, filename <> "\n" <> contents)

            receive do
              {:tcp, socket, data} ->
                IO.write(data)
            after
              1000 -> nil
            end

          {:tcp_closed, ^socket} ->
            nil
        after
          1000 -> nil
        end

      {:error, err} ->
        IO.puts("Error for :gen_tcp.accept() while sending file: \n#{err}")
    end
  end
end

FtpClient.start_client()
