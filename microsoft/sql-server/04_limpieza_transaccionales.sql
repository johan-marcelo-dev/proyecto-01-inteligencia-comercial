/* =====================================================================
   Proyecto 01 · Inteligencia comercial
   Empresa:  Distribuidora Caribe Mayorista S.A.S. (ficticia)
   Script:   04_limpieza_transaccionales.sql
   Fase:     3 · Procesar — Paso 7b: tablas transaccionales limpias

   Crea en el esquema "limpio" las tablas facturas, detalle_factura y
   pagos, aplicando las reglas H09–H22 de la bitácora.

   Requisito: haber ejecutado antes 03_limpieza_maestros.sql
   (usa limpio.clientes, limpio.productos y limpio.equivalencia_clientes).

   Técnica: cada tabla se limpia con una cadena de CTE (WITH ...).
   Cada CTE resuelve un problema y le pasa el resultado a la siguiente,
   como una línea de ensamblaje. Así cada regla se lee por separado.
   ===================================================================== */
USE DistribuidoraCaribe;
GO

DROP TABLE IF EXISTS limpio.pagos;
DROP TABLE IF EXISTS limpio.detalle_factura;
DROP TABLE IF EXISTS limpio.facturas;
GO

/* =====================================================================
   1. FACTURAS                                (H02, H09, H10, H11, H12, H13)
   ===================================================================== */
CREATE TABLE limpio.facturas (
    id_factura         INT          NOT NULL CONSTRAINT pk_facturas PRIMARY KEY,
    numero_factura     NVARCHAR(20) NOT NULL CONSTRAINT uq_facturas_numero UNIQUE,
    fecha_factura      DATE         NOT NULL,
    id_cliente         INT          NOT NULL CONSTRAINT fk_facturas_cliente  REFERENCES limpio.clientes (id_cliente),
    id_vendedor        INT          NOT NULL CONSTRAINT fk_facturas_vendedor REFERENCES limpio.vendedores (id_vendedor),
    condicion_pago     NVARCHAR(30) NOT NULL CONSTRAINT ck_facturas_condicion
                       CHECK (condicion_pago IN (N'Contado', N'Crédito 30 días', N'Crédito 60 días')),
    fecha_vencimiento  DATE         NOT NULL,
    estado             NVARCHAR(20) NOT NULL CONSTRAINT ck_facturas_estado CHECK (estado IN (N'Activa', N'Anulada')),
    regla_limpieza     NVARCHAR(50) NULL,
    CONSTRAINT ck_facturas_fecha_corte  CHECK (fecha_factura <= '2026-10-31'),           -- impide H11
    CONSTRAINT ck_facturas_vencimiento  CHECK (fecha_vencimiento >= fecha_factura)       -- impide H12
);

