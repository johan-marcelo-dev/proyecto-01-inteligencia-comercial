# Inteligencia comercial y análisis de ventas

**Caso:** Distribuidora Caribe Mayorista S.A.S. · distribuidora de consumo masivo en la región Caribe de Colombia
**Autor:** Johan Andrés Marcelo Villorina · Analista de Datos

> ⚠️ Empresa ficticia. Todos los datos son sintéticos y fueron generados para este caso de estudio.

---

## El problema

La empresa vende cada año más, pero gana menos, y no sabe por qué. La información está repartida en archivos de Excel por vendedor, las metas se revisan solo al cierre del mes, los clientes dejan de comprar sin que nadie lo note y la cartera vencida no tiene control.

Este proyecto construye una **fuente única de información** y un dashboard que responde cinco preguntas de negocio y permite tomar decisiones a tiempo.

| Dolor | Pregunta que responde el proyecto |
|---|---|
| Información dispersa | ¿Cómo evolucionan las ventas netas por zona y categoría? |
| Margen en caída | ¿Qué zonas, categorías y clientes reducen el margen? |
| Clientes perdidos | ¿Cuántos clientes dejaron de comprar y cuánto vendían? |
| Metas tardías | ¿Quién va por debajo de la meta y desde cuándo? |
| Cartera vencida | ¿Quién debe, cuánto y desde cuándo? |

---

## Tecnologías

| Capa | Versión Microsoft | Versión Google |
|---|---|---|
| Base de datos (datos transaccionales) | SQL Server | PostgreSQL |
| Hoja de cálculo (metas comerciales) | Excel + Power Query | Google Sheets |
| Visualización | Power BI + DAX | Looker Studio |

---

## Metodología y avance

El proyecto sigue un proceso de análisis de datos en 7 fases. Cada fase tiene un entregable y un criterio de cierre.

| Fase | Descripción | Documento | Microsoft | Google |
|---|---|---|---|---|
| 0 · Diagnóstico | Contexto, dolores y trazabilidad | [00_diagnostico_dolores.md](docs/00_diagnostico_dolores.md) | ✅ | ✅ |
| 1 · Preguntar | Preguntas, KPIs, alcance y supuestos | [01_definicion_negocio.md](docs/01_definicion_negocio.md) | ✅ | ✅ |
| 2 · Preparar | Datos, mapa de fuentes y diccionario | [02_diccionario_datos.md](docs/02_diccionario_datos.md) | ✅ | ⏳ |
| 3 · Procesar | Calidad y limpieza de datos | `03_bitacora_limpieza.md` | ⏳ | ⏳ |
| 4 · Analizar | SQL, modelo estrella y exploración | `04_analisis.md` | ⏳ | ⏳ |
| 5 · Compartir | Dashboard | `05_dashboard.md` | ⏳ | ⏳ |
| 6 · Actuar | Conclusiones y recomendaciones | `06_recomendaciones.md` | ⏳ | ⏳ |

✅ Cerrada · 🔄 En curso · ⏳ Pendiente

---

## Estructura del repositorio

```
proyecto-01-inteligencia-comercial/
├── datos/            Datos fuente (CSV y Excel)
├── docs/             Documentación de cada fase
├── microsoft/
│   ├── sql-server/   Scripts T-SQL
│   ├── excel/        Metas comerciales y exploración
│   └── power-bi/     Archivo .pbix
└── google/
    ├── postgresql/   Scripts PostgreSQL
    ├── google-sheets/
    └── looker-studio/
```
