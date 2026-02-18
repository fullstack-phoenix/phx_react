defmodule PhxReact do
  @moduledoc """
  PhxReact — Phoenix + React integration framework.

  Provides GenServer-based page processes, WebSocket channels, and HTTP action
  dispatch for building React frontends backed by Phoenix server state.

  ## Usage

  Add `PhxReact` to your application's supervision tree (handled automatically
  when PhxReact is started as an OTP application):

      # In your lib/<app>/application.ex
      children = [
        PhxReact.PageSupervisor
      ]

  Run `mix phx_react.install` to generate the required files in your host app.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [PhxReact.PageSupervisor]
    Supervisor.start_link(children, strategy: :one_for_one, name: PhxReact.Supervisor)
  end
end
