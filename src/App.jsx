import { useCallback, useEffect, useState } from "react";
import "./App.css";
import {
  actualizarCliente,
  crearCliente,
  eliminarCliente,
  obtenerClientes,
} from "./services/clientesApi";
import {
  handleAuthRedirect,
  isAuthenticated,
  login,
  logout,
} from "./services/auth";

const FORM_INICIAL = {
  nombre: "",
  apellido: "",
};

function normalizarCliente(form) {
  return {
    nombre: form.nombre.trim(),
    apellido: form.apellido.trim(),
  };
}

function App() {
  const [clientes, setClientes] = useState([]);
  const [form, setForm] = useState(FORM_INICIAL);
  const [clienteEditandoId, setClienteEditandoId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [guardando, setGuardando] = useState(false);
  const [error, setError] = useState("");
  const [autenticado, setAutenticado] = useState(() => isAuthenticated());

  const cargarClientes = useCallback(async () => {
    setLoading(true);
    setError("");

    try {
      const data = await obtenerClientes();
      setClientes(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  const limpiarFormulario = () => {
    setForm(FORM_INICIAL);
    setClienteEditandoId(null);
  };

  const guardarCliente = async (e) => {
    e.preventDefault();
    setError("");

    const cliente = normalizarCliente(form);

    if (!cliente.nombre || !cliente.apellido) {
      setError("Nombre y apellido son obligatorios");
      return;
    }

    setGuardando(true);

    try {
      if (clienteEditandoId) {
        await actualizarCliente(clienteEditandoId, cliente);
      } else {
        await crearCliente(cliente);
      }

      limpiarFormulario();
      await cargarClientes();
    } catch (err) {
      setError(err.message);
    } finally {
      setGuardando(false);
    }
  };

  const empezarEdicion = (cliente) => {
    setClienteEditandoId(cliente.ID);
    setForm({
      nombre: cliente.nombre ?? "",
      apellido: cliente.apellido ?? "",
    });
    setError("");
  };

  const borrarCliente = async (cliente) => {
    const nombreCompleto = `${cliente.nombre} ${cliente.apellido}`.trim();
    const confirmar = window.confirm(
      `¿Seguro que querés eliminar a ${nombreCompleto || "este cliente"}?`
    );

    if (!confirmar) {
      return;
    }

    setError("");

    try {
      await eliminarCliente(cliente.ID);
      await cargarClientes();
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    try {
      if (handleAuthRedirect()) {
        setAutenticado(true);
        return;
      }
    } catch (err) {
      setError(err.message);
    }

    if (!autenticado) {
      return;
    }

    const timeoutId = window.setTimeout(cargarClientes, 0);

    return () => window.clearTimeout(timeoutId);
  }, [autenticado, cargarClientes]);

  const cerrarSesion = () => {
    setClientes([]);
    limpiarFormulario();
    setAutenticado(false);
    logout();
  };

  const iniciarSesion = () => {
    try {
      login();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <main className="app-shell">
      <section className="panel">
        <div className="header">
          <p className="eyebrow">CRUD conectado a AWS Lambda</p>
          <h1>Clientes AWS</h1>
          <p className="description">
            Creá, listá, editá y eliminá clientes con endpoints protegidos por
            Cognito.
          </p>

          <div className="auth-actions">
            {autenticado ? (
              <button className="secondary" type="button" onClick={cerrarSesion}>
                Cerrar sesión
              </button>
            ) : (
              <button type="button" onClick={iniciarSesion}>
                Iniciar sesión
              </button>
            )}
          </div>
        </div>

        {error && <p className="alert error">{error}</p>}

        {!autenticado ? (
          <p className="alert info">
            Iniciá sesión con Cognito para gestionar clientes.
          </p>
        ) : (
          <>
            <form className="cliente-form" onSubmit={guardarCliente}>
              <label>
                Nombre
                <input
                  minLength={2}
                  placeholder="Ej: Juan"
                  required
                  type="text"
                  value={form.nombre}
                  onChange={(e) =>
                    setForm({ ...form, nombre: e.target.value })
                  }
                />
              </label>

              <label>
                Apellido
                <input
                  minLength={2}
                  placeholder="Ej: Pérez"
                  required
                  type="text"
                  value={form.apellido}
                  onChange={(e) =>
                    setForm({ ...form, apellido: e.target.value })
                  }
                />
              </label>

              <div className="form-actions">
                <button disabled={guardando} type="submit">
                  {guardando
                    ? "Guardando..."
                    : clienteEditandoId
                      ? "Guardar cambios"
                      : "Crear cliente"}
                </button>

                {clienteEditandoId && (
                  <button
                    className="secondary"
                    type="button"
                    onClick={limpiarFormulario}
                  >
                    Cancelar edición
                  </button>
                )}
              </div>
            </form>

            {loading && <p className="alert info">Cargando clientes...</p>}

            <section className="listado" aria-labelledby="listado-clientes">
              <div className="listado-header">
                <h2 id="listado-clientes">Listado</h2>
                <span>{clientes.length} clientes</span>
              </div>

              {!loading && clientes.length === 0 ? (
                <p className="empty">Todavía no hay clientes cargados.</p>
              ) : (
                <div className="clientes-grid">
                  {clientes.map((cliente) => (
                    <article className="cliente-card" key={cliente.ID}>
                      <div>
                        <strong>
                          {cliente.nombre} {cliente.apellido}
                        </strong>
                        <small>ID: {cliente.ID}</small>
                      </div>

                      <div className="card-actions">
                        <button
                          className="secondary"
                          type="button"
                          onClick={() => empezarEdicion(cliente)}
                        >
                          Editar
                        </button>

                        <button
                          className="danger"
                          type="button"
                          onClick={() => borrarCliente(cliente)}
                        >
                          Eliminar
                        </button>
                      </div>
                    </article>
                  ))}
                </div>
              )}
            </section>
          </>
        )}
      </section>
    </main>
  );
}

export default App;