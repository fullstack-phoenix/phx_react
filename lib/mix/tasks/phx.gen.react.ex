defmodule Mix.Tasks.Phx.Gen.React do
  @shortdoc "Generates PhxReact pages, React components, and context for a resource"

  @moduledoc """
  Generates a PhxReact CRUD scaffold for a resource.

      mix phx.gen.react [<context>] <schema> <table> <attr:type> [<attr:type>...]

  This task reuses Phoenix context/schema generation and adds:

    * a React controller for route-to-page mapping
    * a PhxReact page module with CRUD actions
    * React components for index/show/form

  """
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.react must be invoked from within your *_web application root directory"
      )
    end

    {context, schema} = Gen.Context.build(args, name_optional: true)
    validate_schema!(schema)

    Gen.Context.prompt_for_code_injection(context)

    binding = build_binding(context, schema)
    paths = Mix.Phoenix.generator_paths()

    context
    |> copy_new_files(paths, binding)
    |> maybe_inject_page_registry(binding)
    |> maybe_inject_component_registry(binding)
    |> print_shell_instructions(binding)
  end

  defp validate_schema!(%Schema{attrs: []}) do
    Mix.raise("""
    No attributes provided. The phx.gen.react generator requires at least one attribute. For example:

      mix phx.gen.react Accounts User users name:string

    """)
  end

  defp validate_schema!(_schema), do: :ok

  defp build_binding(context, schema) do
    schema_alias = schema_alias(schema)
    primary_key = schema.opts[:primary_key] || :id
    attrs = resource_attrs(schema)

    namespace_parts =
      case schema.web_namespace do
        nil -> []
        value -> [value]
      end

    page_module =
      Module.concat([context.web_module] ++ namespace_parts ++ [Pages, "#{schema_alias}Page"])

    controller_module =
      Module.concat([context.web_module] ++ namespace_parts ++ ["#{schema_alias}ReactController"])

    page_keys = %{
      index: "#{schema.plural}_index",
      show: "#{schema.plural}_show",
      form: "#{schema.plural}_form"
    }

    component_names = %{
      index: "#{schema_alias}Index",
      show: "#{schema_alias}Show",
      form: "#{schema_alias}Form"
    }

    component_keys = %{
      index: "#{schema.singular}_index",
      show: "#{schema.singular}_show",
      form: "#{schema.singular}_form"
    }

    [
      context: context,
      schema: schema,
      schema_alias: schema_alias,
      attrs: attrs,
      fields: Enum.map(attrs, &field_spec/1),
      primary_key: primary_key,
      primary_key_string: Atom.to_string(primary_key),
      page_module: page_module,
      controller_module: controller_module,
      page_keys: page_keys,
      component_names: component_names,
      component_keys: component_keys,
      route_base: "/#{schema.plural}"
    ]
  end

  @doc false
  def files_to_be_generated(%Context{schema: schema, context_app: context_app}) do
    schema_alias = schema_alias(schema)
    web_prefix = Mix.Phoenix.web_path(context_app)
    web_path = to_string(schema.web_path)
    controller_prefix = Path.join([web_prefix, "controllers", web_path])
    page_prefix = Path.join([web_prefix, "pages", web_path])

    [
      {:eex, "controller.ex",
       Path.join([controller_prefix, "#{schema.singular}_react_controller.ex"])},
      {:eex, "page.ex", Path.join([page_prefix, "#{schema.singular}_page.ex"])},
      {:eex, "index.tsx", Path.join(["assets/js/components", "#{schema_alias}Index.tsx"])},
      {:eex, "show.tsx", Path.join(["assets/js/components", "#{schema_alias}Show.tsx"])},
      {:eex, "form.tsx", Path.join(["assets/js/components", "#{schema_alias}Form.tsx"])}
    ]
  end

  @doc false
  def copy_new_files(%Context{} = context, paths, binding) do
    files = files_to_be_generated(context)

    if context.generate? do
      context_binding = [
        context: context,
        schema: context.schema,
        scope: context.scope,
        primary_key: context.schema.opts[:primary_key] || :id
      ]

      Gen.Context.copy_new_files(context, paths, context_binding)
    end

    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.react", binding, files)

    context
  end

  defp maybe_inject_page_registry(context, binding) do
    file_path = Path.join(File.cwd!(), "lib/phx_react/page_registry.ex")

    if File.exists?(file_path) do
      page_keys = Keyword.fetch!(binding, :page_keys)
      component_keys = Keyword.fetch!(binding, :component_keys)
      page_module = Keyword.fetch!(binding, :page_module)

      entries = [
        %{page_key: page_keys.index, component_key: component_keys.index},
        %{page_key: page_keys.show, component_key: component_keys.show},
        %{page_key: page_keys.form, component_key: component_keys.form}
      ]

      with {:ok, file} <- File.read(file_path),
           missing_entries <- Enum.reject(entries, &registry_entry_exists?(file, &1.page_key)),
           false <- missing_entries == [] do
        injected = registry_entries(missing_entries, page_module)

        closing_block = "\n  }\n\n  @spec fetch"
        replacement_prefix = if String.contains?(file, ",#{closing_block}"), do: "", else: ","

        new_file =
          String.replace(
            file,
            closing_block,
            "#{replacement_prefix}\n#{injected}\n  }\n\n  @spec fetch",
            global: false
          )

        if new_file != file do
          Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])
          File.write!(file_path, new_file)
        else
          Mix.shell().info("""
          Could not automatically inject entries into #{Path.relative_to_cwd(file_path)}.
          Add entries for #{page_keys.index}, #{page_keys.show}, and #{page_keys.form} manually.
          """)
        end
      else
        true ->
          :ok

        {:error, _reason} ->
          :ok
      end
    end

    context
  end

  defp maybe_inject_component_registry(context, binding) do
    file_path = Path.join(File.cwd!(), "assets/js/app.tsx")

    if File.exists?(file_path) do
      component_names = Keyword.fetch!(binding, :component_names)
      component_keys = Keyword.fetch!(binding, :component_keys)

      with {:ok, file} <- File.read(file_path) do
        new_file =
          file
          |> inject_component_imports(component_names)
          |> inject_component_entries(component_names, component_keys)

        if new_file != file do
          Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])
          File.write!(file_path, new_file)
        end
      end
    end

    context
  end

  defp inject_component_imports(file, component_names) do
    imports = [
      ~s(import #{component_names.index} from "./components/#{component_names.index}";\n),
      ~s(import #{component_names.show} from "./components/#{component_names.show}";\n),
      ~s(import #{component_names.form} from "./components/#{component_names.form}";\n)
    ]

    imports
    |> Enum.reject(&String.contains?(file, &1))
    |> Enum.reduce(file, fn line, acc ->
      String.replace(acc, "const PAGE_COMPONENTS = {\n", line <> "const PAGE_COMPONENTS = {\n",
        global: false
      )
    end)
  end

  defp inject_component_entries(file, component_names, component_keys) do
    entries = [
      ~s(  "#{component_keys.index}": #{component_names.index},\n),
      ~s(  "#{component_keys.show}": #{component_names.show},\n),
      ~s(  "#{component_keys.form}": #{component_names.form},\n)
    ]

    entries
    |> Enum.reject(&String.contains?(file, &1))
    |> Enum.reduce(file, fn line, acc ->
      String.replace(acc, "const PAGE_COMPONENTS = {\n", "const PAGE_COMPONENTS = {\n" <> line,
        global: false
      )
    end)
  end

  defp registry_entry_exists?(file, page_key) do
    String.contains?(file, ~s("#{page_key}" => %{))
  end

  defp registry_entries(entries, page_module) do
    Enum.map_join(entries, "\n", fn %{page_key: page_key, component_key: component_key} ->
      """
        "#{page_key}" => %{
          key: "#{page_key}",
          component_key: "#{component_key}",
          module: #{inspect(page_module)}
        },
      """
    end)
  end

  @doc false
  def print_shell_instructions(%Context{context_app: context_app} = context, binding) do
    controller_module = Keyword.fetch!(binding, :controller_module)
    route_base = Keyword.fetch!(binding, :route_base)
    primary_key_string = Keyword.fetch!(binding, :primary_key_string)
    web_path = Mix.Phoenix.web_path(context_app)

    Mix.shell().info("""

    Add the react routes to your browser scope in #{web_path}/router.ex:

        get "#{route_base}", #{inspect(controller_module)}, :index
        get "#{route_base}/new", #{inspect(controller_module)}, :new
        get "#{route_base}/:#{primary_key_string}", #{inspect(controller_module)}, :show
        get "#{route_base}/:#{primary_key_string}/edit", #{inspect(controller_module)}, :edit
    """)

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end

  defp resource_attrs(%Schema{} = schema) do
    Enum.reject(schema.attrs, fn
      {_key, {:references, _}} -> true
      _other -> false
    end)
  end

  defp field_spec({name, type}) do
    key = Atom.to_string(name)

    %{
      atom: name,
      key: key,
      label: Phoenix.Naming.humanize(key),
      ts_type: ts_type(type),
      input_kind: input_kind(type),
      input_type: input_type(type),
      default_js: default_js(type),
      default_elixir: default_elixir(type)
    }
  end

  defp ts_type(:integer), do: "number"
  defp ts_type(:float), do: "number"
  defp ts_type(:decimal), do: "number | string"
  defp ts_type(:boolean), do: "boolean"
  defp ts_type(:date), do: "string"
  defp ts_type(:time), do: "string"
  defp ts_type(:utc_datetime), do: "string"
  defp ts_type(:naive_datetime), do: "string"
  defp ts_type(:text), do: "string"
  defp ts_type({:array, _}), do: "string[]"
  defp ts_type({:enum, _}), do: "string"
  defp ts_type(_), do: "string"

  defp input_kind(:boolean), do: :checkbox
  defp input_kind(:text), do: :textarea
  defp input_kind(_), do: :input

  defp input_type(:integer), do: "number"
  defp input_type(:float), do: "number"
  defp input_type(:decimal), do: "number"
  defp input_type(:date), do: "date"
  defp input_type(:time), do: "time"
  defp input_type(:utc_datetime), do: "datetime-local"
  defp input_type(:naive_datetime), do: "datetime-local"
  defp input_type(_), do: "text"

  defp default_js(:boolean), do: "false"
  defp default_js({:array, _}), do: "[]"
  defp default_js(_), do: "\"\""

  defp default_elixir(:boolean), do: false
  defp default_elixir(_), do: ""

  defp schema_alias(%Schema{alias: alias_name}) do
    alias_name
    |> to_string()
    |> String.split(".")
    |> List.last()
  end
end
