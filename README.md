# Base de Datos Biblioteca

Proyecto de la asignatura **Base de Datos II** del programa de Ingeniería de Software, Universidad de Cartagena.

## Descripción

Base de datos para la gestión de una biblioteca. Permite llevar el control de los libros, sus autores y categorías, los socios y los préstamos, incluyendo el cálculo automático de multas por devolución tardía.

## Motor y herramientas

- **Motor:** MySQL 8.0
- **Herramienta:** MySQL Workbench

## Estructura

La base de datos tiene 5 tablas y 4 relaciones, normalizadas hasta la tercera forma normal (3FN):

| Tabla | Descripción |
|-------|-------------|
| `categoria` | Categorías de los libros |
| `autor` | Autores de los libros |
| `libro` | Catálogo de libros y ejemplares disponibles |
| `socio` | Personas registradas en la biblioteca |
| `prestamo` | Préstamos y devoluciones |

**Relaciones:**
- Un autor tiene muchos libros.
- Una categoría tiene muchos libros.
- Un libro puede tener muchos préstamos.
- Un socio puede tener muchos préstamos.

## Contenido del script

- **Funciones de cadena:** `fn_nombre_completo`, `fn_iniciales`
- **Funciones matemáticas:** `fn_dias_retraso`, `fn_calcular_multa`, `fn_porcentaje_disponible`
- **Triggers:** validación de ejemplares, descuento y aumento de stock, cálculo de multa
- **Vistas:** `vw_libros_detalle`, `vw_prestamos_activos`, `vw_resumen_socios`


Brayan Contreras - Ingeniería de Software, Universidad de Cartagena
