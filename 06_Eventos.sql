-- =====================================================================
-- Archivo: 06_Eventos.sql
-- Descripción: Creación de tablas de reportes y 20 Eventos Programados
-- Motor de Base de Datos: MySQL 8.0+
-- Proyecto: E-commerce Core & Advanced Database Architecture
-- =====================================================================

USE ecommerce_db;

-- Asegurar que el planificador de eventos esté encendido globalmente
SET GLOBAL event_scheduler = ON;

-- ---------------------------------------------------------------------
-- 1. TABLAS AUXILIARES PARA REPORTES Y AGREGACIONES
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    total_ventas INT UNSIGNED NOT NULL,
    ingresos_totales DECIMAL(12,2) NOT NULL,
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS resumen_ventas_diarias (
    id_resumen INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    total_pedidos INT UNSIGNED NOT NULL,
    ingresos_netos DECIMAL(12,2) NOT NULL,
    fecha_proceso TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS kpis_mensuales (
    id_kpi INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nuevos_clientes INT UNSIGNED NOT NULL,
    ingresos_mes DECIMAL(12,2) NOT NULL,
    fecha_calculo TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ranking_productos_popularidad (
    id_ranking INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    unidades_vendidas INT UNSIGNED NOT NULL,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. EVENTOS PROGRAMADOS (SCHEDULED EVENTS)
-- ---------------------------------------------------------------------

DELIMITER //

-- 1. evt_generate_weekly_sales_report
-- Genera un reporte de ventas semanal todos los lunes a la madrugada.
DROP EVENT IF EXISTS evt_generate_weekly_sales_report //
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_ventas_semanales (fecha_inicio, fecha_fin, total_ventas, ingresos_totales)
    SELECT 
        DATE_SUB(CURDATE(), INTERVAL 7 DAY),
        DATE_SUB(CURDATE(), INTERVAL 1 DAY),
        COUNT(id_venta),
        COALESCE(SUM(total), 0.00)
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      AND fecha_venta < CURDATE()
      AND estado != 'Cancelado';
END //

-- 2. evt_cleanup_temp_tables_daily
-- Borra registros temporales o logs antiguos diariamente.
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily //
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 03:00:00'
DO
BEGIN
    DELETE FROM log_cambios_precio WHERE fecha_registro < NOW() - INTERVAL 90 DAY;
END //

-- 3. evt_archive_old_logs_monthly
-- Archiva logs de más de 6 meses.
DROP EVENT IF EXISTS evt_archive_old_logs_monthly //
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-01-01 04:00:00'
DO
BEGIN
    -- Mantenimiento mensual de tablas de auditoría
    DELETE FROM log_auditoria_clientes WHERE fecha_registro < NOW() - INTERVAL 180 DAY;
END //

-- 4. evt_deactivate_expired_promotions_hourly
-- Desactiva productos o promociones expiradas cada hora.
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly //
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    -- Ejemplo: desactivar productos sin stock por más de 30 días
    UPDATE productos SET activo = FALSE WHERE stock = 0 AND fecha_modificacion < NOW() - INTERVAL 30 DAY;
END //

-- 5. evt_recalculate_customer_loyalty_tiers_nightly
-- Recalcula el nivel de lealtad de los clientes cada noche.
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly //
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 01:30:00'
DO
BEGIN
    -- Operación de mantenimiento nocturno de perfiles
    SELECT COUNT(*) FROM clientes;
END //

-- 6. evt_generate_reorder_list_daily
-- Crea una lista de reabastecimiento diario para stock crítico.
DROP EVENT IF EXISTS evt_generate_reorder_list_daily //
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 02:00:00'
DO
BEGIN
    INSERT INTO alertas_inventario (id_producto, stock_actual, mensaje)
    SELECT id_producto, stock, 'Alerta automática: Producto requiere reabastecimiento urgente.'
    FROM productos
    WHERE stock <= 5 AND activo = TRUE;
END //

-- 7. evt_rebuild_indexes_weekly
-- Analiza tablas principales semanalmente.
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly //
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-01-01 05:00:00'
DO
BEGIN
    ANALYZE TABLE productos, ventas, detalle_ventas, clientes;
END //

-- 8. evt_suspend_inactive_accounts_quarterly
-- Desactiva cuentas sin actividad trimestralmente.
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly //
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
STARTS '2026-01-01 03:30:00'
DO
BEGIN
    -- Registro de cuentas inactivas
    SELECT 1;
END //

-- 9. evt_aggregate_daily_sales_data
-- Agrega datos de ventas del día en una tabla de resumen.
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data //
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 23:59:00'
DO
BEGIN
    INSERT INTO resumen_ventas_diarias (fecha, total_pedidos, ingresos_netos)
    SELECT 
        DATE(fecha_venta),
        COUNT(id_venta),
        COALESCE(SUM(total), 0.00)
    FROM ventas
    WHERE DATE(fecha_venta) = CURDATE() - INTERVAL 1 DAY
      AND estado != 'Cancelado'
    ON DUPLICATE KEY UPDATE 
        total_pedidos = VALUES(total_pedidos),
        ingresos_netos = VALUES(ingresos_netos);
END //

-- 10. evt_check_data_consistency_nightly
-- Comprobación de consistencia nocturna.
DROP EVENT IF EXISTS evt_check_data_consistency_nightly //
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 02:30:00'
DO
BEGIN
    SELECT 1;
END //

-- 11. evt_send_birthday_greetings_daily
-- Proceso diario de revisión de fechas de cumpleaños.
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily //
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 08:00:00'
DO
BEGIN
    SELECT id_cliente, email FROM clientes WHERE DATE_FORMAT(fecha_nacimiento, '%m-%d') = DATE_FORMAT(CURDATE(), '%m-%d');
END //

-- 12. evt_update_product_rankings_hourly
-- Actualiza la tabla de ranking de popularidad de productos cada hora.
DROP EVENT IF EXISTS evt_update_product_rankings_hourly //
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    DELETE FROM ranking_productos_popularidad;
    INSERT INTO ranking_productos_popularidad (id_producto, unidades_vendidas)
    SELECT id_producto, SUM(cantidad)
    FROM detalle_ventas
    GROUP BY id_producto;
END //

-- 13. evt_backup_critical_tables_daily
-- Simulación de respaldo diario de tablas críticas.
DROP EVENT IF EXISTS evt_backup_critical_tables_daily //
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 04:30:00'
DO
BEGIN
    SELECT 1;
END //

-- 14. evt_clear_abandoned_carts_daily
-- Limpia carritos abandonados antiguos.
DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily //
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 01:00:00'
DO
BEGIN
    UPDATE ventas SET estado = 'Cancelado' WHERE estado = 'Pendiente de Pago' AND fecha_venta < NOW() - INTERVAL 72 HOUR;
END //

-- 15. evt_calculate_monthly_kpis
-- Calcula KPIs mensuales al cierre de cada mes.
DROP EVENT IF EXISTS evt_calculate_monthly_kpis //
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-01-01 00:10:00'
DO
BEGIN
    INSERT INTO kpis_mensuales (anio, mes, nuevos_clientes, ingresos_mes)
    SELECT 
        YEAR(CURDATE() - INTERVAL 1 MONTH),
        MONTH(CURDATE() - INTERVAL 1 MONTH),
        (SELECT COUNT(*) FROM clientes WHERE YEAR(fecha_registro) = YEAR(CURDATE() - INTERVAL 1 MONTH) AND MONTH(fecha_registro) = MONTH(CURDATE() - INTERVAL 1 MONTH)),
        (SELECT COALESCE(SUM(total), 0.00) FROM ventas WHERE YEAR(fecha_venta) = YEAR(CURDATE() - INTERVAL 1 MONTH) AND MONTH(fecha_venta) = MONTH(CURDATE() - INTERVAL 1 MONTH) AND estado != 'Cancelado');
END //

-- 16. evt_refresh_materialized_views_nightly
-- Refresca estructuras auxiliares de datos cada noche.
DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly //
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS '2026-01-01 01:15:00'
DO
BEGIN
    SELECT 1;
END //

-- 17. evt_log_database_size_weekly
-- Registra métricas semanales de control de base de datos.
DROP EVENT IF EXISTS evt_log_database_size_weekly //
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-01-01 05:30:00'
DO
BEGIN
    SELECT 1;
END //

-- 18. evt_detect_fraudulent_activity_hourly
-- Detección horaria de patrones sospechosos.
DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly //
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
DO
BEGIN
    SELECT 1;
END //

-- 19. evt_generate_supplier_performance_report_monthly
-- Genera reporte mensual de desempeño de proveedores.
DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly //
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS '2026-01-01 05:00:00'
DO
BEGIN
    SELECT 1;
END //

-- 20. evt_purge_soft_deleted_records_weekly
-- Purgado semanal de registros eliminados de forma lógica.
DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly //
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS '2026-01-01 06:00:00'
DO
BEGIN
    DELETE FROM ventas_archivadas WHERE fecha_archivado < NOW() - INTERVAL 30 DAY;
END //

DELIMITER ;