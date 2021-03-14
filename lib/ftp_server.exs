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

          ["STORE", address, port] ->
            spawn(fn ->
              store_file(address, port)
            end)

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
    # Collect files within ../files/ and join them with a new line.
    Path.wildcard("../server_files/*")
    |> Enum.map(&Path.basename/1)
    |> Enum.join("\n")
  end

  defp retreive_file(filename) do
    "file file file"
  end

  # NOT RECEIVING STORE COMMAND
  defp store_file(address, port) do
    p = Integer.parse(port) |> elem(0)
    case :gen_tcp.connect(String.to_charlist(address), p, [:binary, active: true]) do
      {:ok, socket} ->
        case :gen_tcp.send(socket, "CONNECTED") do
          :ok ->
            receive do
              {:tcp, ^socket, data} ->

                name =
                  String.trim(data)
                  |> String.split("\n")
                  |> Enum.at(0)

                content =
                  String.trim(data)
                  |> String.split("\n")
                  |> Enum.at(1)

                case File.open("../server_files/" <> name, [:write]) do
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
