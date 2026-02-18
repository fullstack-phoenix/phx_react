defmodule PhxReact.Page do
  @moduledoc """
  Behaviour for PhxReact pages.

  Similar to Phoenix.LiveView, pages are GenServer processes that maintain state
  and handle events from the client.

  ## Example

      defmodule MyApp.Pages.CounterPage do
        use PhxReact.Page

        @impl true
        def mount(_params, _session, socket) do
          {:ok, assign(socket, count: 0)}
        end

        @impl true
        def handle_event("increment", _params, socket) do
          {:noreply, assign(socket, count: socket.assigns.count + 1)}
        end

        @impl true
        def handle_info(:tick, socket) do
          {:noreply, assign(socket, count: socket.assigns.count + 1)}
        end
      end
  """

  alias PhxReact.Socket

  @type params :: map()
  @type session :: map()
  @type socket :: Socket.t()
  @type action_result ::
          {:ok, map()}
          | {:error, term()}
          | {:redirect, String.t()}
          | %{status: :ok | :error | :redirect}

  @callback mount(params, session, socket) ::
              {:ok, socket} | {:error, term()}

  @callback handle_event(event :: String.t(), params :: map(), socket) ::
              {:noreply, socket}

  @callback handle_action(action :: String.t(), params :: map(), context :: map()) ::
              action_result()

  @optional_callbacks handle_action: 3

  defmacro __using__(_opts) do
    quote do
      use GenServer
      @behaviour PhxReact.Page

      alias PhxReact.Socket

      # GenServer callbacks
      @impl GenServer
      def init({page_module, params, session, channel_pid}) do
        socket = Socket.new(channel_pid: channel_pid, connected?: true)

        case page_module.mount(params, session, socket) do
          {:ok, socket} ->
            # Push initial state to client
            push_state(socket)
            {:ok, socket}

          {:error, reason} ->
            {:stop, reason}
        end
      end

      @impl GenServer
      def handle_cast({:event, event_name, event_params}, socket) do
        {:noreply, new_socket} = __MODULE__.handle_event(event_name, event_params, socket)
        push_state(new_socket)
        {:noreply, new_socket}
      end

      @impl GenServer
      def handle_info(msg, socket) do
        # Call __handle_info__ which modules will define
        result = __handle_info__(msg, socket)

        case result do
          {:noreply, new_socket} ->
            push_state(new_socket)
            {:noreply, new_socket}
        end
      end

      # Default implementation - can be overridden
      def __handle_info__(_msg, socket), do: {:noreply, socket}

      def handle_action(_action, _params, _context), do: {:error, "unknown_action"}

      defoverridable __handle_info__: 2, handle_action: 3

      # Helper functions available in page modules
      defp assign(socket, key, value) do
        Socket.assign(socket, key, value)
      end

      defp assign(socket, attrs) do
        Socket.assign(socket, attrs)
      end

      defp push_state(socket) do
        if socket.channel_pid do
          send(socket.channel_pid, {:state, socket.assigns})
        end
      end

      defp schedule_info(interval, msg) do
        Process.send_after(self(), msg, interval)
      end
    end
  end
end
