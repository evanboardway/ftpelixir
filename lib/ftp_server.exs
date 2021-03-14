defmodule FtpServer do

  def start_server do
    IO.puts "What port should I listen on: "

    port =
      IO.gets("\n> ")
      |> String.trim()
      |> Integer.parse()
      |> elem(0)

    IO.puts "Listening on port #{port}\n"

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

  # Threadded process to handle incoming tcp connections.
  defp server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    # Lets the client know a connection was received.
    case :gen_tcp.send(socket, "CONNECTION ESTABLISHED \n") do
      :ok -> nil
      {:error, err} ->
        IO.puts "Message not sent. Reason: #{err}"
    end

    receive_stream(socket)
  end

  # Function responsible for asynchronously receiving messages sent from client.
  defp receive_stream(socket) do
    receive do
      {:tcp, ^socket, data} ->
        args = String.split(data)

        # Parse the incoming TCP stream to match on command keywords.
        case args do
          ["LIST"|_] ->
            cond do
              length(args) > 1 -> :gen_tcp.send(socket, "Unexpected aruments")
              length(args) == 1 -> :gen_tcp.send(socket, list_files())
            end

          ["RETREIVE"|filename] ->
            cond do
              length(args) == 1 -> :gen_tcp.send(socket, "Expected argument")
              length(args) == 2 -> :gen_tcp.send(socket, retreive_file(filename))
              length(args) > 2 -> :gen_tcp.send(socket, "Unexpected arguments")
            end

          ["STORE", address, port] -> store_file(address, port)

          ["QUIT"] ->
            :gen_tcp.shutdown(socket, :read_write)

          _ -> :gen_tcp.send(socket, "Unknown command")

        end

        receive_stream(socket)

      {:tcp_closed, ^socket} ->
        IO.puts("CONNECTION CLOSED")
    end
  end

  defp list_files do
    # Collect files within ./server_files/ and join them with a new line.
    File.ls!(File.cwd! <> "/server_files/")
    |> Enum.join("\n")
  end

  defp retreive_file(filename) do
    "file file file"
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
                  {:ok, newfile} -> IO.binwrite(newfile, content)
                  {:error, reason} -> :gen_tcp.send(socket, "Error creating file. Reason: #{reason}")
                end
                :gen_tcp.shutdown(socket, :read_write)

            end
          {:error, err} ->
            IO.puts "File transfer connection dropped. Reason: #{err}"
        end

      {:error, err} ->
        IO.puts("Error connecting to host. Reason: #{err}")
    end
  end

end


FtpServer.start_server()
