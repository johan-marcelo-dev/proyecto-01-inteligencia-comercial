/* =====================================================================
   Proyecto 01 · Inteligencia comercial
   Empresa:  Distribuidora Caribe Mayorista S.A.S. (ficticia)
   Script:   02_perfilamiento_calidad.sql
   Fase:     3 · Procesar — Perfilamiento de calidad de datos

   Objetivo: Evaluar la calidad de las 7 tablas del esquema "crudo" en
             5 dimensiones: completitud, unicidad, validez, consistencia
             e integridad referencial.

   Resultado: 22 hallazgos en SQL Server (H01–H22). El detalle y las
              reglas de limpieza están en docs/03_bitacora_limpieza.md
   ===================================================================== */
USE DistribuidoraCaribe;
GO

/* #####################################################################
   CLIENTES
   ##################################################################### */

-- C1. Completitud: valores nulos o vacíos por columna         -> H01
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN id_cliente     IS NULL OR TRIM(id_cliente)     = '' THEN 1 ELSE 0 END) AS faltan_id_cliente,
    SUM(CASE WHEN nit            IS NULL OR TRIM(nit)            = '' THEN 1 ELSE 0 END) AS faltan_nit,
    SUM(CASE WHEN nombre_cliente IS NULL OR TRIM(nombre_cliente) = '' THEN 1 ELSE 0 END) AS faltan_nombre,
    SUM(CASE WHEN tipo_cliente   IS NULL OR TRIM(tipo_cliente)   = '' THEN 1 ELSE 0 END) AS faltan_tipo,
    SUM(CASE WHEN ciudad         IS NULL OR TRIM(ciudad)         = '' THEN 1 ELSE 0 END) AS faltan_ciudad,
    SUM(CASE WHEN id_zona        IS NULL OR TRIM(id_zona)        = '' THEN 1 ELSE 0 END) AS faltan_zona,
    SUM(CASE WHEN id_vendedor    IS NULL OR TRIM(id_vendedor)    = '' THEN 1 ELSE 0 END) AS faltan_vendedor,
    SUM(CASE WHEN condicion_pago IS NULL OR TRIM(condicion_pago) = '' THEN 1 ELSE 0 END) AS faltan_condicion,
    SUM(CASE WHEN cupo_credito   IS NULL OR TRIM(cupo_credito)   = '' THEN 1 ELSE 0 END) AS faltan_cupo,
    SUM(CASE WHEN fecha_creacion IS NULL OR TRIM(fecha_creacion) = '' THEN 1 ELSE 0 END) AS faltan_fecha
FROM crudo.clientes;

-- C2a. Unicidad de la llave técnica
SELECT COUNT(*) AS total_filas, COUNT(DISTINCT id_cliente) AS ids_distintos
FROM crudo.clientes;

-- C2b. Unicidad de la llave de negocio (NIT)                  -> H02
SELECT nit, COUNT(*) AS veces
FROM crudo.clientes
GROUP BY nit
HAVING COUNT(*) > 1
ORDER BY veces DESC;

-- C2c. Registros completos de los NIT repetidos
SELECT *
FROM crudo.clientes
WHERE nit IN (SELECT nit FROM crudo.clientes GROUP BY nit HAVING COUNT(*) > 1)
ORDER BY nit, id_cliente;

-- C3. Validez técnica y de negocio                            -> sin hallazgos (V01)
SELECT
    SUM(CASE WHEN TRY_CAST(id_cliente   AS INT)    IS NULL THEN 1 ELSE 0 END) AS id_no_numerico,
    SUM(CASE WHEN TRY_CAST(id_zona      AS INT)    IS NULL THEN 1 ELSE 0 END) AS zona_no_numerica,
    SUM(CASE WHEN TRY_CAST(id_vendedor  AS INT)    IS NULL THEN 1 ELSE 0 END) AS vendedor_no_numerico,
    SUM(CASE WHEN TRY_CAST(cupo_credito AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS cupo_no_numerico,
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_creacion, 23) IS NULL THEN 1 ELSE 0 END) AS fecha_invalida,
    SUM(CASE WHEN nit NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]'
             THEN 1 ELSE 0 END) AS nit_formato_invalido,
    SUM(CASE WHEN TRY_CAST(cupo_credito AS BIGINT) < 0 THEN 1 ELSE 0 END) AS cupo_negativo,
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_creacion, 23) > '2026-10-31' THEN 1 ELSE 0 END) AS fecha_posterior_corte,
    SUM(CASE WHEN condicion_pago = 'Contado' AND TRY_CAST(cupo_credito AS BIGINT) > 0
             THEN 1 ELSE 0 END) AS contado_con_cupo,
    SUM(CASE WHEN condicion_pago LIKE 'Crédito%' AND TRY_CAST(cupo_credito AS BIGINT) = 0
             THEN 1 ELSE 0 END) AS credito_sin_cupo
