import { useState } from "react";
import "./App.css";

function App() {
  const [gastos, setGastos] = useState([]);
  const [form, setForm] = useState({
    descripcion: "",
    categoria: "Comida",
    monto: "",
    fecha: "",
  });

const agregarGasto = async (e) => {
  e.preventDefault();

  const gasto = {
    descripcion: form.descripcion,
    categoria: form.categoria,
    monto: Number(form.monto),
    fecha: form.fecha,
  };

  try {
    const response = await fetch(
      "https://sdvngm2azl.execute-api.us-east-2.amazonaws.com/gastos",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(gasto),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      throw new Error("Error al guardar el gasto");
    }

    setGastos([...gastos, data]);

    setForm({
      descripcion: "",
      categoria: "Comida",
      monto: "",
      fecha: "",
    });
  } catch (error) {
    console.error(error);
    alert("No se pudo guardar el gasto");
  }
};

  const total = gastos.reduce((acc, gasto) => acc + gasto.monto, 0);

  return (
    <main className="contenedor">
      <h1>Gestor de Gastos</h1>

      <form onSubmit={agregarGasto} className="formulario">
        <input
          type="text"
          placeholder="Descripción"
          value={form.descripcion}
          onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
          required
        />

        <select
          value={form.categoria}
          onChange={(e) => setForm({ ...form, categoria: e.target.value })}
        >
          <option>Comida</option>
          <option>Transporte</option>
          <option>Servicios</option>
          <option>Ocio</option>
        </select>

        <input
          type="number"
          placeholder="Monto"
          value={form.monto}
          onChange={(e) => setForm({ ...form, monto: e.target.value })}
          required
        />

        <input
          type="date"
          value={form.fecha}
          onChange={(e) => setForm({ ...form, fecha: e.target.value })}
          required
        />

        <button type="submit">Agregar gasto</button>
      </form>

      <h2>Total: ${total}</h2>

      <ul>
        {gastos.map((gasto) => (
          <li key={gasto.id}>
            {gasto.fecha} - {gasto.descripcion} - {gasto.categoria} - $
            {gasto.monto}
          </li>
        ))}
      </ul>
    </main>
  );
}

export default App;