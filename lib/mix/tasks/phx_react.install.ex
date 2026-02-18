defmodule Mix.Tasks.PhxReact.Install do
  @shortdoc "Installs PhxReact into a Phoenix application"

  @moduledoc """
  Installs PhxReact into a Phoenix application.

      mix phx_react.install

  This task will:

    1. Copy JS runtime files to `assets/js/phx-react/`
    2. Generate `lib/<app>_web/channels/phx_react_socket.ex`
    3. Generate `lib/<app>_web/controllers/react_controller.ex`
    4. Generate `lib/<app>_web/controllers/react_html.ex`
    5. Generate `lib/<app>_web/controllers/react_html/shell.html.heex`
    6. Generate `lib/phx_react/page_registry.ex`

  After running this task, follow the printed instructions to complete the setup.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    app = Mix.Project.config()[:app]
    web_module = web_module(app)
    web_path = web_path(app)

    binding = [web_module: web_module]

    copy_js_files()
    generate_socket(web_path, binding)
    generate_controller(web_path, binding)
    generate_html(web_path, binding)
    generate_shell_template(web_path)
    generate_page_registry(binding)

    print_instructions(app, web_module, web_path)
  end

  defp copy_js_files do
    dest_dir = "assets/js/phx-react"
    File.mkdir_p!(dest_dir)

    priv_dir = :code.priv_dir(:phx_react) |> to_string()
    src_dir = Path.join(priv_dir, "static/phx-react")

    for file <- ["socket.ts", "runtime.tsx", "types.ts"] do
      src = Path.join(src_dir, file)
      dest = Path.join(dest_dir, file)

      if File.exists?(dest) do
        Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
      else
        File.copy!(src, dest)
        Mix.shell().info([:green, "* creating ", :reset, dest])
      end
    end
  end

  defp generate_socket(web_path, binding) do
    dest = Path.join([web_path, "channels", "phx_react_socket.ex"])

    if File.exists?(dest) do
      Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
    else
      File.mkdir_p!(Path.dirname(dest))
      content = render_template("phx_react_socket.ex.eex", binding)
      File.write!(dest, content)
      Mix.shell().info([:green, "* creating ", :reset, dest])
    end
  end

  defp generate_controller(web_path, binding) do
    dest = Path.join([web_path, "controllers", "react_controller.ex"])

    if File.exists?(dest) do
      Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
    else
      File.mkdir_p!(Path.dirname(dest))
      content = render_template("react_controller.ex.eex", binding)
      File.write!(dest, content)
      Mix.shell().info([:green, "* creating ", :reset, dest])
    end
  end

  defp generate_html(web_path, binding) do
    dest = Path.join([web_path, "controllers", "react_html.ex"])

    if File.exists?(dest) do
      Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
    else
      content = render_template("react_html.ex.eex", binding)
      File.write!(dest, content)
      Mix.shell().info([:green, "* creating ", :reset, dest])
    end
  end

  defp generate_shell_template(web_path) do
    dest = Path.join([web_path, "controllers", "react_html", "shell.html.heex"])

    if File.exists?(dest) do
      Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
    else
      File.mkdir_p!(Path.dirname(dest))
      src = template_path("shell.html.heex")
      File.copy!(src, dest)
      Mix.shell().info([:green, "* creating ", :reset, dest])
    end
  end

  defp generate_page_registry(_binding) do
    dest = "lib/phx_react/page_registry.ex"

    if File.exists?(dest) do
      Mix.shell().info([:yellow, "* skipping ", :reset, dest, " (already exists)"])
    else
      File.mkdir_p!(Path.dirname(dest))
      content = render_template("page_registry.ex.eex", [])
      File.write!(dest, content)
      Mix.shell().info([:green, "* creating ", :reset, dest])
    end
  end

  defp render_template(template_name, binding) do
    path = template_path(template_name)
    EEx.eval_file(path, assigns: Map.new(binding))
  end

  defp template_path(name) do
    priv_dir = :code.priv_dir(:phx_react) |> to_string()
    Path.join([priv_dir, "templates", "phx_react.install", name])
  end

  defp web_module(app) do
    app
    |> to_string()
    |> Macro.camelize()
    |> then(&Module.concat([&1 <> "Web"]))
  end

  defp web_path(app) do
    "lib/#{app}_web"
  end

  defp print_instructions(app, web_module, web_path) do
    Mix.shell().info("""

    PhxReact installed successfully!

    Complete the setup by making the following manual changes:

    1. Add PhxReact.PageSupervisor to your application children in lib/#{app}/application.ex:

        children = [
          # ... existing children ...
          PhxReact.PageSupervisor
        ]

    2. Add the PhxReact socket to your endpoint in #{web_path}/endpoint.ex:

        socket "/phx_react", #{inspect(web_module)}.PhxReactSocket,
          websocket: true,
          longpoll: false

    3. Add routes to your router in #{web_path}/router.ex:

        scope "/react", #{inspect(web_module)} do
          pipe_through :browser

          get "/pages/:page_key", ReactController, :show
          post "/actions", ReactController, :dispatch_action
        end

        # Optional: JSON endpoint for page payloads
        scope "/react", #{inspect(web_module)} do
          pipe_through :api

          get "/pages/:page_key", ReactController, :page
        end

    4. Import the PhxReact runtime in your assets/js/app.tsx (or app.js):

        import { initPhxReact } from "./phx-react/runtime";

        const PAGE_COMPONENTS = {
          // Add your page components here
        };

        initPhxReact(PAGE_COMPONENTS);

    5. Add jason to your dependencies in mix.exs (if not already present):

        {:jason, "~> 1.2"}

    Then run: mix deps.get
    """)
  end
end