FROM crudo.clientes;

-- C4a. Consistencia de tipo_cliente                           -> H03
SELECT '[' + tipo_cliente + ']' AS tipo_cliente, COUNT(*) AS clientes
FROM crudo.clientes
GROUP BY tipo_cliente
ORDER BY tipo_cliente;

-- C4b. Consistencia de condicion_pago
SELECT '[' + condicion_pago + ']' AS condicion_pago, COUNT(*) AS clientes
FROM crudo.clientes
GROUP BY condicion_pago
ORDER BY condicion_pago;

-- C4c. Ciudades por zona (intercalación por defecto)
SELECT id_zona, '[' + ciudad + ']' AS ciudad, COUNT(*) AS clientes
FROM crudo.clientes
GROUP BY id_zona, ciudad
ORDER BY id_zona, ciudad;

-- C4d. Ciudades con distinción exacta de mayúsculas/minúsculas  -> H04
--      La intercalación por defecto agrupa 'CARTAGENA' con 'Cartagena' (lección L2)
SELECT '[' + (ciudad COLLATE Latin1_General_BIN) + ']' AS ciudad_exacta, COUNT(*) AS clientes
FROM crudo.clientes
GROUP BY ciudad COLLATE Latin1_General_BIN
ORDER BY ciudad_exacta;

-- C4e. Ciudades con espacios sobrantes                        -> H04
SELECT id_cliente, '[' + ciudad + ']' AS ciudad
FROM crudo.clientes
WHERE DATALENGTH(ciudad) <> DATALENGTH(TRIM(ciudad));

-- C5a. Integridad: zonas inexistentes
SELECT c.id_cliente, c.id_zona
FROM crudo.clientes c
LEFT JOIN crudo.zonas z ON z.id_zona = c.id_zona
WHERE z.id_zona IS NULL;

-- C5b. Integridad: vendedores inexistentes
SELECT c.id_cliente, c.id_vendedor
FROM crudo.clientes c
LEFT JOIN crudo.vendedores v ON v.id_vendedor = c.id_vendedor
WHERE v.id_vendedor IS NULL;

-- C5c. Regla de negocio: clientes asignados a vendedor retirado -> H05
SELECT v.codigo_vendedor, v.nombre_vendedor, v.estado, COUNT(*) AS clientes
FROM crudo.clientes c
JOIN crudo.vendedores v ON v.id_vendedor = c.id_vendedor
WHERE v.estado = 'Retirado'
GROUP BY v.codigo_vendedor, v.nombre_vendedor, v.estado;

-- C5d. Regla de negocio: cliente y vendedor en zonas distintas
SELECT c.id_cliente, c.id_zona AS zona_cliente, v.id_zona AS zona_vendedor
FROM crudo.clientes c
JOIN crudo.vendedores v ON v.id_vendedor = c.id_vendedor
WHERE c.id_zona <> v.id_zona;


/* #####################################################################
   PRODUCTOS
   ##################################################################### */

-- P1. Completitud                                             -> H06
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN codigo_producto IS NULL OR TRIM(codigo_producto) = '' THEN 1 ELSE 0 END) AS faltan_codigo,
    SUM(CASE WHEN nombre_producto IS NULL OR TRIM(nombre_producto) = '' THEN 1 ELSE 0 END) AS faltan_nombre,
    SUM(CASE WHEN categoria       IS NULL OR TRIM(categoria)       = '' THEN 1 ELSE 0 END) AS faltan_categoria,
    SUM(CASE WHEN marca           IS NULL OR TRIM(marca)           = '' THEN 1 ELSE 0 END) AS faltan_marca,
    SUM(CASE WHEN precio_lista    IS NULL OR TRIM(precio_lista)    = '' THEN 1 ELSE 0 END) AS faltan_precio
