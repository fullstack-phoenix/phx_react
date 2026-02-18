/**
 * PhxReact Socket wrapper for Phoenix Channels and HTTP actions/page payloads.
 */

import { Socket } from "phoenix";
import type { ActionEnvelope, ConnectionStatus } from "./types";

interface PagePayload {
  page_key: string;
  page_module: string;
  component_key: string;
  session_id: string;
  token: string;
  topic: string;
  initial_state: Record<string, unknown>;
}

interface PagePayloadResponse {
  status: "ok";
  page: PagePayload;
}

interface InitOptions {
  csrfToken: string;
  pageKey: string;
  sessionId: string;
  token: string;
  pageEndpoint: string;
  actionEndpoint: string;
  onStateUpdate: (state: Record<string, unknown>, changedKeys: string[]) => void;
  onStatusChange: (status: ConnectionStatus, error?: string | null) => void;
  onInvalidation: (payload: Record<string, unknown>) => void;
}

export class PhxReactSocket {
  private socket: Socket;
  private pageKey: string;
  private sessionId: string;
  private token: string;
  private pageEndpoint: string;
  private actionEndpoint: string;
  private csrfToken: string;
  private onStateUpdate: (state: Record<string, unknown>, changedKeys: string[]) => void;
  private onStatusChange: (status: ConnectionStatus, error?: string | null) => void;
  private onInvalidation: (payload: Record<string, unknown>) => void;

  public channel: any;
  public state: Record<string, unknown>;
  public status: ConnectionStatus;
  public lastError: string | null;

  constructor(options: InitOptions) {
    this.pageKey = options.pageKey;
    this.sessionId = options.sessionId;
    this.token = options.token;
    this.pageEndpoint = options.pageEndpoint;
    this.actionEndpoint = options.actionEndpoint;
    this.csrfToken = options.csrfToken;
    this.onStateUpdate = options.onStateUpdate;
    this.onStatusChange = options.onStatusChange;
    this.onInvalidation = options.onInvalidation;

    this.socket = new Socket("/phx_react", {
      params: { _csrf_token: options.csrfToken },
    });

    this.state = {};
    this.status = "disconnected";
    this.lastError = null;
    this.channel = null;
  }

  joinChannel() {
    this.socket.connect();
    this.updateStatus("connecting", null);

    const topic = `phx_react:${this.pageKey}:${this.sessionId}`;
    this.channel = this.socket.channel(topic, { token: this.token });

    this.channel.on("state", (payload: { assigns: Record<string, unknown>; changed_keys?: string[] }) => {
      const assigns = payload?.assigns || {};
      const changedKeys = payload?.changed_keys || [];
      this.state = assigns;
      this.onStateUpdate(assigns, changedKeys);
    });

    this.channel.on("invalidate", (payload: Record<string, unknown>) => {
      this.onInvalidation(payload || {});
    });

    this.channel
      .join()
      .receive("ok", () => {
        this.updateStatus("connected", null);
      })
      .receive("error", (resp: unknown) => {
        this.updateStatus("error", `Join failed: ${JSON.stringify(resp)}`);
      });

    this.channel.onError(() => {
      this.updateStatus("error", "Channel error");
    });

    this.channel.onClose(() => {
      this.updateStatus("disconnected", null);
    });

    return this.channel;
  }

  leaveChannel() {
    if (this.channel) {
      this.channel.leave();
      this.channel = null;
    }

    this.socket.disconnect();
    this.updateStatus("disconnected", null);
  }

  pushEvent(name: string, params: Record<string, unknown> = {}) {
    if (!this.channel) return;
    this.channel.push("event", { name, params });
  }

  invalidate(reason = "manual") {
    if (!this.channel) return;
    this.channel.push("invalidate", { reason });
  }

  async invokeAction(action: string, params: Record<string, unknown> = {}): Promise<ActionEnvelope> {
    const response = await fetch(this.actionEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "x-csrf-token": this.csrfToken,
      },
      body: JSON.stringify({
        page_key: this.pageKey,
        session_id: this.sessionId,
        token: this.token,
        action,
        params,
      }),
      credentials: "same-origin",
    });

    const envelope = (await response.json()) as ActionEnvelope;

    if (envelope.status === "redirect") {
      window.location.assign(envelope.to);
    }

    return envelope;
  }

  async fetchPage(pageKey: string, params: Record<string, string> = {}): Promise<PagePayload> {
    const query = new URLSearchParams({
      ...params,
      session_id: this.sessionId,
    });

    const response = await fetch(`${this.pageEndpoint}/${encodeURIComponent(pageKey)}?${query.toString()}`, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
      credentials: "same-origin",
    });

    const payload = (await response.json()) as PagePayloadResponse;
    return payload.page;
  }

  updateAuth(pagePayload: PagePayload) {
    this.pageKey = pagePayload.page_key;
    this.sessionId = pagePayload.session_id;
    this.token = pagePayload.token;
    this.state = pagePayload.initial_state;
  }

  private updateStatus(status: ConnectionStatus, error: string | null) {
    this.status = status;
    this.lastError = error;
    this.onStatusChange(status, error);
  }
}
