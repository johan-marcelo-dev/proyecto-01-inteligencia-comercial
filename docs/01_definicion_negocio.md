# Fase 1 · Preguntar: definición del negocio

**Proyecto 1:** Inteligencia comercial y análisis de ventas
**Empresa:** Distribuidora Caribe Mayorista S.A.S. *(empresa ficticia; datos sintéticos)*
**Fecha de corte del análisis:** 31 de octubre de 2026
**Estado de la fase:** ✅ Cerrada

> Viene de: [Fase 0 · Diagnóstico](00_diagnostico_dolores.md)

---

## 1. Preguntas de negocio

| # | Dolor | Pregunta |
|---|---|---|
| P1 | Información dispersa | ¿Cómo evolucionan cada mes las **ventas netas** por zona y categoría entre enero de 2024 y octubre de 2026, y cómo se comparan contra el mismo mes del año anterior? |
| P2 | Margen en caída | ¿Qué zonas, categorías y clientes tienen un **margen bruto por debajo del objetivo del 20 %**, y qué parte de esa diferencia explican los descuentos? |
| P3 | Clientes perdidos | ¿Cuántos clientes activos en los últimos 12 meses llevan **más de 60 días sin comprar**, y cuántas ventas anuales representaban? |
| P4 | Metas tardías | ¿Qué vendedores y zonas están **por debajo del 90 % de su meta acumulada**, y desde hace cuántos meses? |
| P5 | Cartera vencida | ¿Qué clientes concentran la **cartera vencida a más de 60 días**, y cuál es el DSO por zona? |

**Umbrales de política (definidos por la gerencia):** margen objetivo del 20 % · cliente inactivo después de 60 días sin comprar · cumplimiento mínimo de meta del 90 %.

---

## 2. Definición de KPIs

| # | KPI | Fórmula | Unidad | Semáforo | Responde |
|---|---|---|---|---|---|
| K1 | Ventas brutas | Σ(cantidad × precio de lista) | COP | — | P1 |
| K2 | Descuentos | Σ valor del descuento | COP | — | P1, P2 |
| K3 | **Ventas netas** | K1 − K2 | COP | — | P1 |
| K4 | Variación anual | (K3 del período − K3 del mismo período del año anterior) / K3 del año anterior | % | 🟢 ≥ 0 · 🔴 < 0 | P1 |
| K5 | **Margen bruto %** | (K3 − costo) / K3 | % | 🟢 ≥ 20 · 🟡 18–20 · 🔴 < 18 | P2 |
| K6 | Descuento % | K2 / K1 | % | 🟢 ≤ 5 · 🟡 5–8 · 🔴 > 8 | P2 |
| K7 | Clientes activos | Clientes distintos con al menos 1 compra en los 12 meses anteriores al corte | N.º | — | P3 |
| K8 | **% de clientes inactivos** | Clientes de K7 con última compra hace más de 60 días / K7 | % | 🟢 < 10 · 🟡 10–15 · 🔴 > 15 | P3 |
| K9 | Ventas en riesgo | Σ ventas netas de los últimos 12 meses de los clientes inactivos | COP | — | P3 |
| K10 | **% de cumplimiento de meta** | K3 / meta (mensual y acumulado del año) | % | 🟢 ≥ 100 · 🟡 90–99 · 🔴 < 90 | P4 |
| K11 | **Cartera vencida %** | Saldo de facturas no pagadas con más de 60 días de vencidas / saldo total de cartera | % | 🟢 < 10 · 🟡 10–20 · 🔴 > 20 | P5 |
| K12 | DSO (días de cartera) | Saldo de cartera al corte / ventas netas a crédito de los últimos 90 días × 90 | Días | 🟢 ≤ 45 · 🟡 46–60 · 🔴 > 60 | P5 |

**Reglas generales de cálculo**
- Se excluyen las facturas anuladas de todos los KPIs.
- El costo usado es el registrado en cada línea de venta.
- K11 y K12 consideran solo las facturas a crédito.

---

## 3. Alcance

| ✅ Incluye | ❌ No incluye |
|---|---|
| Ventas, márgenes y descuentos | Devoluciones |
| Clientes y recompra | Inventario y abastecimiento *(Proyecto 3)* |
| Metas comerciales | Fletes y logística |
| Cartera y recaudo | Pronósticos de ventas |
| 5 zonas · enero 2024 a octubre 2026 | Actualización en tiempo real |
| Versión Microsoft y versión Google | — |

---

## 4. Supuestos

| # | Supuesto |
|---|---|
| S1 | Valores en pesos colombianos (COP), **sin IVA** |
| S2 | El costo unitario se registra en cada línea de venta (costo vigente en la fecha) |
| S3 | Cada vendedor atiende una sola zona y cada cliente tiene un vendedor asignado |
| S4 | Las metas son mensuales por vendedor y provienen del Excel del área comercial |
| S5 | Una factura se puede pagar en uno o varios abonos |
| S6 | Datos sintéticos generados para el caso; empresa ficticia |

---

## 5. Usuarios del dashboard

| Usuario | Necesidad principal |
|---|---|
| Gerente general | Visión ejecutiva: ventas, margen y tendencia |
| Jefe comercial | Vendedores, metas y clientes en riesgo |
| Cartera / tesorería | Quién debe, cuánto y con qué antigüedad |

---

## 6. Criterio de cierre

- [x] Preguntas de negocio medibles definidas
- [x] KPIs con fórmula, unidad y semáforo
- [x] Alcance definido
- [x] Supuestos documentados
- [x] Usuarios identificados

**Siguiente fase:** Fase 2 · Preparar → `02_diccionario_datos.md`
