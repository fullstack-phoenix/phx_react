/**
 * PhxReact Runtime
 *
 * Bootstraps React from HTML data attributes and manages channel + HTTP runtime.
 */

import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { PhxReactSocket } from "./socket";
import type { ActionEnvelope, ConnectionStatus, PageComponents } from "./types";

interface BootstrapData {
  pageKey: string;
  componentKey: string;
  pageModule: string;
  sessionId: string;
  token: string;
  initialState: Record<string, unknown>;
  pageEndpoint: string;
  actionEndpoint: string;
  csrfToken: string;
}

interface RuntimePage {
  pageKey: string;
  pageModule: string;
  componentKey: string;
  sessionId: string;
  token: string;
}

export function initPhxReact(pageComponents: PageComponents) {
  const rootElement = document.getElementById("phx-react-root");
  if (!rootElement) {
    return;
  }

  const bootstrapData = readBootstrapData(rootElement);
  if (!bootstrapData) {
    return;
  }

  const root = createRoot(rootElement);
  root.render(<App pageComponents={pageComponents} bootstrapData={bootstrapData} />);
}

function readBootstrapData(rootElement: HTMLElement): BootstrapData | null {
  const pageKey = rootElement.dataset.pageKey;
  const componentKey = rootElement.dataset.componentKey || pageKey;
  const pageModule = rootElement.dataset.pageModule;
  const sessionId = rootElement.dataset.sessionId;
  const token = rootElement.dataset.token;
  const initialStateJson = rootElement.dataset.initialState;
  const pageEndpoint = rootElement.dataset.pageEndpoint;
  const actionEndpoint = rootElement.dataset.actionEndpoint;
  const csrfToken =
    rootElement.dataset.csrfToken ||
    document.querySelector("meta[name='csrf-token']")?.getAttribute("content");

  if (
    !pageKey ||
    !componentKey ||
    !pageModule ||
    !sessionId ||
    !token ||
    !initialStateJson ||
    !pageEndpoint ||
    !actionEndpoint ||
    !csrfToken
  ) {
    console.error("PhxReact: Missing required data attributes");
    return null;
  }

  try {
    const initialState = JSON.parse(initialStateJson) as Record<string, unknown>;

    return {
      pageKey,
      componentKey,
      pageModule,
      sessionId,
      token,
      initialState,
      pageEndpoint,
      actionEndpoint,
      csrfToken,
    };
  } catch (error) {
    console.error("PhxReact: Failed to parse initial state", error);
    return null;
  }
}

interface AppProps {
  pageComponents: PageComponents;
  bootstrapData: BootstrapData;
}

function App({ pageComponents, bootstrapData }: AppProps) {
  const [page, setPage] = useState<RuntimePage>({
    pageKey: bootstrapData.pageKey,
    pageModule: bootstrapData.pageModule,
    componentKey: bootstrapData.componentKey,
    sessionId: bootstrapData.sessionId,
    token: bootstrapData.token,
  });
  const [state, setState] = useState<Record<string, unknown>>(bootstrapData.initialState);
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>("connecting");
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [runtimeSocket, setRuntimeSocket] = useState<PhxReactSocket | null>(null);

  useEffect(() => {
    const nextSocket = new PhxReactSocket({
      csrfToken: bootstrapData.csrfToken,
      pageKey: page.pageKey,
      sessionId: page.sessionId,
      token: page.token,
      pageEndpoint: bootstrapData.pageEndpoint,
      actionEndpoint: bootstrapData.actionEndpoint,
      onStateUpdate: (nextState) => {
        setState(nextState);
      },
      onStatusChange: (status, error) => {
        setConnectionStatus(status);
        setConnectionError(error || null);
      },
      onInvalidation: () => {
        void refreshPage(page.pageKey, {});
      },
    });

    nextSocket.joinChannel();
    setRuntimeSocket(nextSocket);

    return () => {
      nextSocket.leaveChannel();
      setRuntimeSocket(null);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bootstrapData.actionEndpoint, bootstrapData.csrfToken, bootstrapData.pageEndpoint, page.pageKey, page.sessionId, page.token]);

  const invokeAction = async (
    action: string,
    params: Record<string, unknown> = {}
  ): Promise<ActionEnvelope> => {
    if (!runtimeSocket) {
      return {
        status: "error",
        error: { code: "not_connected", message: "Socket not connected" },
      };
    }

    return runtimeSocket.invokeAction(action, params);
  };

  const refreshPage = async (targetPageKey = page.pageKey, params: Record<string, string> = {}) => {
    if (!runtimeSocket) {
      throw new Error("Socket not connected");
    }

    const pagePayload = await runtimeSocket.fetchPage(targetPageKey, params);
    runtimeSocket.updateAuth(pagePayload);

    setPage({
      pageKey: pagePayload.page_key,
      pageModule: pagePayload.page_module,
      componentKey: pagePayload.component_key,
      sessionId: pagePayload.session_id,
      token: pagePayload.token,
    });
    setState(pagePayload.initial_state);
  };

  const PageComponent = pageComponents[page.componentKey] || pageComponents[page.pageModule];
  if (!PageComponent) {
    return <div>Component not found for page: {page.componentKey}</div>;
  }

  const socketProp = useMemo(
    () => ({
      channel: runtimeSocket?.channel || null,
      state,
      status: connectionStatus,
      error: connectionError,
      pushEvent: (name: string, params: Record<string, unknown> = {}) => runtimeSocket?.pushEvent(name, params),
      invokeAction,
      refreshPage,
      invalidate: (reason?: string) => runtimeSocket?.invalidate(reason),
    }),
    [connectionError, connectionStatus, runtimeSocket, state]
  );

  return <PageComponent socket={socketProp} />;
}
