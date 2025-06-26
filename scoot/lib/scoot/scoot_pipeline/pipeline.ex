defmodule Scoot.Pipeline do
  use Broadway
  alias Broadway.Message
  require Logger
  
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayRabbitMQ.Producer,
          queue: "tfa_queue",
          connection: [
            host: "localhost",
            port: 5672,
            username: "guest",
            password: "guest",
            heartbeat: 30,
            connection_timeout: 10_000

          ],
          qos: [
            prefetch_count: 50,
          ],

          on_failure: :reject_and_requeue_once
        },
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: 50
        ],
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: 1500,
          concurrency: 5
        ]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _) do
    IO.inspect(data, label: "Processing TFA Data...")

    case Jason.decode(data) do
      {:ok, parsed_data} -> 
        Logger.info("Successfully parsed TFA data: #{parsed_data}")
        message
      {:error, reason} ->
        Logger.error("Failed to parse JSON data: #{inspect data}")
        Message.failed(message, "JSON parse error")
    end
  end

  @impl true
  def handle_batch(_, messages, _batch_info, _context) do
    IO.inspect(length(messages), label: "Processing batch of")

    Enum.each(messages, fn message ->
        Logger.debug("Batch processing message: #{inspect(message.data)}")
    end)
    messages 
  end

  @impl true
  def handle_failed(messages, _context) do
    Logger.info("Failed to process #{length(messages)} messages")

    Enum.each(messages, fn message ->
        Logger.error("Failed message: #{inspect(message.data)}") 
    end)
  end

end
