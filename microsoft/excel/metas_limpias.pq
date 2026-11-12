// =====================================================================
// Proyecto 01 · Inteligencia comercial
// Empresa:  Distribuidora Caribe Mayorista S.A.S. (ficticia)
// Consulta: metas_limpias (Power Query · lenguaje M)
// Fase:     3 · Procesar — Paso 7c: limpieza del Excel de metas
//
// Lee las 3 hojas de metas_comerciales.xlsx, aplica las reglas
// H23–H30 de la bitácora y entrega una sola tabla limpia.
// El archivo original NO se modifica.
//
// Uso: Excel > Datos > Obtener datos > De otras fuentes > Consulta en blanco
//      > Editor avanzado > pegar este código > ajustar la Ruta.
// =====================================================================
let
    // ---- Parámetros ------------------------------------------------
    Ruta       = "C:\RUTA\A\TU\PROYECTO\proyecto-01-inteligencia-comercial\datos\metas_comerciales.xlsx",
    FechaCorte = #date(2026, 10, 31),

    // ---- Origen: solo las hojas de metas ---------------------------
    Libro = Excel.Workbook(File.Contents(Ruta), null, true),
    Hojas = Table.SelectRows(Libro, each [Kind] = "Sheet" and Text.StartsWith([Name], "Metas")),

    // ---- H23: encabezados distintos entre hojas --------------------
    // Se promueven los encabezados y se renombran POR POSICIÓN, porque
    // los nombres cambian entre hojas pero el orden de las columnas no.
    Estandarizar = (hoja as table) as table =>
        let
            ConEncabezados = Table.PromoteHeaders(hoja, [PromoteAllScalars = true]),
            NombresOrigen  = Table.ColumnNames(ConEncabezados),
            NombresOficial = {"anio", "mes", "codigo_vendedor", "nombre_vendedor", "zona", "meta_ventas"},
            Renombrada     = Table.RenameColumns(ConEncabezados, List.Zip({NombresOrigen, NombresOficial}))
        in
            Renombrada,
    HojasEstandar = Table.TransformColumns(Hojas, {{"Data", Estandarizar}}),
    Combinada     = Table.Combine(HojasEstandar[Data]),

    // ---- H24: mes como texto ("Enero") -> número (1) ---------------
    Meses     = {"enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                 "agosto", "septiembre", "octubre", "noviembre", "diciembre"},
    MesNumero = Table.TransformColumns(Combinada, {{"mes",
                    each if Value.Is(_, type number) then _
                         else List.PositionOf(Meses, Text.Lower(Text.Trim(Text.From(_)))) + 1,
                    Int64.Type}}),

    // ---- H25: códigos con minúscula, espacio o guion ---------------
    Codigos = Table.TransformColumns(MesNumero, {{"codigo_vendedor",
                  each Text.Upper(Text.Remove(Text.Trim(Text.From(_)), "-")), type text}}),

    // ---- H26: metas escritas como texto ("123.400.000") ------------
    // Se quitan los separadores antes de convertir, para no depender
    // de la configuración regional del computador.
    MetasNumero = Table.TransformColumns(Codigos, {{"meta_ventas",
                      each if _ = null then null
                           else if Value.Is(_, type number) then _
                           else Number.From(Text.Remove(Text.From(_), {".", ",", "$", " "})),
                      type number}}),

    // ---- Tipos explícitos (nunca automáticos) ----------------------
    Tipos = Table.TransformColumnTypes(MetasNumero, {
                {"anio", Int64.Type}, {"nombre_vendedor", type text}, {"zona", type text}}),

    // ---- H28: filas duplicadas -------------------------------------
    // Se quitan DESPUÉS de estandarizar: así " V005" y "V005" se
    // reconocen como la misma fila.
    SinDuplicados = Table.Distinct(Tipos),

    // ---- H29: meta de V007 después de su retiro (30-jun-2025) ------
    SinRetirada = Table.SelectRows(SinDuplicados, each
                      not ([codigo_vendedor] = "V007" and #date([anio], [mes], 1) > #date(2025, 6, 30))),

    // ---- H30: solo metas hasta la fecha de corte -------------------
    HastaCorte = Table.SelectRows(SinRetirada, each #date([anio], [mes], 1) <= FechaCorte),

    // ---- H27: meta vacía -> se conserva y se marca -----------------
    // No se inventa: se excluye del % de cumplimiento en el análisis.
    Marcada = Table.AddColumn(HastaCorte, "meta_faltante", each [meta_ventas] = null, type logical),

    Ordenada = Table.Sort(Marcada, {{"anio", Order.Ascending}, {"mes", Order.Ascending}, {"codigo_vendedor", Order.Ascending}})
in
    Ordenada
