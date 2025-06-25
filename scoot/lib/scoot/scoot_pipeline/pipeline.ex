defmodule Scoot.Pipeline do
  use Broadway
  alias Broadway.Message
  
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
    message
    IO.inspect(message, label: "Processing TFA Data...")
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    IO.inspect(length(messages), label: "Processing batch of")
    messages 
  end

end
