/* =====================================================================
   Proyecto 01 · Inteligencia comercial
   Empresa:  Distribuidora Caribe Mayorista S.A.S. (ficticia)
   Script:   03_limpieza_maestros.sql
   Fase:     3 · Procesar — Paso 7a: tablas maestras limpias

   Crea en el esquema "limpio" las tablas maestras con:
     - tipos de datos correctos
     - restricciones (PK, FK, UNIQUE, CHECK) que impiden que el error vuelva
     - las reglas de limpieza H01–H08 y H18 de la bitácora
     - la columna regla_limpieza: qué hallazgo se corrigió en cada fila

   El esquema "crudo" NO se modifica.
   Requisito: SQL Server 2017+ (TRIM, CONCAT_WS).
   ===================================================================== */
USE DistribuidoraCaribe;
GO

/* ---------------------------------------------------------------------
   0. Borrado previo (permite re-ejecutar el script)
      Se borra en orden inverso a las dependencias: primero las tablas
      que apuntan a otras (transaccionales), luego las maestras.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS limpio.pagos;
DROP TABLE IF EXISTS limpio.detalle_factura;
DROP TABLE IF EXISTS limpio.facturas;
DROP TABLE IF EXISTS limpio.clientes;
DROP TABLE IF EXISTS limpio.equivalencia_clientes;
DROP TABLE IF EXISTS limpio.homologacion_ciudades;
DROP TABLE IF EXISTS limpio.ciudades;
DROP TABLE IF EXISTS limpio.productos;
DROP TABLE IF EXISTS limpio.vendedores;
DROP TABLE IF EXISTS limpio.zonas;
GO

/* =====================================================================
   1. ZONAS (sin hallazgos: solo tipificación)
   ===================================================================== */
CREATE TABLE limpio.zonas (
    id_zona      INT          NOT NULL CONSTRAINT pk_zonas PRIMARY KEY,
    nombre_zona  NVARCHAR(50) NOT NULL CONSTRAINT uq_zonas_nombre UNIQUE
);

INSERT INTO limpio.zonas (id_zona, nombre_zona)
SELECT CAST(id_zona AS INT), TRIM(nombre_zona)
FROM crudo.zonas;
GO

/* =====================================================================
   2. VENDEDORES (sin hallazgos: solo tipificación)
   ===================================================================== */
CREATE TABLE limpio.vendedores (
    id_vendedor      INT           NOT NULL CONSTRAINT pk_vendedores PRIMARY KEY,
    codigo_vendedor  NVARCHAR(10)  NOT NULL CONSTRAINT uq_vendedores_codigo UNIQUE,
    nombre_vendedor  NVARCHAR(100) NOT NULL,
    id_zona          INT           NOT NULL CONSTRAINT fk_vendedores_zona REFERENCES limpio.zonas (id_zona),
    fecha_ingreso    DATE          NOT NULL,
    fecha_retiro     DATE          NULL,
    estado           NVARCHAR(20)  NOT NULL CONSTRAINT ck_vendedores_estado CHECK (estado IN (N'Activo', N'Retirado'))
);

INSERT INTO limpio.vendedores
SELECT
    CAST(id_vendedor AS INT),
    UPPER(TRIM(codigo_vendedor)),
    TRIM(nombre_vendedor),
    CAST(id_zona AS INT),
    CONVERT(DATE, fecha_ingreso, 23),
    TRY_CONVERT(DATE, NULLIF(TRIM(fecha_retiro), ''), 23),   -- vacío -> NULL
    TRIM(estado)
FROM crudo.vendedores;
GO

/* =====================================================================
   3. CIUDADES OFICIALES y HOMOLOGACIÓN                         (H04)
      - ciudades: la lista oficial de 25 municipios y su zona
      - homologacion_ciudades: variantes conocidas -> nombre oficial
      Las variantes de mayúsculas y espacios se resuelven solas con
      TRIM + la intercalación por defecto (no distingue mayúsculas).
   ===================================================================== */
CREATE TABLE limpio.ciudades (
    ciudad   NVARCHAR(60) NOT NULL CONSTRAINT pk_ciudades PRIMARY KEY,
    id_zona  INT          NOT NULL CONSTRAINT fk_ciudades_zona REFERENCES limpio.zonas (id_zona)
);

