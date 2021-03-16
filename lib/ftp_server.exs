defmodule FtpServer do
  def start_server do
    IO.puts("What port should I listen on: ")

    port =
      IO.gets("\n> ")
      |> String.trim()
      |> Integer.parse()
      |> elem(0)

    IO.puts("Listening on port #{port}\n")

    case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
      {:ok, socket} ->
        # spawn them as connections come in
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

  # Threaded process to handle incoming tcp connections.
  defp server_handler(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        # Lets the client know a connection was received.
        case :gen_tcp.send(socket, "CONNECTION ESTABLISHED \n") do
          :ok ->
            IO.puts("Successfully established connection with new client.")

          {:error, err} ->
            IO.puts("Message not sent. Reason: #{err}")
        end

        receive_stream(socket)

      {:end, err} ->
        IO.puts("Error for :gen_tcp.accept() while establishing first connection: \n#{err}")
    end
  end

  # Function responsible for asynchronously receiving messages sent from client.
  defp receive_stream(socket) do
    receive do
      {:tcp, ^socket, data} ->
        args = String.split(data)

        # Parse the incoming TCP stream to match on command keywords.
        case args do
          ["LIST" | _] ->
            cond do
              length(args) > 1 -> :gen_tcp.send(socket, "Unexpected arguments")
              length(args) == 1 -> :gen_tcp.send(socket, list_files())
            end

          ["RETRIEVE" | filename] ->
            cond do
              length(args) == 1 -> :gen_tcp.send(socket, "Expected argument")
              length(args) == 2 -> :gen_tcp.send(socket, retrieve_file(filename, socket))
              length(args) > 2 -> :gen_tcp.send(socket, "Unexpected arguments")
            end

          ["STORE", address, port] ->
            store_file(address, port)

          ["QUIT"] ->
            :gen_tcp.shutdown(socket, :read_write)

          _ ->
            :gen_tcp.send(socket, "Unknown command")
        end

        receive_stream(socket)

      {:tcp_closed, ^socket} ->
        IO.puts("CONNECTION CLOSED")
    end
  end

  defp list_files do
    # Collect files within ./server_files/ and join them with a new line.
    File.ls!(File.cwd!() <> "/server_files/")
    |> Enum.join("\n")
  end

  defp retrieve_file(filename, socket) do
    IO.puts(File.ls!("./server_files/")) # testing to see what the computer sees...
    # Check to see that the file exists before proceeding
    if File.ls!("./server_files/") |> Enum.member?(filename) do
      # Generate a random port number
      port = Enum.random(1024..65535)
      # Set up a listener on the randomly generated port for file transfer.
      case :gen_tcp.listen(port, [:binary, reuseaddr: true]) do
        {:ok, transfer_socket} ->
          # Tell the server the command, what IP address and port number the client is listening on
          :gen_tcp.send(socket, "Sending file #{filename}")
          send_file(transfer_socket, filename)

        {:error, err} ->
          IO.puts(err)
      end
    else
      :gen_tcp.send(socket, "Cannot send file #{filename}")
      IO.puts("File #{filename} not found.")
    end
  end

  # Responsible for storing the incoming file in /server_files
  defp store_file(address, port) do
    p = Integer.parse(port) |> elem(0)
    # Connect to socket over the port that the client specified
    case :gen_tcp.connect(String.to_charlist(address), p, [:binary, active: true]) do
      {:ok, socket} ->
        # This message is not printed, it's simply sent to let the client know the connection is established.
        case :gen_tcp.send(socket, "CONNECTED") do
          :ok ->
            receive do
              {:tcp, ^socket, data} ->
                # Parse the file name and content from the stream.
                name =
                  String.trim(data)
                  |> String.split("\n")
                  |> Enum.at(0)

                content =
                  String.trim(data)
                  |> String.split("\n")
                  |> Enum.at(1)

                # Open / create the file with given filename
                case File.open("./server_files/" <> name, [:write]) do
                  # Write contents to file
                  {:ok, newfile} ->
                    IO.binwrite(newfile, content)
                    :gen_tcp.send(socket, "Successfully stored file #{name}\n")

                  {:error, reason} ->
                    :gen_tcp.send(socket, "Error creating file. Reason: #{reason}")
                    IO.puts("error")
                end

                IO.puts("Shutting down {store_file} socket at port #{port}")
                :gen_tcp.shutdown(socket, :read_write)
            end

          {:error, err} ->
            IO.puts("File transfer connection dropped. Reason: #{err}")
        end

      {:error, err} ->
        IO.puts("Error connecting to host. Reason: #{err}")
    end
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

FtpServer.start_server()
