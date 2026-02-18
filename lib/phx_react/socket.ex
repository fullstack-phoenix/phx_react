defmodule PhxReact.Socket do
  @moduledoc """
  Socket struct for PhxReact pages.
  Similar to Phoenix.LiveView.Socket but simplified for our use case.
  """

  defstruct [:id, :channel_pid, :assigns, :connected?]

  @type t :: %__MODULE__{
          id: String.t(),
          channel_pid: pid() | nil,
          assigns: map(),
          connected?: boolean()
        }

  @doc """
  Creates a new socket with default values.
  """
  def new(opts \\ []) do
    %__MODULE__{
      id: opts[:id] || generate_id(),
      channel_pid: opts[:channel_pid],
      assigns: %{},
      connected?: opts[:connected?] || false
    }
  end

  @doc """
  Assigns a key-value pair to the socket.
  """
  def assign(%__MODULE__{} = socket, key, value) do
    %{socket | assigns: Map.put(socket.assigns, key, value)}
  end

  @doc """
  Assigns multiple key-value pairs to the socket.
  """
  def assign(%__MODULE__{} = socket, attrs) when is_map(attrs) or is_list(attrs) do
    %{socket | assigns: Map.merge(socket.assigns, Map.new(attrs))}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
