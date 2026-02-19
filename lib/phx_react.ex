defmodule PhxReact do
  @moduledoc """
  PhxReact — Phoenix + React integration framework.

  Provides GenServer-based page processes, WebSocket channels, and HTTP action
  dispatch for building React frontends backed by Phoenix server state.

  ## Usage

  Run `mix phx_react.install` to generate the required files in your host app.
  `PhxReact.PageSupervisor` is started automatically as part of the `:phx_react` OTP application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [PhxReact.PageSupervisor]
    Supervisor.start_link(children, strategy: :one_for_one, name: PhxReact.Supervisor)
  end
end
