import React, { useEffect, useMemo, useState } from "react";
import type { PageComponentProps } from "../phx-react/types";

type FormState = {
<%= for field <- fields do %>  <%= field.key %>: <%= field.ts_type %>;
<% end %>};

const DEFAULT_FORM: FormState = {
<%= for field <- fields do %>  <%= field.key %>: <%= field.default_js %>,
<% end %>};

type FieldErrors = Record<string, string[]>;

export default function <%= component_names.form %>({ socket }: PageComponentProps) {
  const routeBase = (socket.state.route_base as string | undefined) || "<%= route_base %>";
  const mode = (socket.state.mode as string | undefined) || "new";
  const incomingForm = (socket.state.form as Partial<FormState> | undefined) || {};

  const [form, setForm] = useState<FormState>(() => ({ ...DEFAULT_FORM, ...incomingForm }));
  const [errors, setErrors] = useState<FieldErrors>({});
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    setForm({ ...DEFAULT_FORM, ...incomingForm });
  }, [socket.state.form]);

  const title = useMemo(
    () => (mode === "edit" ? "Edit <%= schema.human_singular %>" : "New <%= schema.human_singular %>"),
    [mode]
  );

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    const response = await socket.invokeAction("save", { attrs: form });

    if (response.status === "ok") {
      setErrorMessage(null);
      setErrors({});
      return;
    }

    if (response.status === "error") {
      setErrorMessage(response.error.message);
      const errorDetails = (response.error.details?.errors as FieldErrors | undefined) || {};
      setErrors(errorDetails);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="mx-auto max-w-3xl rounded bg-white p-6 shadow">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">{title}</h1>
          <a className="text-sm text-blue-600 hover:underline" href={routeBase}>
            Back
          </a>
        </div>

        {errorMessage ? (
          <p className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {errorMessage}
          </p>
        ) : null}

        <form onSubmit={submit} className="space-y-4">
<%= for field <- fields do %>
<%= if field.input_kind == :checkbox do %>
          <label className="flex items-center gap-2 text-sm text-gray-800">
            <input
              type="checkbox"
              checked={Boolean(form.<%= field.key %>)}
              onChange={(e) => setForm((prev) => ({ ...prev, <%= field.key %>: e.target.checked }))}
            />
            <%= field.label %>
          </label>
<% else %>
<%= if field.input_kind == :textarea do %>
          <div>
            <label className="mb-1 block text-sm font-semibold text-gray-700"><%= field.label %></label>
            <textarea
              value={String(form.<%= field.key %> ?? "")}
              onChange={(e) => setForm((prev) => ({ ...prev, <%= field.key %>: e.target.value }))}
              className="w-full rounded border border-gray-300 px-3 py-2"
              rows={4}
            />
            {errors["<%= field.key %>"] ? (
              <p className="mt-1 text-xs text-red-600">{errors["<%= field.key %>"].join(", ")}</p>
            ) : null}
          </div>
<% else %>
          <div>
            <label className="mb-1 block text-sm font-semibold text-gray-700"><%= field.label %></label>
            <input
              type="<%= field.input_type %>"
              value={String(form.<%= field.key %> ?? "")}
              onChange={(e) => setForm((prev) => ({ ...prev, <%= field.key %>: e.target.value as any }))}
              className="w-full rounded border border-gray-300 px-3 py-2"
            />
            {errors["<%= field.key %>"] ? (
              <p className="mt-1 text-xs text-red-600">{errors["<%= field.key %>"].join(", ")}</p>
            ) : null}
          </div>
<% end %>
<% end %>
<% end %>
          <div className="pt-2">
            <button
              type="submit"
              className="rounded bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
            >
              Save <%= schema.human_singular %>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
