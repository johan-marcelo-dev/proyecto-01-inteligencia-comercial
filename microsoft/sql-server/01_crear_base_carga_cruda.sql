/* =====================================================================
   Proyecto 01 · Inteligencia comercial
   Empresa:  Distribuidora Caribe Mayorista S.A.S. (ficticia)
   Script:   01_crear_base_carga_cruda.sql
   Fase:     2 · Preparar

   Objetivo: Crear la base de datos y cargar los 7 CSV del sistema de
             facturación en el esquema "crudo", tal como llegan.

   Arquitectura por capas:
     crudo   -> datos tal cual llegan de la fuente (todo como texto)
     limpio  -> datos tipificados y depurados       (Fase 3)
     modelo  -> modelo estrella para análisis       (Fase 4)

   Por qué todo como texto en "crudo": si un dato viene mal (una fecha
   inválida, un número con letras), la carga no falla y el problema
   queda visible para la Fase 3 en vez de perderse.

   Requisito: SQL Server 2017 o superior (FORMAT = 'CSV').
   ===================================================================== */

USE master;
GO
IF DB_ID('DistribuidoraCaribe') IS NULL
    CREATE DATABASE DistribuidoraCaribe;
GO
USE DistribuidoraCaribe;
GO
IF SCHEMA_ID('crudo')  IS NULL EXEC('CREATE SCHEMA crudo');
IF SCHEMA_ID('limpio') IS NULL EXEC('CREATE SCHEMA limpio');
IF SCHEMA_ID('modelo') IS NULL EXEC('CREATE SCHEMA modelo');
GO

/* ---------------------------------------------------------------------
   1. Tablas crudas (se recrean cada vez que se ejecuta el script)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS crudo.zonas, crudo.vendedores, crudo.clientes, crudo.productos,
                     crudo.facturas, crudo.detalle_factura, crudo.pagos;
GO

CREATE TABLE crudo.zonas (
    id_zona       NVARCHAR(50),
    nombre_zona   NVARCHAR(100)
);

CREATE TABLE crudo.vendedores (
    id_vendedor      NVARCHAR(50),
    codigo_vendedor  NVARCHAR(50),
    nombre_vendedor  NVARCHAR(150),
    id_zona          NVARCHAR(50),
    fecha_ingreso    NVARCHAR(50),
    fecha_retiro     NVARCHAR(50),
    estado           NVARCHAR(50)
);

CREATE TABLE crudo.clientes (
    id_cliente      NVARCHAR(50),
    nit             NVARCHAR(50),
    nombre_cliente  NVARCHAR(200),
    tipo_cliente    NVARCHAR(100),
    ciudad          NVARCHAR(100),
    id_zona         NVARCHAR(50),
    id_vendedor     NVARCHAR(50),
    condicion_pago  NVARCHAR(100),
    cupo_credito    NVARCHAR(50),
    fecha_creacion  NVARCHAR(50)
);

CREATE TABLE crudo.productos (
    id_producto      NVARCHAR(50),
    codigo_producto  NVARCHAR(50),
    nombre_producto  NVARCHAR(250),
    categoria        NVARCHAR(100),
    marca            NVARCHAR(100),
    precio_lista     NVARCHAR(50)
);

CREATE TABLE crudo.facturas (
    id_factura         NVARCHAR(50),
    numero_factura     NVARCHAR(50),
    fecha_factura      NVARCHAR(50),
    id_cliente         NVARCHAR(50),
    id_vendedor        NVARCHAR(50),
    condicion_pago     NVARCHAR(100),
    fecha_vencimiento  NVARCHAR(50),
    estado             NVARCHAR(50)
);

CREATE TABLE crudo.detalle_factura (
    id_detalle            NVARCHAR(50),
    id_factura            NVARCHAR(50),
    id_producto           NVARCHAR(50),
    cantidad              NVARCHAR(50),
    precio_lista          NVARCHAR(50),
    porcentaje_descuento  NVARCHAR(50),
    valor_descuento       NVARCHAR(50),
    costo_unitario        NVARCHAR(50)
);

CREATE TABLE crudo.pagos (
    id_pago     NVARCHAR(50),
    id_factura  NVARCHAR(50),
    fecha_pago  NVARCHAR(50),
    valor_pago  NVARCHAR(50),
    medio_pago  NVARCHAR(100)
);
GO

/* ---------------------------------------------------------------------
   2. Carga de los CSV
      Ajusta @ruta si copiaste los archivos en otra carpeta.
      - FIRSTROW = 2      : salta la fila de encabezados
      - CODEPAGE = 65001  : UTF-8 (tildes y ñ correctas)
      - ROWTERMINATOR     : 0x0a (salto de línea tipo LF)
   --------------------------------------------------------------------- */
DECLARE @ruta NVARCHAR(260) = N'C:\datos_sql\proyecto01\';
DECLARE @sql  NVARCHAR(MAX) = N'';

DECLARE @cargas TABLE (tabla SYSNAME, archivo NVARCHAR(100));
INSERT INTO @cargas VALUES
    (N'crudo.zonas',           N'zonas.csv'),
    (N'crudo.vendedores',      N'vendedores.csv'),
    (N'crudo.clientes',        N'clientes.csv'),
    (N'crudo.productos',       N'productos.csv'),
    (N'crudo.facturas',        N'facturas.csv'),
    (N'crudo.detalle_factura', N'detalle_factura.csv'),
    (N'crudo.pagos',           N'pagos.csv');

SELECT @sql += N'
BULK INSERT ' + tabla + N'
FROM ''' + @ruta + archivo + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'',
      FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'',
      CODEPAGE = ''65001'', TABLOCK);'
FROM @cargas;

EXEC sp_executesql @sql;
GO

/* ---------------------------------------------------------------------
   3. Verificación: filas cargadas por tabla
      Valores esperados:
        zonas 5 · vendedores 13 · clientes 608 · productos 250
        facturas 33258 · detalle_factura 143047 · pagos 39199
   --------------------------------------------------------------------- */
SELECT t.name AS tabla, SUM(p.rows) AS filas_cargadas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE SCHEMA_NAME(t.schema_id) = 'crudo'
GROUP BY t.name
ORDER BY t.name;
