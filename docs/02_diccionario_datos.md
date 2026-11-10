# Fase 2 · Preparar: diccionario de datos

**Proyecto 1:** Inteligencia comercial y análisis de ventas
**Empresa:** Distribuidora Caribe Mayorista S.A.S. *(empresa ficticia; datos sintéticos)*
**Estado de la fase:** ✅ Cerrada (versión Microsoft) · ⏳ Pendiente (versión Google)

> Viene de: [Fase 1 · Definición del negocio](01_definicion_negocio.md)

---

## 1. Mapa de fuentes

| Fuente | Sistema simulado | Responsable | Tablas / archivos | Frecuencia |
|---|---|---|---|---|
| Base de datos | Sistema de facturación (ERP) | Área de sistemas | `zonas`, `vendedores`, `clientes`, `productos`, `facturas`, `detalle_factura`, `pagos` | Automática (diaria) |
| Hoja de cálculo | `metas_comerciales.xlsx` | Jefe comercial | Hojas `Metas 2024`, `Metas 2025`, `Metas 2026` | Manual (anual, con ajustes) |

**Llave de integración entre fuentes:** `vendedores.codigo_vendedor` ↔ columna de código de vendedor del Excel.

---

## 2. Arquitectura de la base de datos

**Base de datos:** `DistribuidoraCaribe` (SQL Server)

| Esquema | Contenido | Fase |
|---|---|---|
| `crudo` | Datos tal como llegan de la fuente, todos como texto | 2 · Preparar |
| `limpio` | Datos tipificados y depurados | 3 · Procesar |
| `modelo` | Modelo estrella para el análisis | 4 · Analizar |

**Relaciones:**

```
zonas ──< vendedores ──< facturas >── clientes >── zonas
                            │
              ┌─────────────┴─────────────┐
     detalle_factura >── productos      pagos
```
*(`──<` = uno a muchos)*

---

## 3. Carga inicial (esquema `crudo`)

| Tabla | Archivo fuente | Filas cargadas | Fecha de carga |
|---|---|---|---|
| zonas | zonas.csv | 5 | 10-nov-2026 |
| vendedores | vendedores.csv | 13 | 10-nov-2026 |
| clientes | clientes.csv | 608 | 10-nov-2026 |
| productos | productos.csv | 250 | 10-nov-2026 |
| facturas | facturas.csv | 33.258 | 10-nov-2026 |
| detalle_factura | detalle_factura.csv | 143.047 | 10-nov-2026 |
| pagos | pagos.csv | 39.199 | 10-nov-2026 |

Script: [`01_crear_base_carga_cruda.sql`](../microsoft/sql-server/01_crear_base_carga_cruda.sql)

---

## 4. Diccionario por tabla

**Convenciones:** PK = llave primaria · FK = llave foránea · El *tipo esperado* es el que tendrá la columna en el esquema `limpio`.

### `zonas`: zonas comerciales

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_zona | INT | PK | Identificador de la zona | 1 |
| nombre_zona | NVARCHAR(50) | | Departamento que cubre la zona | Atlántico |

### `vendedores`: equipo comercial

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_vendedor | INT | PK | Identificador interno | 4 |
| codigo_vendedor | NVARCHAR(10) | | Código de negocio; se usa para unir con el Excel de metas | V004 |
| nombre_vendedor | NVARCHAR(100) | | Nombre completo | — |
| id_zona | INT | FK → zonas | Zona asignada (un vendedor atiende una sola zona) | 2 |
| fecha_ingreso | DATE | | Fecha de vinculación | 2019-05-01 |
| fecha_retiro | DATE | | Fecha de retiro; vacía si sigue activo | 2025-06-30 |
| estado | NVARCHAR(20) | | Activo / Retirado | Activo |

### `clientes`: clientes de la distribuidora

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_cliente | INT | PK | Identificador interno | 125 |
| nit | NVARCHAR(20) | | Identificación tributaria; debería ser única por cliente | 900123456-7 |
| nombre_cliente | NVARCHAR(150) | | Razón social o nombre comercial | Tienda La Esquina |
| tipo_cliente | NVARCHAR(30) | | Tienda de barrio / Minimercado / Supermercado / Droguería | Minimercado |
| ciudad | NVARCHAR(60) | | Municipio del cliente | Barranquilla |
| id_zona | INT | FK → zonas | Zona comercial | 1 |
| id_vendedor | INT | FK → vendedores | Vendedor asignado **actualmente** | 2 |
| condicion_pago | NVARCHAR(30) | | Contado / Crédito 30 días / Crédito 60 días | Crédito 30 días |
| cupo_credito | BIGINT | | Cupo aprobado en COP; 0 si paga de contado | 12000000 |
| fecha_creacion | DATE | | Fecha en que se creó el cliente | 2021-08-14 |

