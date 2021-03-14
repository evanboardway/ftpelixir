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

  # This is the process that is spawned 10 times.
  defp server_handler(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)

    case :gen_tcp.send(socket, "CONNECTION ESTABLISHED \n") do
      :ok -> nil
      {:error, err} ->
        IO.puts "Message not sent. Reason: #{err}"
    end

    receive_stream(socket)

  end

  defp receive_stream(socket) do
    receive do
      {:tcp, ^socket, data} ->

        args = String.split(data)|> IO.inspect()

        IO.puts("Client said, #{data}")
        receive_stream(socket)

      {:tcp_closed, ^socket} ->
        IO.puts("CONNECTION CLOSED")
    end
  end
end


FtpServer.start_server()