WITH
-- 1a. H10: quitar filas duplicadas exactas
sin_duplicados AS (
    SELECT DISTINCT * FROM crudo.facturas
),
-- 1b. Tipificar fechas y deducir la condición de pago faltante por el plazo (H09)
paso_condicion AS (
    SELECT
        s.*,
        CONVERT(DATE, s.fecha_factura, 23)     AS f_factura,
        CONVERT(DATE, s.fecha_vencimiento, 23) AS f_vencimiento,
        COALESCE(
            NULLIF(TRIM(s.condicion_pago), ''),
            CASE DATEDIFF(DAY, CONVERT(DATE, s.fecha_factura, 23), CONVERT(DATE, s.fecha_vencimiento, 23))
                WHEN 0  THEN N'Contado'
                WHEN 30 THEN N'Crédito 30 días'
                WHEN 60 THEN N'Crédito 60 días'
            END
        ) AS condicion_limpia
    FROM sin_duplicados s
),
-- 1c. Plazo oficial de cada condición
paso_plazo AS (
    SELECT
        p.*,
        CASE p.condicion_limpia
            WHEN N'Contado'         THEN 0
            WHEN N'Crédito 30 días' THEN 30
            WHEN N'Crédito 60 días' THEN 60
        END AS plazo
    FROM paso_condicion p
),
-- 1d. H11: fecha posterior al corte (año mal digitado) -> vencimiento - plazo
paso_fecha AS (
    SELECT
        p.*,
        CASE WHEN p.f_factura > '2026-10-31'
             THEN DATEADD(DAY, -p.plazo, p.f_vencimiento)
             ELSE p.f_factura
        END AS fecha_limpia
    FROM paso_plazo p
)
INSERT INTO limpio.facturas
SELECT
    CAST(p.id_factura AS INT),
    TRIM(p.numero_factura),
    p.fecha_limpia,
    e.id_cliente_destino,                                          -- H02: historial al cliente oficial
    CAST(p.id_vendedor AS INT),
    p.condicion_limpia,
    CASE WHEN p.f_vencimiento < p.fecha_limpia                     -- H12: recalcular vencimiento
         THEN DATEADD(DAY, p.plazo, p.fecha_limpia)
         ELSE p.f_vencimiento
    END,
    CASE UPPER(TRIM(p.estado))                                     -- H13: estandarizar estado
        WHEN N'ACTIVA'  THEN N'Activa'
        WHEN N'ANULADA' THEN N'Anulada'
    END,
    NULLIF(CONCAT_WS(',',
        CASE WHEN e.id_cliente_destino <> e.id_cliente_origen THEN 'H02' END,
        CASE WHEN p.condicion_pago IS NULL OR TRIM(p.condicion_pago) = '' THEN 'H09' END,
        CASE WHEN p.f_factura > '2026-10-31' THEN 'H11' END,
        CASE WHEN p.f_vencimiento < p.fecha_limpia THEN 'H12' END,
        CASE WHEN p.estado COLLATE Latin1_General_BIN NOT IN (N'Activa', N'Anulada') THEN 'H13' END
    ), '')
FROM paso_fecha p
JOIN limpio.equivalencia_clientes e ON e.id_cliente_origen = CAST(p.id_cliente AS INT);
GO

/* =====================================================================
   2. DETALLE_FACTURA                              (H14, H15, H16, H17, H18)
   ===================================================================== */
CREATE TABLE limpio.detalle_factura (
    id_detalle            INT           NOT NULL CONSTRAINT pk_detalle PRIMARY KEY,
    id_factura            INT           NOT NULL CONSTRAINT fk_detalle_factura  REFERENCES limpio.facturas (id_factura),
    id_producto           INT           NOT NULL CONSTRAINT fk_detalle_producto REFERENCES limpio.productos (id_producto),
    cantidad              INT           NOT NULL CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
    precio_lista          BIGINT        NOT NULL CONSTRAINT ck_detalle_precio   CHECK (precio_lista > 0),
    porcentaje_descuento  DECIMAL(5,2)  NOT NULL CONSTRAINT ck_detalle_pct
                          CHECK (porcentaje_descuento >= 0 AND porcentaje_descuento < 100),
    valor_descuento       BIGINT        NOT NULL CONSTRAINT ck_detalle_descuento CHECK (valor_descuento >= 0),
    costo_unitario        BIGINT        NOT NULL CONSTRAINT ck_detalle_costo     CHECK (costo_unitario > 0),
    es_costo_imputado     BIT           NOT NULL,
    regla_limpieza        NVARCHAR(50)  NULL
);

