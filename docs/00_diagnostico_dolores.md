# Fase 0 · Diagnóstico del negocio

**Proyecto 1:** Inteligencia comercial y análisis de ventas
**Empresa:** Distribuidora Caribe Mayorista S.A.S. *(empresa ficticia; datos sintéticos generados para este caso)*
**Autor:** Johan Andrés Marcelo Villorina · Analista de Datos
**Estado de la fase:** ✅ Cerrada

---

## 1. Contexto de la empresa

| Elemento | Definición |
|---|---|
| Sede principal | Barranquilla, Colombia |
| Zonas de venta | Atlántico, Bolívar, Magdalena, Córdoba, Sucre |
| Portafolio | Consumo masivo: abarrotes, bebidas, aseo, cuidado personal, snacks |
| Tipos de cliente | Tiendas de barrio, minimercados, supermercados, droguerías |
| Tamaño | ~600 clientes · 12 vendedores · ~250 productos |
| Ventas anuales de referencia | ~$25.000 millones COP |
| Condiciones de pago | Contado · crédito a 30 días · crédito a 60 días |
| Histórico disponible | Enero 2024 – octubre 2026 (34 meses) |
| Solicitantes | Gerente general y jefe comercial |

---

## 2. Dolores del negocio

1. **Información dispersa.** Cada vendedor lleva su propio Excel, el cierre de mes tarda días y cada área presenta una cifra diferente.
2. **Venden más, pero ganan menos.** Las ventas crecen, pero no se conoce el margen real por producto, cliente ni zona, y los descuentos no tienen control.
3. **Pérdida silenciosa de clientes.** Los clientes dejan de comprar y nadie lo detecta a tiempo.
4. **Metas visibles demasiado tarde.** El cumplimiento de cada vendedor y zona solo se conoce al cierre del mes.
5. **Cartera vencida sin control.** No se sabe con claridad quién debe, cuánto ni desde cuándo.

---

## 3. Impacto estimado (hipótesis del cliente)

> Estas cifras representan la percepción de la gerencia, recogida en el levantamiento inicial. El análisis de la Fase 4 las **confirma o las refuta**.

| # | Dolor | Percepción del cliente | Impacto estimado | Medición |
|---|---|---|---|---|
| 1 | Información dispersa | El cierre de mes tarda 5 días y las cifras no coinciden | ~80 horas al mes de trabajo manual; decisiones tardías | Tiempo de generación del reporte antes y después |
| 2 | Margen en caída | "Vendemos más, pero queda menos plata" | Cada punto de margen ≈ $250 millones al año | Margen bruto %, descuento promedio % |
| 3 | Clientes perdidos | "Hay clientes que ya no vemos" | Ventas perdidas no cuantificadas | % de clientes inactivos, tasa de retención |
| 4 | Metas tardías | "Siempre incumplen los mismos vendedores" | No hay margen para corregir dentro del mes | % de cumplimiento de meta acumulado |
| 5 | Cartera vencida | "Nos deben mucho y no sabemos quién" | Presión sobre la liquidez | Cartera vencida %, DSO |

---

## 4. Matriz de trazabilidad

| # | Dolor | Pregunta de negocio | KPI · Fórmula | Fuente | Visual | Decisión |
|---|---|---|---|---|---|---|
| 1 | Información dispersa | ¿Cuánto vendimos por zona y período, sin consolidar a mano? | **Ventas netas** = Σ(cantidad × precio) − descuentos | SQL | Tarjetas KPI + filtros | Reporte único oficial |
| 2 | Margen en caída | ¿Qué productos, clientes y zonas reducen el margen? | **Margen bruto %** = (ventas netas − costo) / ventas netas · **Descuento %** = descuentos / ventas brutas | SQL | Matriz zona × categoría con colores | Topes a los descuentos |
| 3 | Clientes perdidos | ¿Cuántos clientes dejaron de comprar y cuánto vendían? | **% de clientes inactivos** = clientes sin compra en más de 60 días / clientes activos en los últimos 12 meses | SQL | Segmentación RFM + lista de clientes en riesgo | Plan de recuperación por vendedor |
| 4 | Metas tardías | ¿Quién va por debajo de la meta hoy? | **% de cumplimiento** = ventas acumuladas / meta acumulada a la fecha | SQL + Excel | Barras con semáforo | Corrección dentro del mes |
| 5 | Cartera vencida | ¿Quién debe, cuánto y desde cuándo? | **Cartera vencida %** = saldo vencido / saldo total · **DSO** = (cartera / ventas a crédito) × días | SQL | Cartera por edades (0–30, 31–60, 61–90, más de 90 días) | Gestión de cobro y bloqueo de crédito |

---

## 5. Criterio de cierre

- [x] Contexto de la empresa definido
- [x] Dolores identificados
- [x] Impacto estimado por dolor
- [x] Cada dolor tiene su fila completa en la matriz de trazabilidad

**Siguiente fase:** Fase 1 · Preguntar → `01_definicion_negocio.md`