FROM crudo.productos;

-- P2. Unicidad de id, código y nombre                         -> sin hallazgos (V02)
SELECT
    COUNT(*)                        AS total_filas,
    COUNT(DISTINCT id_producto)     AS ids_distintos,
    COUNT(DISTINCT codigo_producto) AS codigos_distintos,
    COUNT(DISTINCT nombre_producto) AS nombres_distintos
FROM crudo.productos;

-- P3. Validez del precio                                      -> H07
SELECT
    SUM(CASE WHEN TRY_CAST(precio_lista AS BIGINT) IS NULL THEN 1 ELSE 0 END) AS precio_no_numerico,
    SUM(CASE WHEN TRY_CAST(precio_lista AS BIGINT) <= 0    THEN 1 ELSE 0 END) AS precio_cero_o_negativo
FROM crudo.productos;

-- P3b. Productos con precio en cero
SELECT id_producto, nombre_producto, precio_lista
FROM crudo.productos
WHERE TRY_CAST(precio_lista AS BIGINT) <= 0;

-- P4. Consistencia de categoría (intercalación binaria)       -> H08
SELECT '[' + (categoria COLLATE Latin1_General_BIN) + ']' AS categoria_exacta, COUNT(*) AS productos
FROM crudo.productos
GROUP BY categoria COLLATE Latin1_General_BIN
ORDER BY categoria_exacta;

-- P4b. Categorías con espacios sobrantes                      -> H08
SELECT id_producto, '[' + categoria + ']' AS categoria
FROM crudo.productos
WHERE DATALENGTH(categoria) <> DATALENGTH(TRIM(categoria));


/* #####################################################################
   VENDEDORES  (13 filas: revisión visual completa)
   ##################################################################### */

-- VE1. Revisión completa
--      Nota: se ordena como texto (1, 10, 11, 2…) porque en "crudo" todo es NVARCHAR (lección L3)
SELECT * FROM crudo.vendedores ORDER BY id_vendedor;

-- VE2. Coherencia entre estado y fecha de retiro              -> sin hallazgos (V05)
SELECT id_vendedor, codigo_vendedor, estado, fecha_retiro
FROM crudo.vendedores
WHERE (estado = 'Retirado' AND (fecha_retiro IS NULL OR fecha_retiro = ''))
   OR (estado = 'Activo'   AND fecha_retiro IS NOT NULL AND fecha_retiro <> '');


/* #####################################################################
   FACTURAS
   ##################################################################### */

-- F1. Completitud                                             -> H09
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN numero_factura    IS NULL OR TRIM(numero_factura)    = '' THEN 1 ELSE 0 END) AS faltan_numero,
    SUM(CASE WHEN fecha_factura     IS NULL OR TRIM(fecha_factura)     = '' THEN 1 ELSE 0 END) AS faltan_fecha,
    SUM(CASE WHEN id_cliente        IS NULL OR TRIM(id_cliente)        = '' THEN 1 ELSE 0 END) AS faltan_cliente,
    SUM(CASE WHEN id_vendedor       IS NULL OR TRIM(id_vendedor)       = '' THEN 1 ELSE 0 END) AS faltan_vendedor,
    SUM(CASE WHEN condicion_pago    IS NULL OR TRIM(condicion_pago)    = '' THEN 1 ELSE 0 END) AS faltan_condicion,
    SUM(CASE WHEN fecha_vencimiento IS NULL OR TRIM(fecha_vencimiento) = '' THEN 1 ELSE 0 END) AS faltan_vencimiento,
    SUM(CASE WHEN estado            IS NULL OR TRIM(estado)            = '' THEN 1 ELSE 0 END) AS faltan_estado
FROM crudo.facturas;

