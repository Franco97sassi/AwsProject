const COGNITO_DOMAIN = import.meta.env.VITE_COGNITO_DOMAIN;
const COGNITO_CLIENT_ID = import.meta.env.VITE_COGNITO_CLIENT_ID;
const COGNITO_REDIRECT_URI = import.meta.env.VITE_COGNITO_REDIRECT_URI || window.location.origin;
const COGNITO_LOGOUT_URI = import.meta.env.VITE_COGNITO_LOGOUT_URI || window.location.origin;
const TOKEN_KEY = "clientes_aws_id_token";

function getAuthConfig() {
  if (!COGNITO_DOMAIN || !COGNITO_CLIENT_ID) {
    throw new Error("Falta configurar Cognito en las variables VITE_COGNITO_DOMAIN y VITE_COGNITO_CLIENT_ID");
  }

  return {
    domain: COGNITO_DOMAIN.replace(/\/$/, ""),
    clientId: COGNITO_CLIENT_ID,
    redirectUri: COGNITO_REDIRECT_URI,
    logoutUri: COGNITO_LOGOUT_URI,
  };
}

function buildUrl(path, params) {
  const { domain } = getAuthConfig();
  const url = new URL(`${domain}${path}`);

  Object.entries(params).forEach(([key, value]) => {
    url.searchParams.set(key, value);
  });

  return url.toString();
}

export function getToken() {
  return window.localStorage.getItem(TOKEN_KEY);
}

export function isAuthenticated() {
  return Boolean(getToken());
}

export function login() {
  const { clientId, redirectUri } = getAuthConfig();

  window.location.assign(
    buildUrl("/oauth2/authorize", {
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: "token",
      scope: "openid email profile",
    })
  );
}

export function logout() {
  const { clientId, logoutUri } = getAuthConfig();
  window.localStorage.removeItem(TOKEN_KEY);

  window.location.assign(
    buildUrl("/logout", {
      client_id: clientId,
      logout_uri: logoutUri,
    })
  );
}

export function handleAuthRedirect() {
  const hash = new URLSearchParams(window.location.hash.slice(1));
  const idToken = hash.get("id_token");
  const error = hash.get("error_description") || hash.get("error");

  if (error) {
    window.history.replaceState(null, "", window.location.pathname + window.location.search);
    throw new Error(error);
  }

  if (!idToken) {
    return false;
  }

  window.localStorage.setItem(TOKEN_KEY, idToken);
  window.history.replaceState(null, "", window.location.pathname + window.location.search);
  return true;
}
