defmodule Scoot.Pipeline do
  use Broadway
  alias Broadway.Message
  
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: ScootPipeline,
      producer: [
        module: {BroadwayRabbitMQ.Producer,
          queue: "tfa_queue",
          qos: [
            prefetch_count: 50,
          ]
        },
        concurrency: 1
      ],
      processor: [
        default: [
          concurrency: 50
        ],
      ],
    )
  end

  @impl true
  def handle_message(_, message, _) do
    message
    |> Message.update_data()
  end

end
