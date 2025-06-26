defmodule Scoot.TFAPublisher do
  
  require Logger
  use GenServer
  #@default_timeout 30_000
  @tfa_poll_msec 15_000
  @wbsock_endpoint "http://localhost:4000/info"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    poll_tfl_api()
    {:ok, %{latest_results: nil,  retry_count: 0}}
  end

  @impl true
  def handle_info(:work, state) do
    case fetch_tfa_info() do
    {:ok, results} ->
      case publish(results) do
        :ok ->
            Logger.info("Succesful publishing of TFA data to queue")
            new_state = %{state | latest_results: results, retry_count: 0}
            poll_tfl_api()
            {:noreply, new_state}

        {:error, reason} ->
            Logger.error("Failed to publish TFA data: #{inspect(reason)}")
            retry_count = state.retry_count + 1
            if retry_count <= 3 do
              delay = min(retry_count * 2000, 10_000)
              Logger.info("Retrying publish in #{delay}ms")
              Process.send_after(self(), :work, delay)
              {:noreply, %{state | retry_count: retry_count}}
            else
              Logger.error("Max retries exceeded, scheduling next poll.")
              poll_tfl_api()
              {:noreply, %{state | retry_count: 0}}
            end
      end
    {:error, reason} ->
        Logger.error("Failed to fetch TFA info: #{inspect(reason)}")
        poll_tfl_api()
        {:noreply, %{state | retry_count: 0}}
    end
  end

  defp publish(data) do
    json_data = Jason.encode!(data)

    with {:ok, connection} <- AMQP.Connection.open(),
        {:ok, channel} <- AMQP.Channel.open(connection) do
      case AMQP.Queue.declare(channel, "tfa_queue", durable: true) do
        {:ok, _queue_info} ->
          case AMQP.Basic.publish(channel, "", "tfa_queue", json_data, persistent: true) do
            :ok ->
              AMQP.Connection.close(connection)
              :ok
            {:error, reason} ->
              AMQP.Connection.close(connection)
              Logger.error("Failed to publish message: #{inspect(reason)}")
              error
          end
        {:error, reason} = error ->
          AMQP.Connection.close(connection)
          Logger.error("Failed to declare queue: #{inspect(reason)}")
      else
        {:error, reason} = error ->
        Logger.error("Failed to establish AMQP connection/channel: #{inspect(reason)}")
        error
      end
    end 
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

  defp fetch_tfa_info do
    config = Application.get_env(:scoot, __MODULE__, []) 
    endpoints = Keyword.get(config, :endpoints, [])
    
    if Enum.empty?(endpoints) do
      Logger.error("No endpoints configured for TFA polling")
      {:error, :no_endpoints_configured}
    else
      Logger.info("Fetching from #{length(endpoints)} configured endpoints")
      
      results = 
        endpoints
        |> Task.async_stream(
          fn endpoint -> 
            {endpoint.name, fetch_lines_info(endpoint.url)}
          end,
          timeout: 15_000,
          max_concurrency: 5
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, reason} -> 
            Logger.error("Task failed: #{inspect(reason)}")
            {"unknown", {:error, reason}}
        end)
      
      # Check if we got any successful results
      successful_results = 
        results
        |> Enum.filter(fn {_name, result} -> 
          case result do
            {:ok, _} -> true
            _ -> false
          end
        end)
      
      if Enum.empty?(successful_results) do
        Logger.error("All endpoint fetches failed")
        {:error, :all_endpoints_failed}
      else
        Logger.info("Successfully fetched from #{length(successful_results)} endpoints")
        
        response_data = %{
          timestamp: DateTime.utc_now(),
          poll_interval_ms: @tfa_poll_msec,
          successful_endpoints: length(successful_results),
          total_endpoints: length(endpoints),
          results: results
        }
        
        {:ok, response_data}
      end
    end
  end

end