WITH
-- 2a. H15: quitar filas duplicadas exactas
sin_duplicados AS (
    SELECT DISTINCT * FROM crudo.detalle_factura
),
-- 2b. Tipificar y traer la fecha de la factura (se necesita para H14)
tipado AS (
    SELECT
        CAST(s.id_detalle AS INT)                               AS id_detalle,
        CAST(s.id_factura AS INT)                               AS id_factura,
        CAST(s.id_producto AS INT)                              AS id_producto_origen,
        CAST(s.cantidad AS INT)                                 AS cantidad_origen,
        CAST(s.precio_lista AS BIGINT)                          AS precio_lista,
        CAST(s.porcentaje_descuento AS DECIMAL(6,2))            AS pct_origen,
        CAST(s.valor_descuento AS BIGINT)                       AS valor_descuento,
        TRY_CAST(NULLIF(TRIM(s.costo_unitario), '') AS BIGINT)  AS costo_origen,
        f.fecha_factura
    FROM sin_duplicados s
    JOIN limpio.facturas f ON f.id_factura = CAST(s.id_factura AS INT)
),
-- 2c. H17: porcentaje digitado x10 (100 -> 10, 150 -> 15)
paso_pct AS (
    SELECT
        t.*,
        CASE WHEN t.pct_origen >= 100 THEN t.pct_origen / 10 ELSE t.pct_origen END AS pct_limpio
    FROM tipado t
),
-- 2d. H16: recuperar la cantidad · H14: imputar el costo
paso_cantidad_costo AS (
    SELECT
        p.*,
        CASE
            WHEN p.cantidad_origen > 0 THEN p.cantidad_origen
            -- con descuento: el valor del descuento conserva la cantidad original
            WHEN p.pct_limpio > 0 AND p.valor_descuento > 0
                THEN CAST(ROUND(p.valor_descuento / (p.precio_lista * p.pct_limpio / 100.0), 0) AS INT)
            -- negativa sin descuento: error de signo
            WHEN p.cantidad_origen < 0 THEN ABS(p.cantidad_origen)
            -- cero sin descuento: no se puede recuperar -> NULL (se excluye abajo)
        END AS cantidad_limpia,
        COALESCE(
            p.costo_origen,
            -- promedio del mismo producto en el mismo mes
            CAST(ROUND(AVG(CAST(p.costo_origen AS DECIMAL(18,2)))
                 OVER (PARTITION BY p.id_producto_origen, YEAR(p.fecha_factura), MONTH(p.fecha_factura)), 0) AS BIGINT),
            -- respaldo: promedio del producto en todo el periodo
            CAST(ROUND(AVG(CAST(p.costo_origen AS DECIMAL(18,2)))
                 OVER (PARTITION BY p.id_producto_origen), 0) AS BIGINT)
        ) AS costo_limpio
    FROM paso_pct p
)
INSERT INTO limpio.detalle_factura
SELECT
    x.id_detalle,
    x.id_factura,
    CASE WHEN pr.id_producto IS NULL THEN 0 ELSE x.id_producto_origen END,   -- H18: producto no identificado
    x.cantidad_limpia,
    x.precio_lista,
    x.pct_limpio,
    x.valor_descuento,
    x.costo_limpio,
    CASE WHEN x.costo_origen IS NULL THEN 1 ELSE 0 END,
    NULLIF(CONCAT_WS(',',
        CASE WHEN x.costo_origen IS NULL     THEN 'H14' END,
        CASE WHEN x.cantidad_origen <= 0     THEN 'H16' END,
        CASE WHEN x.pct_origen >= 100        THEN 'H17' END,
        CASE WHEN pr.id_producto IS NULL     THEN 'H18' END
    ), '')
FROM paso_cantidad_costo x
LEFT JOIN limpio.productos pr ON pr.id_producto = x.id_producto_origen
WHERE x.cantidad_limpia IS NOT NULL;                                          -- H16: excluye la no recuperable
GO

/* =====================================================================
   3. PAGOS                                             (H19, H20, H21, H22)
   ===================================================================== */
CREATE TABLE limpio.pagos (
    id_pago         INT          NOT NULL CONSTRAINT pk_pagos PRIMARY KEY,
    id_factura      INT          NOT NULL CONSTRAINT fk_pagos_factura REFERENCES limpio.facturas (id_factura),
    fecha_pago      DATE         NOT NULL,
    valor_pago      BIGINT       NOT NULL CONSTRAINT ck_pagos_valor CHECK (valor_pago > 0),
    medio_pago      NVARCHAR(30) NOT NULL,
    regla_limpieza  NVARCHAR(50) NULL
);

