# 🛒 Proyecto de Base de Datos para un E-commerce

> **Sistema de Base de Datos E-commerce**
> 
> Catálogo · Inventario · Clientes · Ventas · Analítica · Seguridad

---

## ✨ Presentación

Este proyecto consiste en el diseño, estructuración e implementación de una base de datos relacional robusta orientada a la gestión integral de un sistema de comercio electrónico (**E-commerce**). Su objetivo principal es optimizar el almacenamiento y la manipulación de datos críticos del negocio sobre **MySQL 8.0+**, incorporando reglas de integridad, control de inventario, trazabilidad de ventas, histórico de precios, perfiles de acceso mediante seguridad, automatización con eventos y lógica avanzada a través de procedimientos, funciones y disparadores (*triggers*).

---

## 🎯 Objetivos del Proyecto

* Diseñar un modelo relacional robusto y escalable para la tienda virtual.
* Garantizar la integridad referencial y la consistencia de la información.
* Mantener registros históricos de precios y costos en cada transacción de venta.
* Administrar eficientemente productos, categorías, proveedores, clientes, pedidos e inventario.
* Implementar consultas analíticas y reportes para la toma de decisiones comerciales.
* Centralizar la lógica reutilizable mediante funciones y procedimientos almacenados.
* Automatizar controles de integridad y auditoría técnica mediante triggers.
* Automatizar tareas de mantenimiento periódico utilizando eventos programados.
* Aplicar el principio de mínimo privilegio y separación de responsabilidades en la capa de seguridad.

---

## 🗂️ Estructura del Repositorio

El proyecto se encuentra organizado en los siguientes archivos y scripts SQL:

```text
E-commerce/
│
├── 01_Esquema_y_Datos.sql
├── 02_Consultas_Avanzadas.sql
├── 03_Funciones.sql
├── 04_Seguridad.sql
├── 05_Triggers.sql
├── 06_Eventos.sql
├── 07_Procedimientos_Almacenados.sql
│
└── README.md
```

### 📌 Propósito de cada archivo

| Archivo | Contenido |
| :--- | :--- |
| `01_Esquema_y_Datos.sql` | Creación de la estructura del esquema, tablas, restricciones, índices y datos iniciales. |
| `02_Consultas_Avanzadas.sql` | Consultas analíticas y reportes de negocio. |
| `03_Funciones.sql` | Funciones definidas por el usuario para cálculos y validaciones. |
| `04_Seguridad.sql` | Configuración de roles, usuarios, privilegios y accesos. |
| `05_Triggers.sql` | Disparadores para auditoría, validaciones y automatización de datos. |
| `06_Eventos.sql` | Eventos programados para tareas periódicas y mantenimiento. |
| `07_Procedimientos_Almacenados.sql` | Procedimientos transaccionales y operativos de la lógica de negocio. |

---

## 🛠️ Tecnologías Utilizadas

* **Motor de Base de Datos:** MySQL 8.0+
* **Lenguaje:** SQL / MySQL SQL
* **Motor de Almacenamiento:** InnoDB
* **Control Transaccional:** `START TRANSACTION`, `COMMIT`, `ROLLBACK`
* **Manejo de Errores:** `SIGNAL`, `RESIGNAL` y bloques de control de excepciones

---

## ⚙️ Instrucciones de Ejecución

Para construir, poblar e implementar correctamente la base de datos y toda su lógica asociada en tu entorno local de MySQL, sigue rigurosamente el **orden de ejecución** de los archivos SQL indicados a continuación para evitar conflictos de dependencias (llaves foráneas y referencias cruzadas):

1. **Creación del Esquema y Datos Base:**
   * Ejecuta `01_Esquema_y_Datos.sql` para crear la estructura de las tablas, relaciones y cargar la información inicial de prueba.

2. **Implementación de la Lógica y Seguridad (Orden Estricto):**
   * Ejecuta `03_Funciones.sql` para registrar las funciones personalizadas.
   * Ejecuta `05_Triggers.sql` para activar los disparadores del sistema.
   * Ejecuta `07_Procedimientos_Almacenados.sql` para incorporar la lógica transaccional.
   * Ejecuta `06_Eventos.sql` para habilitar las tareas programadas (requiere el `event_scheduler` activo).
   * Ejecuta `04_Seguridad.sql` para configurar roles, permisos y usuarios.
   * Ejecuta `02_Consultas_Avanzadas.sql` para probar las consultas de análisis y reportes.

---

> ⚠️ **Nota:** Asegúrate de contar con un servidor MySQL activo y de ejecutar los scripts con un usuario que posea privilegios administrativos suficientes para la creación de esquemas, roles y eventos en el sistema.