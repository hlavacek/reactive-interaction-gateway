defmodule RigOutboundGateway.Redis.Client do

  use GenServer
  require Logger

  def start_link(opts) do
    conf = config()
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, _args = conf.enabled?, opts)
  end


end
