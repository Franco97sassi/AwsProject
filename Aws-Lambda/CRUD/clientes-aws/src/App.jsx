import { useEffect, useState } from "react";

const API_URL = "https://phl3ntiiiierdnims6bjnm5ecy0ycyxb.lambda-url.us-east-2.on.aws/";

function App() {
  const [clientes, setClientes] = useState([]);
  const [form, setForm] = useState({
    nombre: "",
    apellido: ""
  });

  const obtenerClientes = async () => {
    const res = await fetch(API_URL);
    const data = await res.json();
    setClientes(data);
  };

  const crearCliente = async (e) => {
    e.preventDefault();

    await fetch(API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(form)
    });

    setForm({ nombre: "", apellido: "" });
    obtenerClientes();
  };

  const eliminarCliente = async (id) => {
    await fetch(`${API_URL}?id=${id}`, {
      method: "DELETE"
    });

    obtenerClientes();
  };

  useEffect(() => {
    obtenerClientes();
  }, []);

  return (
    <div style={{ padding: "30px", fontFamily: "Arial" }}>
      <h1>Clientes AWS Lambda</h1>

      <form onSubmit={crearCliente}>
        <input
          placeholder="Nombre"
          value={form.nombre}
          onChange={(e) =>
            setForm({ ...form, nombre: e.target.value })
          }
        />

        <input
          placeholder="Apellido"
          value={form.apellido}
          onChange={(e) =>
            setForm({ ...form, apellido: e.target.value })
          }
        />

        <button type="submit">Crear cliente</button>
      </form>

      <hr />

      <h2>Listado</h2>

      {clientes.map((cliente) => (
        <div key={cliente.ID}>
          <strong>
            {cliente.nombre} {cliente.apellido}
          </strong>

          <button onClick={() => eliminarCliente(cliente.ID)}>
            Eliminar
          </button>
        </div>
      ))}
    </div>
  );
}

export default App;