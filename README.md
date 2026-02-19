# PhxReact

PhxReact is a Phoenix + React integration package for server-owned page state with:

- page modules (`PhxReact.Page`) running as GenServers
- real-time updates over Phoenix Channels
- HTTP action dispatch (`/react/actions`)
- generators for React-backed CRUD resources (`mix phx.gen.react`)

## Status

This project is currently under active extraction and hardening from a production app.
The install and generator flows work, and are being optimized for fresh-app UX.

## Add Dependency

If using Hex (once published):

```elixir
def deps do
  [
    {:phx_react, "~> 0.1.0"}
  ]
end
```

If using directly from Git while iterating:

```elixir
def deps do
  [
    {:phx_react, github: "fullstack-phoenix/phx_react"}
  ]
end
```

Then fetch deps:

```bash
mix deps.get
```

## Install Into a Phoenix App

Run:

```bash
mix phx_react.install
```

This generates:

- `assets/js/phx-react/socket.ts`
- `assets/js/phx-react/runtime.tsx`
- `assets/js/phx-react/types.ts`
- `assets/js/components/PhxReactItWorks.tsx`
- `lib/<app>_web/channels/phx_react_socket.ex`
- `lib/<app>_web/controllers/react_controller.ex`
- `lib/<app>_web/controllers/react_html.ex`
- `lib/<app>_web/controllers/react_html/shell.html.heex`
- `lib/<app>_web/pages/phx_react_it_works_page.ex`
- `lib/phx_react/page_registry.ex`

## Manual Setup

Add socket in `lib/<app>_web/endpoint.ex`:

```elixir
socket "/phx_react", MyAppWeb.PhxReactSocket,
  websocket: true,
  longpoll: false
```

Add routes in `lib/<app>_web/router.ex`:

```elixir
scope "/react", MyAppWeb do
  pipe_through :browser

  get "/pages/:page_key", ReactController, :show
  post "/actions", ReactController, :dispatch_action
end

# JSON endpoint used by the runtime for refresh/invalidation
scope "/react", MyAppWeb do
  pipe_through :api

  get "/page_payloads/:page_key", ReactController, :page
end
```

Install React packages in `assets/`:

```bash
cd assets
npm install react react-dom
npm install --save-dev @types/react @types/react-dom
```

Or with bun:

```bash
cd assets
bun add react react-dom
```

Wire runtime in `assets/js/app.tsx` (or `assets/js/app.js`):

```tsx
import PhxReactItWorks from "./components/PhxReactItWorks";
import { initPhxReact } from "./phx-react/runtime";

const PAGE_COMPONENTS = {
  phx_react_it_works: PhxReactItWorks,
};

initPhxReact(PAGE_COMPONENTS);
```

If your app does not already include `:jason`, add:

```elixir
{:jason, "~> 1.2"}
```

Then run:

```bash
mix deps.get
```

## Verify Install

Start the app and open:

```text
/react/pages/phx_react_it_works
```

You should see the generated "PhxReact It Works" page rendered by React from server state.

## Generate a CRUD Resource

Example:

```bash
mix phx.gen.react Boards Board boards title:string description:text
```

This reuses Phoenix context/schema generation and also creates:

- `<resource>_react_controller.ex`
- `<resource>_page.ex`
- `assets/js/components/<Resource>Index.tsx`
- `assets/js/components/<Resource>Show.tsx`
- `assets/js/components/<Resource>Form.tsx`

Then add the generated routes to your browser scope (the task prints exact lines). Use explicit `get` routes for index/new/show/edit.

## Current Caveats

- `mix phx.gen.react` does not auto-inject routes into `router.ex`.
- Component injection expects `assets/js/app.tsx` to contain:
  - `const PAGE_COMPONENTS = {`
- Page registry injection expects the default map structure in:
  - `lib/phx_react/page_registry.ex`
- Generated form TypeScript may require manual coercion for numeric/date fields.
