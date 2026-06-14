const API_URL = import.meta.env.VITE_API_URL;
import { getToken } from "./auth";
function getApiUrl() {
  if (!API_URL) {
    throw new Error("Falta configurar VITE_API_URL en el archivo .env");
  }

  return API_URL;
}

function buildClientUrl(id) {
  const url = new URL(getApiUrl());
  url.searchParams.set("id", id);
  return url.toString();
}

async function parseResponse(response) {
  const text = await response.text();

  if (!text) {
    return null;
  }

  return JSON.parse(text);
}

async function request(url, options, errorMessage) {
 const token = getToken();

  if (!token) {
    throw new Error("Iniciá sesión para usar el CRUD de clientes");
  }

  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...options?.headers,
    },
  });
  const data = await parseResponse(response);

  if (!response.ok) {
    throw new Error(data?.message || errorMessage);
  }

  return data;
}

export async function obtenerClientes() {
  const data = await request(
    getApiUrl(),
    undefined,
    "No se pudieron obtener los clientes"
  );

  return Array.isArray(data) ? data : [];
}

export async function crearCliente(cliente) {
  return request(
    getApiUrl(),
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(cliente),
    },
    "No se pudo crear el cliente"
  );
}

export async function actualizarCliente(id, cliente) {
  return request(
    buildClientUrl(id),
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(cliente),
    },
    "No se pudo actualizar el cliente"
  );
}

export async function eliminarCliente(id) {
  return request(
    buildClientUrl(id),
    {
      method: "DELETE",
    },
    "No se pudo eliminar el cliente"
  );
}