INSERT INTO limpio.ciudades (ciudad, id_zona) VALUES
    (N'Barranquilla', 1), (N'Soledad', 1), (N'Malambo', 1), (N'Puerto Colombia', 1), (N'Sabanalarga', 1),
    (N'Cartagena', 2), (N'Turbaco', 2), (N'Magangué', 2), (N'El Carmen de Bolívar', 2), (N'Arjona', 2),
    (N'Santa Marta', 3), (N'Ciénaga', 3), (N'Fundación', 3), (N'El Banco', 3), (N'Zona Bananera', 3),
    (N'Montería', 4), (N'Cereté', 4), (N'Lorica', 4), (N'Sahagún', 4), (N'Montelíbano', 4),
    (N'Sincelejo', 5), (N'Corozal', 5), (N'Sampués', 5), (N'San Marcos', 5), (N'Santiago de Tolú', 5);

CREATE TABLE limpio.homologacion_ciudades (
    valor_origen    NVARCHAR(60) NOT NULL CONSTRAINT pk_homologacion PRIMARY KEY,
    ciudad_oficial  NVARCHAR(60) NOT NULL CONSTRAINT fk_homologacion_ciudad REFERENCES limpio.ciudades (ciudad)
);

INSERT INTO limpio.homologacion_ciudades (valor_origen, ciudad_oficial) VALUES
    (N'B/quilla',            N'Barranquilla'),
    (N'Sta Marta',           N'Santa Marta'),
    (N'Cartagena de Indias', N'Cartagena'),
    (N'Monteria',            N'Montería'),
    (N'Magangue',            N'Magangué'),
    (N'Cienaga',             N'Ciénaga');
GO

/* =====================================================================
   4. PRODUCTOS                                        (H06, H07, H08, H18)
   ===================================================================== */
CREATE TABLE limpio.productos (
    id_producto      INT           NOT NULL CONSTRAINT pk_productos PRIMARY KEY,
    codigo_producto  NVARCHAR(10)  NOT NULL CONSTRAINT uq_productos_codigo UNIQUE,
    nombre_producto  NVARCHAR(200) NOT NULL,
    categoria        NVARCHAR(30)  NOT NULL CONSTRAINT ck_productos_categoria
                     CHECK (categoria IN (N'Abarrotes', N'Bebidas', N'Aseo', N'Cuidado personal', N'Snacks', N'No identificado')),
    marca            NVARCHAR(50)  NOT NULL,
    precio_lista     BIGINT        NULL CONSTRAINT ck_productos_precio CHECK (precio_lista > 0),
    regla_limpieza   NVARCHAR(50)  NULL
);

-- 4a. Último precio vendido de cada producto (para H07)
WITH ultimo_precio AS (
    SELECT
        d.id_producto,
        TRY_CAST(d.precio_lista AS BIGINT) AS precio,
        ROW_NUMBER() OVER (
            PARTITION BY d.id_producto
            ORDER BY TRY_CONVERT(DATE, f.fecha_factura, 23) DESC, TRY_CAST(d.id_detalle AS INT) DESC
        ) AS orden                                           -- 1 = la venta más reciente
    FROM crudo.detalle_factura d
    JOIN crudo.facturas f ON f.id_factura = d.id_factura
    WHERE TRY_CONVERT(DATE, f.fecha_factura, 23) <= '2026-10-31'
),
-- 4b. Categoría estandarizada (H08) o asignada a mano (H06)
base AS (
    SELECT
        p.*,
        CASE UPPER(TRIM(p.categoria))
            WHEN N'ABARROTES'        THEN N'Abarrotes'
            WHEN N'BEBIDAS'          THEN N'Bebidas'
            WHEN N'ASEO'             THEN N'Aseo'
            WHEN N'CUIDADO PERSONAL' THEN N'Cuidado personal'
            WHEN N'SNACKS'           THEN N'Snacks'
            ELSE CASE TRIM(p.id_producto)                    -- H06: asignación manual documentada
                     WHEN N'89'  THEN N'Bebidas'             -- Jugo de guayaba 1 L
                     WHEN N'131' THEN N'Aseo'                -- Limpiador multiusos 1 L
                     WHEN N'216' THEN N'Snacks'              -- Ponqué 30 g
                 END
        END AS categoria_limpia
    FROM crudo.productos p
)
INSERT INTO limpio.productos
SELECT
    CAST(b.id_producto AS INT),
    TRIM(b.codigo_producto),
    TRIM(b.nombre_producto),
    b.categoria_limpia,
    TRIM(b.marca),
    CASE WHEN TRY_CAST(b.precio_lista AS BIGINT) > 0
         THEN TRY_CAST(b.precio_lista AS BIGINT)
         ELSE up.precio                                       -- H07
    END,
    NULLIF(CONCAT_WS(',',
        CASE WHEN b.categoria IS NULL OR TRIM(b.categoria) = '' THEN 'H06' END,
        CASE WHEN TRY_CAST(b.precio_lista AS BIGINT) <= 0 THEN 'H07' END,
        CASE WHEN TRIM(b.categoria) <> '' AND
                  (b.categoria COLLATE Latin1_General_BIN <> b.categoria_limpia COLLATE Latin1_General_BIN
                   OR DATALENGTH(b.categoria) <> DATALENGTH(TRIM(b.categoria)))
             THEN 'H08' END
    ), '')
