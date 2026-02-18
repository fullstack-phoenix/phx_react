import React, { useState } from "react";
import type { PageComponentProps } from "../phx-react/types";

interface <%= schema_alias %> {
  <%= primary_key %>: string | number;
<%= for field <- fields do %>  <%= field.key %>: <%= field.ts_type %>;
<% end %>}

export default function <%= component_names.index %>({ socket }: PageComponentProps) {
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const items = (socket.state.<%= schema.plural %> as <%= schema_alias %>[] | undefined) || [];
  const routeBase = (socket.state.route_base as string | undefined) || "<%= route_base %>";

  const handleDelete = async (id: string | number) => {
    const response = await socket.invokeAction("delete", { id: String(id) });

    if (response.status === "ok") {
      setErrorMessage(null);
      await socket.refreshPage("<%= page_keys.index %>");
    } else if (response.status === "error") {
      setErrorMessage(response.error.message);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="mx-auto max-w-5xl">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-900">Listing <%= schema.human_plural %></h1>
          <a
            href={`${routeBase}/new`}
            className="rounded bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            New <%= schema.human_singular %>
          </a>
        </div>

        {errorMessage ? (
          <p className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {errorMessage}
          </p>
        ) : null}

        <div className="overflow-hidden rounded bg-white shadow">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
<%= for field <- fields do %>                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  <%= field.label %>
                </th>
<% end %>                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 bg-white">
              {items.map((item) => (
                <tr key={String(item.<%= primary_key %>)}>
<%= for field <- fields do %>                  <td className="px-4 py-3 text-sm text-gray-800">{String(item.<%= field.key %> ?? "")}</td>
<% end %>                  <td className="px-4 py-3 text-sm text-gray-700">
                    <div className="flex gap-3">
                      <a className="text-blue-600 hover:underline" href={`${routeBase}/${item.<%= primary_key %>}`}>
                        Show
                      </a>
                      <a className="text-blue-600 hover:underline" href={`${routeBase}/${item.<%= primary_key %>}/edit`}>
                        Edit
                      </a>
                      <button
                        className="text-red-600 hover:underline"
                        onClick={() => handleDelete(item.<%= primary_key %>)}
                        type="button"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {items.length === 0 ? (
            <p className="p-6 text-sm text-gray-500">No <%= schema.human_plural %> yet.</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