-- F2. Unicidad                                                -> H10
SELECT
    COUNT(*)                       AS total_filas,
    COUNT(DISTINCT id_factura)     AS ids_distintos,
    COUNT(DISTINCT numero_factura) AS numeros_distintos
FROM crudo.facturas;

-- F2b. ¿Duplicados exactos? (todas las columnas iguales)      -> H10
SELECT COUNT(*) AS grupos_duplicados, SUM(veces - 1) AS filas_sobrantes
FROM (
    SELECT id_factura, numero_factura, fecha_factura, id_cliente, id_vendedor,
           condicion_pago, fecha_vencimiento, estado, COUNT(*) AS veces
    FROM crudo.facturas
    GROUP BY id_factura, numero_factura, fecha_factura, id_cliente, id_vendedor,
             condicion_pago, fecha_vencimiento, estado
    HAVING COUNT(*) > 1
) AS d;

-- F3. Validez de fechas                                       -> H11, H12
SELECT
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_factura, 23)     IS NULL THEN 1 ELSE 0 END) AS fecha_invalida,
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_vencimiento, 23) IS NULL THEN 1 ELSE 0 END) AS vencimiento_invalido,
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_factura, 23) > '2026-10-31' THEN 1 ELSE 0 END) AS factura_posterior_corte,
    SUM(CASE WHEN TRY_CONVERT(DATE, fecha_vencimiento, 23) < TRY_CONVERT(DATE, fecha_factura, 23)
             THEN 1 ELSE 0 END) AS vence_antes_de_emitirse
FROM crudo.facturas;

-- F3b. Coherencia entre plazo y condición de pago            -> H09, H11, H12
--      Plazos -1095/-730/-335 = facturas con año 2027 (H11)
--      Plazo -30 = vencimiento mal calculado (H12)
--      Condición NULL con plazo 0/30 = condición deducible (H09)
SELECT
    condicion_pago,
    DATEDIFF(DAY, TRY_CONVERT(DATE, fecha_factura, 23),
                  TRY_CONVERT(DATE, fecha_vencimiento, 23)) AS dias_plazo,
    COUNT(*) AS facturas
FROM crudo.facturas
GROUP BY condicion_pago,
         DATEDIFF(DAY, TRY_CONVERT(DATE, fecha_factura, 23),
                       TRY_CONVERT(DATE, fecha_vencimiento, 23))
ORDER BY condicion_pago, dias_plazo;

-- F4. Consistencia del estado (intercalación binaria)        -> H13
SELECT '[' + (estado COLLATE Latin1_General_BIN) + ']' AS estado_exacto, COUNT(*) AS facturas
FROM crudo.facturas
GROUP BY estado COLLATE Latin1_General_BIN
ORDER BY estado_exacto;

-- F5. Integridad: clientes inexistentes                       -> sin hallazgos (V04)
SELECT COUNT(*) AS facturas_cliente_inexistente
FROM crudo.facturas f
LEFT JOIN crudo.clientes c ON c.id_cliente = f.id_cliente
WHERE c.id_cliente IS NULL;

-- F5b. Regla de negocio: ventas de V007 (retiro) y V013 (ingreso) -> sin hallazgos (V04)
SELECT
    v.codigo_vendedor,
    MIN(TRY_CONVERT(DATE, f.fecha_factura, 23)) AS primera_venta,
    MAX(TRY_CONVERT(DATE, f.fecha_factura, 23)) AS ultima_venta,
    COUNT(*) AS facturas
FROM crudo.facturas f
JOIN crudo.vendedores v ON v.id_vendedor = f.id_vendedor
WHERE v.codigo_vendedor IN ('V007', 'V013')
GROUP BY v.codigo_vendedor;


/* #####################################################################
   DETALLE_FACTURA
   ##################################################################### */

-- D1. Completitud                                             -> H14
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN id_producto          IS NULL OR TRIM(id_producto)          = '' THEN 1 ELSE 0 END) AS faltan_producto,
    SUM(CASE WHEN cantidad             IS NULL OR TRIM(cantidad)             = '' THEN 1 ELSE 0 END) AS faltan_cantidad,
    SUM(CASE WHEN precio_lista         IS NULL OR TRIM(precio_lista)         = '' THEN 1 ELSE 0 END) AS faltan_precio,
    SUM(CASE WHEN porcentaje_descuento IS NULL OR TRIM(porcentaje_descuento) = '' THEN 1 ELSE 0 END) AS faltan_pct,
    SUM(CASE WHEN costo_unitario       IS NULL OR TRIM(costo_unitario)       = '' THEN 1 ELSE 0 END) AS faltan_costo