FROM base b
LEFT JOIN ultimo_precio up ON up.id_producto = b.id_producto AND up.orden = 1;

-- 4c. Miembro "desconocido" para ventas de productos inexistentes (H18)
INSERT INTO limpio.productos VALUES
    (0, N'P0000', N'Producto no identificado', N'No identificado', N'No identificado', NULL, 'H18');
GO

/* =====================================================================
   5. EQUIVALENCIA DE CLIENTES                                      (H02)
      Tabla puente: a qué cliente oficial corresponde cada id del sistema.
      Para los clientes originales, origen = destino.
      Para los duplicados, destino = el id más bajo con el mismo NIT.
      La usa también el script de facturas para mover su historial.
   ===================================================================== */
CREATE TABLE limpio.equivalencia_clientes (
    id_cliente_origen   INT NOT NULL CONSTRAINT pk_equivalencia PRIMARY KEY,
    id_cliente_destino  INT NOT NULL
);

INSERT INTO limpio.equivalencia_clientes (id_cliente_origen, id_cliente_destino)
SELECT
    CAST(id_cliente AS INT),
    MIN(CAST(id_cliente AS INT)) OVER (PARTITION BY TRIM(nit))   -- el id menor de ese NIT
FROM crudo.clientes;
GO

/* =====================================================================
   6. CLIENTES                                   (H01, H02, H03, H04, H05)
   ===================================================================== */
CREATE TABLE limpio.clientes (
    id_cliente      INT           NOT NULL CONSTRAINT pk_clientes PRIMARY KEY,
    nit             NVARCHAR(20)  NOT NULL CONSTRAINT uq_clientes_nit UNIQUE,      -- impide H02 en el futuro
    nombre_cliente  NVARCHAR(150) NOT NULL,
    tipo_cliente    NVARCHAR(30)  NOT NULL CONSTRAINT ck_clientes_tipo
                    CHECK (tipo_cliente IN (N'Tienda de barrio', N'Minimercado', N'Supermercado', N'Droguería')),
    ciudad          NVARCHAR(60)  NOT NULL CONSTRAINT fk_clientes_ciudad REFERENCES limpio.ciudades (ciudad),
    id_zona         INT           NOT NULL CONSTRAINT fk_clientes_zona REFERENCES limpio.zonas (id_zona),
    id_vendedor     INT           NOT NULL CONSTRAINT fk_clientes_vendedor REFERENCES limpio.vendedores (id_vendedor),
    condicion_pago  NVARCHAR(30)  NOT NULL CONSTRAINT ck_clientes_condicion
                    CHECK (condicion_pago IN (N'Contado', N'Crédito 30 días', N'Crédito 60 días')),
    cupo_credito    BIGINT        NOT NULL CONSTRAINT ck_clientes_cupo CHECK (cupo_credito >= 0),
    fecha_creacion  DATE          NOT NULL,
    regla_limpieza  NVARCHAR(50)  NULL
);

