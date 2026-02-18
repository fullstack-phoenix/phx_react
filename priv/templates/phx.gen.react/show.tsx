import React, { useState } from "react";
import type { PageComponentProps } from "../phx-react/types";

interface <%= schema_alias %> {
  <%= primary_key %>: string | number;
<%= for field <- fields do %>  <%= field.key %>: <%= field.ts_type %>;
<% end %>}

export default function <%= component_names.show %>({ socket }: PageComponentProps) {
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const routeBase = (socket.state.route_base as string | undefined) || "<%= route_base %>";
  const item = socket.state.<%= schema.singular %> as <%= schema_alias %> | undefined;

  const handleDelete = async () => {
    if (!item) return;

    const response = await socket.invokeAction("delete", { id: String(item.<%= primary_key %>) });

    if (response.status === "ok") {
      window.location.assign(routeBase);
    } else if (response.status === "error") {
      setErrorMessage(response.error.message);
    }
  };

  if (!item) {
    return (
      <div className="p-8">
        <p className="text-sm text-gray-600">Record not found.</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="mx-auto max-w-3xl rounded bg-white p-6 shadow">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Show <%= schema.human_singular %></h1>
          <a className="text-sm text-blue-600 hover:underline" href={routeBase}>
            Back
          </a>
        </div>

        {errorMessage ? (
          <p className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {errorMessage}
          </p>
        ) : null}

        <dl className="grid grid-cols-1 gap-4 sm:grid-cols-2">
<%= for field <- fields do %>          <div>
            <dt className="text-xs font-semibold uppercase tracking-wider text-gray-500"><%= field.label %></dt>
            <dd className="mt-1 text-sm text-gray-900">{String(item.<%= field.key %> ?? "")}</dd>
          </div>
<% end %>        </dl>

        <div className="mt-8 flex gap-3">
          <a
            href={`${routeBase}/${item.<%= primary_key %>}/edit`}
            className="rounded bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            Edit
          </a>
          <button
            type="button"
            onClick={handleDelete}
            className="rounded bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}
