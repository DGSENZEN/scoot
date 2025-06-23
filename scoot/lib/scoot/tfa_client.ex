defmodule Scoot.TfaAPIClient do
  
  require Logger

  @content_headers [
    {"Content-Type", "application/json"},
    {"Accept-Type", "application/json"},
    {"User-Agent", "Scoot/0.1"}
  ]
  @default_timeout 30_000

  def fetch_lines_info(endpoint) do
    
  end
end