WITH tipado AS (
    SELECT
        CAST(p.id_pago AS INT)            AS id_pago,
        CAST(p.id_factura AS INT)         AS id_factura,
        CONVERT(DATE, p.fecha_pago, 23)   AS fecha_pago,
        CAST(p.valor_pago AS BIGINT)      AS valor_origen,
        TRIM(p.medio_pago)                AS medio_pago,
        -- H20: numera los pagos idénticos; 1 = el de id_pago menor
        ROW_NUMBER() OVER (
            PARTITION BY p.id_factura, p.fecha_pago, p.valor_pago, p.medio_pago
            ORDER BY CAST(p.id_pago AS INT)
        ) AS repeticion
    FROM crudo.pagos p
)
INSERT INTO limpio.pagos
SELECT
    t.id_pago,
    t.id_factura,
    t.fecha_pago,
    ABS(t.valor_origen),                                             -- H19: error de signo
    t.medio_pago,
    NULLIF(CONCAT_WS(',',
        CASE WHEN t.valor_origen < 0             THEN 'H19' END,
        CASE WHEN t.fecha_pago < f.fecha_factura THEN 'H22' END       -- se marca, no se corrige
    ), '')
FROM tipado t
JOIN limpio.facturas f ON f.id_factura = t.id_factura                  -- H21: los huérfanos quedan fuera
WHERE t.repeticion = 1;                                                -- H20: solo el primer registro
GO

/* =====================================================================
   4. VALIDACIÓN
   ===================================================================== */

-- 4a. Conciliación de filas: crudo vs limpio
--     Esperado: facturas 33.258 -> 33.078 · detalle 143.047 -> 142.646 · pagos 39.199 -> 39.154
SELECT 'facturas' AS tabla,
       (SELECT COUNT(*) FROM crudo.facturas)  AS filas_crudo,
       (SELECT COUNT(*) FROM limpio.facturas) AS filas_limpio
UNION ALL
SELECT 'detalle_factura',
       (SELECT COUNT(*) FROM crudo.detalle_factura),
       (SELECT COUNT(*) FROM limpio.detalle_factura)
UNION ALL
SELECT 'pagos',
       (SELECT COUNT(*) FROM crudo.pagos),
       (SELECT COUNT(*) FROM limpio.pagos);

-- 4b. Filas corregidas por hallazgo (una fila puede tener varios)
--     Esperado: H02 108 · H09 15 · H11 3 · H12 20 · H13 1.323
--               H14 30 · H16 24 · H17 8 · H18 12 · H19 5 · H22 10
SELECT hallazgo, tabla, COUNT(*) AS filas
FROM (
    SELECT 'facturas' AS tabla, TRIM(value) AS hallazgo
    FROM limpio.facturas CROSS APPLY STRING_SPLIT(regla_limpieza, ',')
    UNION ALL
    SELECT 'detalle_factura', TRIM(value)
    FROM limpio.detalle_factura CROSS APPLY STRING_SPLIT(regla_limpieza, ',')
    UNION ALL
    SELECT 'pagos', TRIM(value)
    FROM limpio.pagos CROSS APPLY STRING_SPLIT(regla_limpieza, ',')
) AS r
GROUP BY hallazgo, tabla
ORDER BY hallazgo;

-- 4c. Comprobación final: ya no deben existir los errores
--     Esperado: todo en 0
SELECT
    (SELECT COUNT(*) FROM limpio.facturas WHERE fecha_factura > '2026-10-31')           AS facturas_despues_corte,
    (SELECT COUNT(*) FROM limpio.facturas WHERE fecha_vencimiento < fecha_factura)      AS vencimientos_imposibles,
    (SELECT COUNT(*) FROM limpio.detalle_factura WHERE cantidad <= 0)                   AS cantidades_invalidas,
    (SELECT COUNT(*) FROM limpio.detalle_factura
      WHERE ABS(cantidad * precio_lista * porcentaje_descuento / 100 - valor_descuento) > 1) AS descuentos_que_no_cuadran,
    (SELECT COUNT(*) FROM limpio.pagos WHERE valor_pago <= 0)                           AS pagos_invalidos;
