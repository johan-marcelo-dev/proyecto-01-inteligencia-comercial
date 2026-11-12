# Fase 3 · Procesar: bitácora de calidad y limpieza

**Proyecto 1:** Inteligencia comercial y análisis de ventas
**Empresa:** Distribuidora Caribe Mayorista S.A.S. *(empresa ficticia; datos sintéticos)*
**Estado de la fase:** ✅ Cerrada (versión Microsoft) · ⏳ Pendiente (versión Google)

> Viene de: [Fase 2 · Diccionario de datos](02_diccionario_datos.md)

---

## 1. Marco de evaluación

La calidad se evaluó en **5 dimensiones** sobre las 8 fuentes:

| Dimensión | Pregunta | Técnica principal |
|---|---|---|
| Completitud | ¿Faltan datos? | `SUM(CASE WHEN col IS NULL OR TRIM(col) = '' …)` |
| Unicidad | ¿Hay registros repetidos? | `COUNT(DISTINCT)` · `GROUP BY … HAVING COUNT(*) > 1` |
| Validez | ¿El tipo y el rango son correctos? | `TRY_CAST` · `TRY_CONVERT` · reglas de negocio |
| Consistencia | ¿El mismo dato se escribe igual? | `GROUP BY` con `COLLATE Latin1_General_BIN` · `DATALENGTH` |
| Integridad referencial | ¿Las llaves apuntan a registros existentes? | `LEFT JOIN … WHERE derecha IS NULL` |

**Herramientas:** SQL Server (7 tablas, esquema `crudo`) · Power Query en Excel (metas comerciales).
**Scripts:**
- Perfilamiento: [`02_perfilamiento_calidad.sql`](../microsoft/sql-server/02_perfilamiento_calidad.sql)
- Limpieza de maestras: [`03_limpieza_maestros.sql`](../microsoft/sql-server/03_limpieza_maestros.sql)
- Limpieza de transaccionales: [`04_limpieza_transaccionales.sql`](../microsoft/sql-server/04_limpieza_transaccionales.sql)
- Limpieza del Excel de metas (Power Query): [`metas_limpias.pq`](../microsoft/excel/metas_limpias.pq)

---

## 2. Resumen del perfilamiento

| Fuente | Filas | Completitud | Unicidad | Validez | Consistencia | Integridad | Hallazgos |
|---|---|---|---|---|---|---|---|
| clientes | 608 | ⚠️ | ⚠️ | ✅ | ⚠️ | ⚠️ | 5 |
| productos | 250 | ⚠️ | ✅ | ⚠️ | ⚠️ | — | 3 |
| vendedores | 13 | ✅ | ✅ | ✅ | ✅ | ✅ | 0 |
| zonas | 5 | ✅ | ✅ | ✅ | ✅ | — | 0 |
| facturas | 33.258 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | 5 |
| detalle_factura | 143.047 | ⚠️ | ⚠️ | ⚠️ | — | ⚠️ | 5 |
| pagos | 39.199 | ✅ | ⚠️ | ⚠️ | — | ⚠️ | 4 |
| metas_comerciales.xlsx | 434 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | 8 |
| **Total** | | | | | | | **30** |

✅ sin hallazgos · ⚠️ con hallazgos · — no aplica

---

## 3. Hallazgos y reglas de limpieza

**Principios aplicados:**
1. El esquema `crudo` nunca se modifica; las correcciones se materializan en `limpio`.
2. Recuperar es mejor que eliminar: si un dato se puede deducir de otro, se deduce.
3. Ninguna fila se elimina sin quedar registrada en esta bitácora.
4. Lo que no se puede recuperar se reporta al dueño del dato; no se inventa.

### clientes

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H01 | Completitud | `tipo_cliente` vacío | 7 | Recuperar | Deducir del prefijo del nombre del cliente |
| H02 | Unicidad | Mismo NIT en dos `id_cliente` (los ID 601 a 608 son duplicados) | 8 pares | Unificar | Conservar el ID menor; reasignar sus facturas al original |
| H03 | Consistencia | Variantes de `tipo_cliente`: `TIENDA`, `Mini mercado` | 5 | Recuperar | Igual que H01 |
| H04 | Consistencia | Variantes de `ciudad`: abreviaturas, sin tilde, mayúsculas, espacios | 37 | Estandarizar | `TRIM` + tabla de homologación de ciudades |
| H05 | Integridad | Clientes asignados a V007, retirada el 30-jun-2025 | 58 | Corregir | Reasignar a V013, su reemplazo en Magdalena *(supuesto documentado)* |