FROM crudo.detalle_factura;

-- D2. Unicidad                                                -> H15
SELECT COUNT(*) AS total_filas, COUNT(DISTINCT id_detalle) AS ids_distintos
FROM crudo.detalle_factura;

-- D3. Validez de cantidades y porcentajes                     -> H16, H17
--     Nota: BETWEEN 0 AND 100 deja pasar el 100 % (lección L4)
SELECT
    SUM(CASE WHEN TRY_CAST(cantidad AS INT) < 0 THEN 1 ELSE 0 END) AS cantidad_negativa,
    SUM(CASE WHEN TRY_CAST(cantidad AS INT) = 0 THEN 1 ELSE 0 END) AS cantidad_cero,
    SUM(CASE WHEN TRY_CAST(porcentaje_descuento AS DECIMAL(6,2)) NOT BETWEEN 0 AND 100
             THEN 1 ELSE 0 END) AS pct_fuera_de_rango
FROM crudo.detalle_factura;

-- D3b. Recalcular el descuento y comparar con el registrado  -> H16, H17
--      26 = 8 porcentajes x10 + 9 negativas + 9 en cero (las demás "cuadran" por tener 0 %, lección L5)
SELECT COUNT(*) AS descuento_no_cuadra
FROM crudo.detalle_factura
WHERE ABS( TRY_CAST(cantidad AS BIGINT) * TRY_CAST(precio_lista AS BIGINT)
           * TRY_CAST(porcentaje_descuento AS DECIMAL(6,2)) / 100
         - TRY_CAST(valor_descuento AS BIGINT) ) > 1;

-- D4. Integridad: facturas y productos inexistentes          -> H18
--     DISTINCT en facturas para no duplicar conteos por H10
SELECT
    SUM(CASE WHEN f.id_factura  IS NULL THEN 1 ELSE 0 END) AS factura_inexistente,
    SUM(CASE WHEN p.id_producto IS NULL THEN 1 ELSE 0 END) AS producto_inexistente
FROM crudo.detalle_factura d
LEFT JOIN (SELECT DISTINCT id_factura FROM crudo.facturas) f ON f.id_factura  = d.id_factura
LEFT JOIN crudo.productos p                                  ON p.id_producto = d.id_producto;


/* #####################################################################
   PAGOS
   ##################################################################### */

-- PA1. Unicidad y validez del valor                           -> H19
SELECT
    COUNT(*)                AS total_filas,
    COUNT(DISTINCT id_pago) AS ids_distintos,
    SUM(CASE WHEN TRY_CAST(valor_pago AS BIGINT) <= 0 THEN 1 ELSE 0 END) AS valor_cero_o_negativo
FROM crudo.pagos;

-- PA2. Duplicados disfrazados: mismo pago con distinto id_pago -> H20
SELECT COUNT(*) AS pagos_repetidos
FROM (
    SELECT id_factura, fecha_pago, valor_pago, medio_pago
    FROM crudo.pagos
    GROUP BY id_factura, fecha_pago, valor_pago, medio_pago
    HAVING COUNT(*) > 1
) AS d;

-- PA3. Integridad y coherencia de fechas                      -> H21, H22
SELECT
    SUM(CASE WHEN f.id_factura IS NULL THEN 1 ELSE 0 END) AS pago_sin_factura,
    SUM(CASE WHEN TRY_CONVERT(DATE, p.fecha_pago, 23) < TRY_CONVERT(DATE, f.fecha_factura, 23)
             THEN 1 ELSE 0 END) AS pago_antes_de_facturar
FROM crudo.pagos p
LEFT JOIN (SELECT DISTINCT id_factura, fecha_factura FROM crudo.facturas) f
       ON f.id_factura = p.id_factura;
