defmodule PhxReact.PageSupervisor do
  @moduledoc """
  DynamicSupervisor for PhxReact page processes.

  Each page connection spawns a GenServer under this supervisor.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a page process under supervision.

  ## Parameters
    - page_module: The module implementing PhxReact.Page behaviour
    - params: URL parameters
    - session: Session data from token
    - channel_pid: The channel process pid for communication

  ## Returns
    - {:ok, pid} on success
    - {:error, reason} on failure
  """
  def start_page(page_module, params, session, channel_pid) do
    child_spec = %{
      id: page_module,
      start: {GenServer, :start_link, [page_module, {page_module, params, session, channel_pid}]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