### productos

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H06 | Completitud | `categoria` vacía | 3 | Recuperar | Asignación manual según el nombre del producto |
| H07 | Validez | `precio_lista` = 0 (productos 34 y 214) | 2 | Recuperar | Último precio registrado en `detalle_factura` |
| H08 | Consistencia | Variantes de `categoria`: mayúsculas y espacios | 8 | Estandarizar | `TRIM` + mapeo al nombre oficial |

### facturas

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H09 | Completitud | `condicion_pago` vacía | 15 | Recuperar | Deducir por el plazo: 0 → Contado · 30 → Crédito 30 días · 60 → Crédito 60 días |
| H10 | Unicidad | Filas duplicadas exactas | 180 | Eliminar | Conservar una sola fila |
| H11 | Validez | `fecha_factura` en 2027 (error en el año) | 3 | Recuperar | Fecha de factura = vencimiento − plazo de la condición |
| H12 | Validez | Vencimiento 30 días antes de la emisión | 20 | Recalcular | Vencimiento = fecha de factura + plazo de la condición |
| H13 | Consistencia | `estado` con mayúsculas y minúsculas mezcladas | 1.334 | Estandarizar | Valores oficiales: Activa / Anulada |

### detalle_factura

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H14 | Completitud | `costo_unitario` vacío | 30 | Imputar y marcar | Costo promedio del mismo producto en el mismo mes · `es_imputado = 1` |
| H15 | Unicidad | Filas duplicadas | 400 | Eliminar | Conservar una sola fila |
| H16 | Validez | Cantidad negativa (15) o en cero (10) | 25 | Recuperar | Con descuento: cantidad = valor descuento ÷ (precio × % / 100). Negativa sin descuento: valor absoluto. Cero sin descuento: excluir |
| H17 | Validez | Porcentaje ×10 (100 en vez de 10, 150 en vez de 15) | 8 | Corregir | Dividir entre 10, validado contra `valor_descuento` |
| H18 | Integridad | `id_producto` = 9999, que no existe | 12 | Conservar | Asignar a "Producto no identificado" (id 0) |

### pagos

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H19 | Validez | `valor_pago` negativo | 5 | Corregir | Valor absoluto (error de signo) |
| H20 | Unicidad | Mismo pago registrado dos veces con distinto `id_pago` | 30 | Eliminar | Conservar el `id_pago` menor |
| H21 | Integridad | Pagos de facturas inexistentes | 15 | Excluir y reportar | No se pueden asignar |
| H22 | Validez | Pago anterior a la factura (10 propios + 3 explicados por H11) | 13 | Conservar y marcar | Los 3 se resuelven con H11; los 10 se marcan, sin efecto en el saldo al corte |

### metas_comerciales.xlsx

| ID | Dimensión | Hallazgo | Filas | Acción | Regla |
|---|---|---|---|---|---|
| H23 | Consistencia | Encabezados distintos en 2026 (`Cod. Vendedor`, `Meta ($)`) | 2 col. | Estandarizar | Renombrar a `codigo_vendedor`, `meta_ventas` |
| H24 | Consistencia | Mes como texto en 2024 y como número en 2025-2026 | 1 hoja | Estandarizar | Convertir el nombre del mes a número |
| H25 | Consistencia | Códigos con minúscula, espacio o guion | ~15 | Estandarizar | `TRIM` + mayúsculas + quitar el guion |
| H26 | Validez | Metas escritas como texto en 2025 | 4 | Corregir | Quitar los separadores y convertir a número |
| H27 | Completitud | Meta vacía en 2026 | 1 | Consultar | Excluir del % de cumplimiento; reportar al jefe comercial |
| H28 | Unicidad | Fila duplicada en 2025 | 1 | Eliminar | Conservar una sola fila |
| H29 | Integridad | Meta de V007 en agosto de 2025, después de su retiro | 1 | Excluir | La vendedora ya no estaba en la empresa |
| H30 | Alcance | Metas de noviembre y diciembre de 2026, posteriores al corte | 24 | Filtrar | Solo meses ≤ fecha de corte |

---

## 4. Lecciones aprendidas

