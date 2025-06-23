defmodule Scoot.TFAPoller do
  
  require Logger
  use GenServer
  #@default_timeout 30_000
  @tfa_poll_msec 15_000
  @wbsock_endpoint 

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    poll_tfl_api()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    state = fetch_tfa_info(state)
    poll_tfl_api()
    {:noreply, state}
  end

  defp poll_tfl_api do
    Process.send_after(self(), :work, @tfa_poll_msec)
  end


  defp fetch_lines_info(endpoint) do
    Logger.info("[fetch_lines_info]: Fetching #{endpoint}")
    case Req.get(endpoint) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.info("[fetch_lines_info]: Succesful GET to TFA endpoint!")
        {:ok, body}
      {:ok, %Req.Response{status: status}} ->
        {:error, "[fetch_lines_info]: Client responded with: #{status}"}
      {:error, %Req.HTTPError{reason: reason}} ->
        {:error, "[fetch_lines_info]: Req Error: #{reason}"}
    end
  end

  defp fetch_tfa_info(state) do
    config = Application.get_env(:scoot, __MODULE__, [])
    endpoints = Keyword.get(config, :endpoints, [])
    results = Enum.map(endpoints, fn endpoint -> 
      {endpoint.name, fetch_lines_info(endpoint.url)}
    end)
    state = Map.put(state, :latest_results, results)
  end

end