### `productos`: catálogo

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_producto | INT | PK | Identificador interno | 87 |
| codigo_producto | NVARCHAR(10) | | Código de negocio | P0087 |
| nombre_producto | NVARCHAR(200) | | Descripción, marca y presentación | Arroz blanco 1 kg … - Paca x 12 |
| categoria | NVARCHAR(30) | | Abarrotes / Bebidas / Aseo / Cuidado personal / Snacks | Bebidas |
| marca | NVARCHAR(50) | | Marca (ficticia) | Brisa |
| precio_lista | BIGINT | | Precio de lista **actual** por unidad de venta, en COP sin IVA | 64500 |

### `facturas`: encabezado de las ventas

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_factura | INT | PK | Identificador interno | 1520 |
| numero_factura | NVARCHAR(20) | | Número de factura de venta | FV-001520 |
| fecha_factura | DATE | | Fecha de emisión | 2025-03-14 |
| id_cliente | INT | FK → clientes | Cliente facturado | 125 |
| id_vendedor | INT | FK → vendedores | Vendedor que hizo la venta (**histórico**) | 4 |
| condicion_pago | NVARCHAR(30) | | Condición de pago de esa factura | Crédito 60 días |
| fecha_vencimiento | DATE | | Fecha límite de pago | 2025-05-13 |
| estado | NVARCHAR(20) | | Activa / Anulada | Activa |

### `detalle_factura`: productos de cada factura

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_detalle | INT | PK | Identificador de la línea | 9031 |
| id_factura | INT | FK → facturas | Factura a la que pertenece | 1520 |
| id_producto | INT | FK → productos | Producto vendido | 87 |
| cantidad | INT | | Unidades de venta (pacas o cajas) | 6 |
| precio_lista | BIGINT | | Precio de lista **vigente en la fecha de venta**, en COP | 61200 |
| porcentaje_descuento | DECIMAL(5,2) | | Descuento otorgado, de 0 a 100 | 5 |
| valor_descuento | BIGINT | | cantidad × precio_lista × porcentaje / 100 | 18360 |
| costo_unitario | BIGINT | | Costo por unidad en la fecha de venta, en COP | 47800 |

### `pagos`: recaudo de facturas

| Columna | Tipo esperado | Llave | Descripción | Ejemplo |
|---|---|---|---|---|
| id_pago | INT | PK | Identificador del pago | 3310 |
| id_factura | INT | FK → facturas | Factura que se abona | 1520 |
| fecha_pago | DATE | | Fecha en que se recibió el pago | 2025-05-20 |
| valor_pago | BIGINT | | Valor abonado en COP; una factura puede tener varios abonos | 350000 |
| medio_pago | NVARCHAR(30) | | Efectivo / Transferencia / Consignación / Cheque | Transferencia |

### `metas_comerciales.xlsx`: metas del área comercial

| Columna | Tipo esperado | Descripción | Ejemplo |
|---|---|---|---|
| anio | INT | Año de la meta | 2025 |
| mes | INT (1–12) | Mes de la meta | 3 |
| codigo_vendedor | NVARCHAR(10) | Código del vendedor; llave hacia `vendedores` | V004 |
| nombre_vendedor | NVARCHAR(100) | Nombre del vendedor (informativo) | — |
| zona | NVARCHAR(50) | Zona del vendedor (informativo) | Bolívar |
| meta_ventas | BIGINT | Meta de **ventas netas** del mes, en COP | 185000000 |

> Los nombres de las columnas del Excel no son iguales en todas las hojas. La estandarización se hace en la Fase 3.

---

## 5. Criterio de cierre

- [x] Mapa de fuentes documentado
- [x] Base de datos y esquemas creados
- [x] 7 tablas cargadas en `crudo` con conteo verificado
- [x] Todas las tablas y columnas descritas
- [ ] Carga en PostgreSQL y Google Sheets *(versión Google)*

**Siguiente fase:** Fase 3 · Procesar → `03_bitacora_limpieza.md`
