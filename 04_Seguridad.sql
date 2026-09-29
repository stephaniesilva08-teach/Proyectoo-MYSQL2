-- =====================================================================
-- Archivo: 04_Seguridad.sql
-- Descripción: Gestión de roles, usuarios, permisos, vistas seguras y políticas (DCL)
-- Motor de Base de Datos: MySQL 8.0+
-- Proyecto: E-commerce Core & Advanced Database Architecture
-- =====================================================================

USE ecommerce_db;

-- ---------------------------------------------------------------------
-- 1. CREACIÓN DE ROLES DEL SISTEMA
-- ---------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'Administrador_Sistema';
CREATE ROLE IF NOT EXISTS 'Gerente_Marketing';
CREATE ROLE IF NOT EXISTS 'Analista_Datos';
CREATE ROLE IF NOT EXISTS 'Empleado_Inventario';
CREATE ROLE IF NOT EXISTS 'Atencion_Cliente';
CREATE ROLE IF NOT EXISTS 'Auditor_Financiero';
CREATE ROLE IF NOT EXISTS 'Visitante';

-- ---------------------------------------------------------------------
-- 2. ASIGNACIÓN DE PRIVILEGIOS A ROLES
-- ---------------------------------------------------------------------

-- 1. Administrador_Sistema: Todos los privilegios sobre la base de datos
GRANT ALL PRIVILEGES ON ecommerce_db.* TO 'Administrador_Sistema';

-- 2. Gerente_Marketing: Acceso de solo lectura a ventas y clientes, más permisos para sps de marketing
GRANT SELECT ON ecommerce_db.ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Gerente_Marketing';
GRANT SELECT ON ecommerce_db.clientes TO 'Gerente_Marketing';
GRANT EXECUTE ON PROCEDURE ecommerce_db.sp_ObtenerDashboardAdmin TO 'Gerente_Marketing';

-- 3. Analista_Datos: Acceso de solo lectura a todas las tablas, excepto auditoría (si aplica)
GRANT SELECT ON ecommerce_db.* TO 'Analista_Datos';

-- 4. Empleado_Inventario: Modificar exclusivamente stock y ubicación/datos de productos
GRANT SELECT, UPDATE (stock, activo) ON ecommerce_db.productos TO 'Empleado_Inventario';

-- 5. Atencion_Cliente: Ver clientes y ventas, pero sin modificar precios
GRANT SELECT ON ecommerce_db.clientes TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Atencion_Cliente';
GRANT SELECT ON ecommerce_db.productos TO 'Atencion_Cliente';

-- 6. Auditor_Financiero: Solo lectura a ventas, productos y logs de precios
GRANT SELECT ON ecommerce_db.ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.detalle_ventas TO 'Auditor_Financiero';
GRANT SELECT ON ecommerce_db.productos TO 'Auditor_Financiero';
-- (Se asume la existencia futura de log_cambios_precio)
GRANT SELECT ON ecommerce_db.categorias TO 'Auditor_Financiero';

-- 7. Visitante: Solo puede ver la tabla productos
GRANT SELECT ON ecommerce_db.productos TO 'Visitante';
GRANT SELECT ON ecommerce_db.categorias TO 'Visitante';

-- ---------------------------------------------------------------------
-- 3. CREACIÓN DE USUARIOS Y ASIGNACIÓN DE ROLES
-- ---------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'AdminSecure#2026_Root';
CREATE USER IF NOT EXISTS 'marketing_user'@'localhost' IDENTIFIED BY 'MarketPass#2026_Mkt';
CREATE USER IF NOT EXISTS 'inventory_user'@'localhost' IDENTIFIED BY 'Invent#2026_Stock';
CREATE USER IF NOT EXISTS 'support_user'@'localhost' IDENTIFIED BY 'Support#2026_Help';

-- Asignar roles a los usuarios correspondientes
GRANT 'Administrador_Sistema' TO 'admin_user'@'localhost';
GRANT 'Gerente_Marketing' TO 'marketing_user'@'localhost';
GRANT 'Empleado_Inventario' TO 'inventory_user'@'localhost';
GRANT 'Atencion_Cliente' TO 'support_user'@'localhost';

-- Establecer roles activos por defecto al iniciar sesión
SET DEFAULT ROLE 'Administrador_Sistema' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Gerente_Marketing' TO 'marketing_user'@'localhost';
SET DEFAULT ROLE 'Empleado_Inventario' TO 'inventory_user'@'localhost';
SET DEFAULT ROLE 'Atencion_Cliente' TO 'support_user'@'localhost';

-- ---------------------------------------------------------------------
-- 4. RESTRICCIONES Y CONFIGURACIONES DE SEGURIDAD AVANZADA
-- ---------------------------------------------------------------------

-- Impedir que el rol Analista_Datos pueda ejecutar comandos DELETE o TRUNCATE
-- (En MySQL, revocar explícitamente comandos de modificación si se hubiesen otorgado)
REVOKE DELETE ON ecommerce_db.* FROM 'Analista_Datos';

-- Revocar el permiso de UPDATE sobre la columna 'precio' de productos al Empleado_Inventario
REVOKE UPDATE (precio) ON ecommerce_db.productos FROM 'Empleado_Inventario';

-- Crear una vista v_info_clientes_basica que oculte información sensible (ej. contraseñas)
DROP VIEW IF EXISTS v_info_clientes_basica;
CREATE VIEW v_info_clientes_basica AS
SELECT 
    id_cliente,
    nombre,
    apellido,
    email,
    direccion_envio,
    fecha_registro
FROM clientes;

-- Otorgar acceso a la vista básica al rol Atencion_Cliente
GRANT SELECT ON ecommerce_db.v_info_clientes_basica TO 'Atencion_Cliente';

-- Asegurar que el usuario root no pueda ser usado desde conexiones remotas
-- (Actualización de seguridad para restringir root exclusivamente a localhost)
UPDATE mysql.user SET Host = 'localhost' WHERE User = 'root' AND Host != 'localhost';
FLUSH PRIVILEGES;

-- Limitar recursos por hora para el rol Analista_Datos (ej. max_queries_per_hour)
ALTER USER 'Analista_Datos'@'%' WITH MAX_QUERIES_PER_HOUR 100;
-- Nota: Si el usuario analista es local, aplicar la restricción sobre 'localhost':
-- ALTER USER 'analista_user'@'localhost' WITH MAX_QUERIES_PER_HOUR 100;

-- Auditar intentos de inicio de sesión fallidos (Activación del plugin connection_control si está disponible)
-- INSTALL PLUGIN connection_control SONAME 'connection_control.so';
-- SET GLOBAL connection_control_failed_connections_threshold = 3;

FLUSH PRIVILEGES;