defmodule RigOutboundGateway.Redis.Client do

  use GenServer
  use Rig.Config, [:enabled?, :redis_url, :redis_channel, :redis_subscriber_group_name]
  require Logger

  @default_send &RigOutboundGateway.send/1

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl GenServer
  def init(:ok) do
    conf = config()
    if conf.enabled? do

      Logger.info("Connecting to Redis (config=#{inspect(conf)})")
      {:ok, pubsub} = Redix.PubSub.start_link(conf.redis_url);

      # This creates subsriber group for RIG

      # {:ok, conn} = Redix.start_link(conf.redis_url, name: :redix)
      #
      # Logger.info("Creating subcriber group #{inspect(conf.redis_subscriber_group_name)}")

      # try do
      #   case Redix.command(conn, ~w(XGROUP CREATE #{conf.redis_channel} #{conf.redis_subscriber_group_name} $ MKSTREAM)) do
      #     {:ok, _} -> Logger.info("Subscriber group #{inspect(conf.redis_subscriber_group_name)} created successfuly")
      #     {:error, reason} -> Logger.info("Failed to create subscriber group #{inspect(conf.redis_subscriber_group_name)}, reason #{reason}")
      #     _ -> Logger.info("Default match")
      #   end
      # # we have to use try / rescue due to https://github.com/whatyouhide/redix/issues/75
      # rescue
      #   e in Redix.Error -> Logger.info("Failed to create subscriber group #{inspect(conf.redis_subscriber_group_name)}, reason #{e.message}")
      # end

      # TODO: We should use subscriber group for receiving the messages so different rig nodes won't get the same message
      # but Redis subscriber groups needs a cluster wide tracking of all subsribed nodes and their IDs, so that we know
      # if we should claim pending messages or not (see description of subscriber groups here: https://redis.io/topics/streams-intro)

      # the current implementation works just with sigle node of RIG, otherwise messages will be replicated for each node

      {:ok, ref} = Redix.PubSub.subscribe(pubsub, conf.redis_channel, self())

      receive_message(pubsub, ref, conf.redis_channel)

    end

    {:ok, %{}}
  end

  def receive_message(conn, ref, channel) do
    receive do
      {:redix_pubsub, ^conn, ^ref, :subscribed, %{channel: ^channel}} ->
        Logger.info("Subscribed to redis channel #{channel}")
      {:redix_pubsub, ^conn, ^ref, :message, %{channel: ^channel} = properties} ->
        handle_message(properties.payload)
    end

    receive_message(conn, ref, channel)
  end

  def handle_message([[msgId | message_body] | _], send \\ @default_send) do
    [ firstEntry | _ ] = message_body

    body = message_to_map(firstEntry)
    meta = [{ :body_raw, Poison.encode!(body) }, { :msgId, msgId }]
    ack = fn -> :ok end

    RigOutboundGateway.handle_map(body, send, ack)
    |> RigOutboundGateway.Logger.log(__MODULE__, meta)
  end

  defp message_to_map([]) do
    %{}
  end

  defp message_to_map(message_array) do
    [ entry_key | next ] = message_array
    [ entry_value | tail ] = next

    map = message_to_map(tail)

    Map.put(map, entry_key, entry_value)
  end

end
