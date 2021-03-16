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

      ["RETRIEVE", filename] ->
        port = Enum.random(1024..65535)

        case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
          {:ok, transfer_socket} ->
            # Tell the server the command, what IP address and port number the client is listening on
            :gen_tcp.send(socket, "RETRIEVE localhost #{port} #{filename}")

            # Wait for data for one second
            receive do
              # If the string is "File not found."
              # Then stop listening on the port, print the message "File not found."
              {:tcp, ^socket, data} ->
                case String.contains?(data, "ERROR") do
                  true -> IO.puts data
                  false -> retrieve_file(transfer_socket, filename)
                end
            end

          {:error, err} ->
            IO.puts(err)
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

  defp retrieve_file(transfer_socket, filename) do
    case :gen_tcp.accept(transfer_socket) do
      {:ok, socket} ->
        receive do
          {:tcp, ^socket, data} ->
            # Open / create the file with given filename
            case File.open("./client_files/" <> filename, [:write]) do
              # Write contents to file
              {:ok, newfile} ->
                IO.binwrite(newfile, data)
                IO.puts("#{filename} successfully retrieved.")

              {:error, reason} ->
                IO.puts("Error creating file. Reason: #{reason}")
            end
        after
          10000 ->
            IO.puts("FILE TRANSFER CONNECTION TIMEOUT")
            :gen_tcp.shutdown(transfer_socket, :read_write)
        end

      {:error, err} ->
        IO.puts(
          "Error for :gen_tcp.accept() while connecting to new port during file reception attempt: \n#{
            err
          }"
        )
    end
  end

  # Sends the file to the server over the new socket
  defp send_file(transfer_socket, filename) do
    # Wait for server to try to connect to the new socket.
    case :gen_tcp.accept(transfer_socket) do
      {:ok, socket} ->
        # Check for server response upon accepting connection.
        receive do
          {:tcp, ^socket, _} ->
            # Read the contents of the file and send it over the transfer socket
            {:ok, contents} = File.read("./client_files/" <> filename)
            :gen_tcp.send(socket, filename <> "\n" <> contents)
            receive do
              {:tcp, ^socket, response} -> IO.puts response
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