| # | Lección | Hallazgos relacionados |
|---|---|---|
| L1 | `COUNT(columna)` excluye los nulos, pero cuenta los textos vacíos. Hay que revisar ambos. | H01 |
| L2 | La intercalación por defecto de SQL Server no distingue mayúsculas e ignora los espacios finales: un `GROUP BY` normal **esconde** variantes. Se usa `COLLATE Latin1_General_BIN` y `DATALENGTH`. | H04, H08 |
| L3 | En el esquema `crudo` todo es texto: los números se ordenan como texto (1, 10, 11, 2…). Por eso hay que tipificar. | — |
| L4 | `BETWEEN 0 AND 100` deja pasar un descuento del 100 %, que es válido técnicamente pero absurdo para el negocio. | H17 |
| L5 | Una validación puede "cuadrar por coincidencia" cuando hay ceros. | H16 |
| L6 | Un hallazgo puede explicar otro: los 23 vencimientos imposibles son en realidad 2 problemas. | H11, H12, H22 |
| L7 | El paso automático **"Tipo cambiado"** de Power Query convierte en silencio y esconde errores. Al perfilar se elimina y se desactiva la detección automática de tipos. | H26 |
| L8 | Un dato puede ser correcto pero quedar **fuera del alcance** (metas posteriores al corte). Solo el criterio de negocio lo detecta. | H30 |

---

## 5. Resultado de la limpieza

### 5.1 Conciliación de filas

| Fuente | Crudo | Limpio | Diferencia | Explicación |
|---|---|---|---|---|
| zonas | 5 | 5 | 0 | — |
| vendedores | 13 | 13 | 0 | — |
| clientes | 608 | 600 | −8 | H02: duplicados unificados con su cliente original |
| productos | 250 | 251 | +1 | H18: se agrega "Producto no identificado" (id 0) |
| facturas | 33.258 | 33.078 | −180 | H10: duplicados exactos |
| detalle_factura | 143.047 | 142.646 | −401 | H15: 400 duplicados · H16: 1 línea en cero sin descuento, no recuperable |
| pagos | 39.199 | 39.154 | −45 | H20: 30 pagos repetidos · H21: 15 pagos sin factura |
| metas (Excel) | 434 | 408 | −26 | H28: 1 duplicada · H29: 1 de V007 · H30: 24 posteriores al corte |

**Tablas de apoyo creadas:** `ciudades` (25) · `homologacion_ciudades` (6) · `equivalencia_clientes` (608).

### 5.2 Filas corregidas por hallazgo

Cada fila corregida guarda en la columna `regla_limpieza` los hallazgos que se le aplicaron.

| Tabla | Hallazgos corregidos (filas) |
|---|---|
| clientes | H01: 7 · H02: 8 · H03: 5 · H04: 35 · H05: 57 |
| productos | H06: 3 · H07: 2 · H08: 8 · H18: 1 |
| facturas | H02: 108 (facturas trasladadas al cliente original) · H09: 15 · H11: 3 · H12: 20 · H13: 1.323 |
| detalle_factura | H14: 30 · H16: 24 · H17: 8 · H18: 12 |
| pagos | H19: 5 · H22: 10 (marcados) |
| metas (Excel) | H23 a H27: estandarizadas en Power Query · H27: 1 meta marcada como faltante |

> Las diferencias con el perfilamiento se explican porque algunas filas con error eran duplicados y se eliminaron primero (por ejemplo, H13: 1.334 en el perfilamiento → 1.323 corregidas).

### 5.3 Validación final

| Comprobación en `limpio` | Resultado |
|---|---|
| Facturas posteriores a la fecha de corte | 0 |
| Vencimientos anteriores a la emisión | 0 |
| Cantidades menores o iguales a cero | 0 |
| Descuentos que no cuadran con cantidad × precio × % | 0 |
| Pagos con valor menor o igual a cero | 0 |
| Clientes asignados a vendedores retirados | 0 |

**Restricciones que impiden que los errores vuelvan a entrar:** llaves primarias y foráneas en todas las tablas, `UNIQUE` en el NIT, el código de vendedor y el número de factura, y `CHECK` en categorías, tipos de cliente, condiciones de pago, estados, fechas, cantidades, porcentajes y valores.

## 6. Criterio de cierre

- [x] Las 8 fuentes perfiladas en las 5 dimensiones
- [x] Cada hallazgo con su regla de limpieza
- [x] Reglas ejecutadas en el esquema `limpio` y en Power Query
- [x] Conteos antes/después validados
- [ ] Limpieza en PostgreSQL y Google Sheets *(versión Google)*

**Siguiente fase:** Fase 4 · Analizar → `04_analisis.md`
