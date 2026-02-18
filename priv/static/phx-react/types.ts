/**
 * PhxReact TypeScript type definitions
 */

export type ConnectionStatus =
  | "connecting"
  | "connected"
  | "reconnecting"
  | "disconnected"
  | "error";

export interface ActionOkEnvelope {
  status: "ok";
  data: Record<string, unknown>;
}

export interface ActionErrorEnvelope {
  status: "error";
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export interface ActionRedirectEnvelope {
  status: "redirect";
  to: string;
}

export type ActionEnvelope =
  | ActionOkEnvelope
  | ActionErrorEnvelope
  | ActionRedirectEnvelope;

export interface PhxReactSocket {
  channel: any;
  state: any;
  status: ConnectionStatus;
  error: string | null;
  pushEvent: (name: string, params?: Record<string, unknown>) => void;
  invokeAction: (
    action: string,
    params?: Record<string, unknown>
  ) => Promise<ActionEnvelope>;
  refreshPage: (
    pageKey?: string,
    params?: Record<string, string>
  ) => Promise<void>;
  invalidate: (reason?: string) => void;
}

export interface PageComponentProps {
  socket: PhxReactSocket;
}

export interface PageComponent {
  (props: PageComponentProps): JSX.Element;
}

export interface PageComponents {
  [key: string]: PageComponent;
}