WITH base AS (
    SELECT
        c.*,
        -- H01 / H03: el tipo se deduce del prefijo del nombre
        CASE
            WHEN TRIM(c.nombre_cliente) LIKE N'Tienda%'       THEN N'Tienda de barrio'
            WHEN TRIM(c.nombre_cliente) LIKE N'Minimercado%'  THEN N'Minimercado'
            WHEN TRIM(c.nombre_cliente) LIKE N'Supermercado%' THEN N'Supermercado'
            WHEN TRIM(c.nombre_cliente) LIKE N'Droguer%'      THEN N'Droguería'
        END AS tipo_limpio,
        -- H04: primero la homologación; si no aplica, el nombre oficial que coincida
        COALESCE(h.ciudad_oficial, ci.ciudad) AS ciudad_limpia
    FROM crudo.clientes c
    LEFT JOIN limpio.homologacion_ciudades h ON h.valor_origen = TRIM(c.ciudad)
    LEFT JOIN limpio.ciudades ci             ON ci.ciudad      = TRIM(c.ciudad)
)
INSERT INTO limpio.clientes
SELECT
    CAST(b.id_cliente AS INT),
    TRIM(b.nit),
    TRIM(b.nombre_cliente),
    b.tipo_limpio,
    b.ciudad_limpia,
    CAST(b.id_zona AS INT),
    CASE WHEN CAST(b.id_vendedor AS INT) = 7 THEN 13              -- H05: V007 retirada -> V013
         ELSE CAST(b.id_vendedor AS INT) END,
    TRIM(b.condicion_pago),
    CAST(b.cupo_credito AS BIGINT),
    CONVERT(DATE, b.fecha_creacion, 23),
    NULLIF(CONCAT_WS(',',
        CASE WHEN b.tipo_cliente IS NULL OR TRIM(b.tipo_cliente) = '' THEN 'H01'
             WHEN b.tipo_cliente COLLATE Latin1_General_BIN <> b.tipo_limpio COLLATE Latin1_General_BIN THEN 'H03' END,
        CASE WHEN EXISTS (SELECT 1 FROM limpio.equivalencia_clientes e
                          WHERE e.id_cliente_destino = CAST(b.id_cliente AS INT)
                            AND e.id_cliente_origen <> e.id_cliente_destino) THEN 'H02' END,
        CASE WHEN b.ciudad COLLATE Latin1_General_BIN <> b.ciudad_limpia COLLATE Latin1_General_BIN
                  OR DATALENGTH(b.ciudad) <> DATALENGTH(TRIM(b.ciudad)) THEN 'H04' END,
        CASE WHEN CAST(b.id_vendedor AS INT) = 7 THEN 'H05' END
    ), '')
FROM base b
JOIN limpio.equivalencia_clientes e
  ON e.id_cliente_origen = CAST(b.id_cliente AS INT)
 AND e.id_cliente_origen = e.id_cliente_destino;                 -- H02: solo los originales
GO

/* =====================================================================
   7. VALIDACIÓN
   ===================================================================== */

-- 7a. Filas por tabla
--     Esperado: zonas 5 · vendedores 13 · ciudades 25 · homologacion 6
--               productos 251 · equivalencia 608 · clientes 600
SELECT 'zonas' AS tabla, COUNT(*) AS filas FROM limpio.zonas
UNION ALL SELECT 'vendedores',            COUNT(*) FROM limpio.vendedores
UNION ALL SELECT 'ciudades',              COUNT(*) FROM limpio.ciudades
UNION ALL SELECT 'homologacion_ciudades', COUNT(*) FROM limpio.homologacion_ciudades
UNION ALL SELECT 'productos',             COUNT(*) FROM limpio.productos
UNION ALL SELECT 'equivalencia_clientes', COUNT(*) FROM limpio.equivalencia_clientes
UNION ALL SELECT 'clientes',              COUNT(*) FROM limpio.clientes;

-- 7b. Clientes por tipo
--     Esperado: Tienda de barrio 325 · Minimercado 159 · Supermercado 61 · Droguería 55
SELECT tipo_cliente, COUNT(*) AS clientes
FROM limpio.clientes
GROUP BY tipo_cliente
ORDER BY clientes DESC;

-- 7c. Clientes por vendedor (V007 ya no debe aparecer; V013 = 57)
SELECT v.codigo_vendedor, v.estado, COUNT(c.id_cliente) AS clientes
FROM limpio.vendedores v
LEFT JOIN limpio.clientes c ON c.id_vendedor = v.id_vendedor
GROUP BY v.codigo_vendedor, v.estado
ORDER BY v.codigo_vendedor;

-- 7d. Productos por categoría (5 categorías + No identificado)
SELECT categoria, COUNT(*) AS productos
FROM limpio.productos
GROUP BY categoria
ORDER BY categoria;

-- 7e. Trazabilidad: filas corregidas por regla
SELECT 'clientes' AS tabla, regla_limpieza, COUNT(*) AS filas
FROM limpio.clientes WHERE regla_limpieza IS NOT NULL GROUP BY regla_limpieza
UNION ALL
SELECT 'productos', regla_limpieza, COUNT(*)
FROM limpio.productos WHERE regla_limpieza IS NOT NULL GROUP BY regla_limpieza
ORDER BY tabla, regla_limpieza;
