defmodule <%= inspect page_module %> do
  use PhxReact.Page

  alias <%= inspect context.module %>, as: <%= inspect context.alias %>
  alias <%= inspect schema.module %>

  @index_page_key "<%= page_keys.index %>"
  @show_page_key "<%= page_keys.show %>"
  @form_page_key "<%= page_keys.form %>"
  @primary_key :<%= primary_key %>
  @route_base "<%= route_base %>"

  @impl true
  def mount(%{"_page_key" => @index_page_key}, _session, socket) do
    {:ok,
     assign(socket, %{
       page_title: "Listing <%= schema.human_plural %>",
       route_base: @route_base,
       <%= schema.plural %>: list_<%= schema.plural %>()
     })}
  end

  def mount(%{"_page_key" => @show_page_key, "<%= primary_key_string %>" => id}, _session, socket) do
    <%= schema.singular %> = get_<%= schema.singular %>!(id)

    {:ok,
     assign(socket, %{
       page_title: "Show <%= schema.human_singular %>",
       route_base: @route_base,
       <%= schema.singular %>: <%= schema.singular %>
     })}
  rescue
    Ecto.NoResultsError ->
      {:ok, assign(socket, %{error: "Record not found", route_base: @route_base})}
  end

  def mount(%{"_page_key" => @form_page_key} = params, _session, socket) do
    mode = Map.get(params, "mode", "new")
    <%= schema.singular %> = form_<%= schema.singular %>(mode, params)

    {:ok,
     assign(socket, %{
       page_title: if(mode == "edit", do: "Edit <%= schema.human_singular %>", else: "New <%= schema.human_singular %>"),
       route_base: @route_base,
       mode: mode,
       <%= schema.singular %>: <%= schema.singular %>,
       form: form_from_<%= schema.singular %>(<%= schema.singular %>),
       errors: %{}
     })}
  rescue
    Ecto.NoResultsError ->
      mode = Map.get(params, "mode", "new")
      {:ok, assign(socket, %{error: "Record not found", route_base: @route_base, mode: mode})}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, %{error: "Unsupported page", route_base: @route_base})}
  end

  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_action("delete", %{"id" => id}, _context) do
    <%= schema.singular %> = get_<%= schema.singular %>!(id)

    case <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>) do
      {:ok, _} -> {:ok, %{deleted_id: id}}
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "not_found"}
  end

  def handle_action("save", %{"attrs" => attrs}, context) when is_map(attrs) do
    case Map.get(context.page_params || %{}, "mode", "new") do
      "edit" -> update_<%= schema.singular %>(attrs, context)
      _mode -> create_<%= schema.singular %>(attrs)
    end
  end

  def handle_action("save", _params, _context), do: {:error, "invalid_params"}

  def handle_action(_action, _params, _context), do: {:error, "unknown_action"}

  defp update_<%= schema.singular %>(attrs, context) do
    params = context.page_params || %{}
    id = Map.get(params, "<%= primary_key_string %>")

    with id when is_binary(id) <- id,
         <%= schema.singular %> <- get_<%= schema.singular %>!(id),
         {:ok, updated_<%= schema.singular %>} <- <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, attrs) do
      {:redirect, "#{@route_base}/#{Map.get(updated_<%= schema.singular %>, @primary_key)}"}
    else
      nil ->
        {:error, "missing_id"}

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_error(changeset)

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "not_found"}
  end

  defp create_<%= schema.singular %>(attrs) do
    case <%= inspect context.alias %>.create_<%= schema.singular %>(attrs) do
      {:ok, <%= schema.singular %>} ->
        {:redirect, "#{@route_base}/#{Map.get(<%= schema.singular %>, @primary_key)}"}

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_error(changeset)

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp validation_error(%Ecto.Changeset{} = changeset) do
    %{
      status: :error,
      error: %{
        code: "validation_failed",
        message: "Validation failed",
        details: %{errors: errors_from_changeset(changeset)}
      }
    }
  end

  defp errors_from_changeset(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp form_<%= schema.singular %>("edit", %{"<%= primary_key_string %>" => id}),
    do: get_<%= schema.singular %>!(id)

  defp form_<%= schema.singular %>(_mode, _params), do: struct(<%= inspect schema.module %>)

  defp form_from_<%= schema.singular %>(resource) do
    %{<%= for field <- fields do %>
      "<%= field.key %>" => form_value(resource, :<%= field.atom %>, <%= inspect(field.default_elixir) %>),
<% end %>
    }
  end

  defp form_value(resource, key, default) do
    case Map.get(resource, key) do
      nil -> default
      value -> value
    end
  end

  defp list_<%= schema.plural %>, do: <%= inspect context.alias %>.list_<%= schema.plural %>()
  defp get_<%= schema.singular %>!(id), do: <%= inspect context.alias %>.get_<%= schema.singular %>!(id)
end
