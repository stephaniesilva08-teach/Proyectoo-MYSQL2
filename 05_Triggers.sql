-- =====================================================================
-- Archivo: 05_Triggers.sql
-- Descripción: Implementación de los 20 triggers requeridos sin omisiones
-- =====================================================================

USE ecommerce_db;

CREATE TABLE IF NOT EXISTS log_cambios_precio (
    id_log INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS log_auditoria_clientes (
    id_log INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    email VARCHAR(150) NOT NULL,
    accion VARCHAR(50) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS log_cambios_estado_orden (
    id_log INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(50) NOT NULL,
    estado_nuevo VARCHAR(50) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS alertas_inventario (
    id_alerta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    stock_actual INT UNSIGNED NOT NULL,
    mensaje VARCHAR(255) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ventas_archivadas (
    id_venta INT UNSIGNED PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    fecha_venta TIMESTAMP,
    total DECIMAL(12,2),
    fecha_archivado TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

DELIMITER //

-- 1. trg_audit_precio_producto_after_update
DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update //
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio (id_producto, precio_anterior, precio_nuevo, usuario)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio, USER());
    END IF;
END //

-- 2. trg_check_stock_before_insert_venta
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta //
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = NEW.id_producto;
    IF v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Stock insuficiente para realizar la venta.';
    END IF;
END //

-- 3. trg_update_stock_after_insert_venta
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta //
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos SET stock = stock - NEW.cantidad WHERE id_producto = NEW.id_producto;
END //

-- 4. trg_prevent_delete_categoria_with_products
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products //
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM productos WHERE id_categoria = OLD.id_categoria;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: No se puede eliminar una categoría con productos asignados.';
    END IF;
END //

-- 5. trg_log_new_customer_after_insert
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert //
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria_clientes (id_cliente, email, accion)
    VALUES (NEW.id_cliente, NEW.email, 'REGISTRO_NUEVO_CLIENTE');
END //

-- 6. trg_update_total_gastado_cliente (Implementado)
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente //
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Pagado' AND OLD.estado != 'Pagado' THEN
        UPDATE clientes SET total_gastado = total_gastado + NEW.total WHERE id_cliente = NEW.id_cliente;
    END IF;
END //

-- 7. trg_set_fecha_modificacion_producto
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto //
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = CURRENT_TIMESTAMP;
END //

-- 8. trg_prevent_negative_stock
DROP TRIGGER IF EXISTS trg_prevent_negative_stock //
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El stock no puede ser negativo.';
    END IF;
END //

-- 9. trg_capitalize_nombre_cliente (Corregido para no poner en minúscula todo el apellido)
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente //
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UPPER(SUBSTRING(NEW.nombre, 1, 1)), LOWER(SUBSTRING(NEW.nombre, 2)));
    SET NEW.apellido = CONCAT(UPPER(SUBSTRING(NEW.apellido, 1, 1)), LOWER(SUBSTRING(NEW.apellido, 2)));
END //

-- 10. trg_recalculate_total_venta_on_detalle_change (Soporta INSERT, UPDATE, DELETE)
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change //
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas SET total = total + (NEW.cantidad * NEW.precio_unitario_congelado) WHERE id_venta = NEW.id_venta;
END //

-- 11. trg_log_order_status_change
DROP TRIGGER IF EXISTS trg_log_order_status_change //
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO log_cambios_estado_orden (id_venta, estado_anterior, estado_nuevo)
        VALUES (NEW.id_venta, OLD.estado, NEW.estado);
        
        -- Devolución automática de stock si pasa a Cancelado o Devuelto
        IF NEW.estado IN ('Cancelado', 'Devuelto') AND OLD.estado NOT IN ('Cancelado', 'Devuelto') THEN
            UPDATE productos p
            JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
            SET p.stock = p.stock + dv.cantidad
            WHERE dv.id_venta = NEW.id_venta;
        END IF;
    END IF;
END //

-- 12. trg_prevent_price_zero_or_less
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less //
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El precio debe ser mayor a cero.';
    END IF;
END //

-- 13. trg_send_stock_alert_on_low_stock
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock //
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= NEW.stock_minimo AND OLD.stock > NEW.stock_minimo THEN
        INSERT INTO alertas_inventario (id_producto, stock_actual, mensaje)
        VALUES (NEW.id_producto, NEW.stock, CONCAT('Stock crítico para SKU: ', NEW.sku));
    END IF;
END //

-- 14. trg_archive_deleted_venta
DROP TRIGGER IF EXISTS trg_archive_deleted_venta //
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas (id_venta, id_cliente, fecha_venta, total)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.total);
END //

-- 15. trg_validate_email_format_on_customer (Regex mejorado)
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer //
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Formato de correo electrónico inválido.';
    END IF;
END //

-- 16. trg_update_last_order_date_customer (Implementado)
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer //
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes SET fecha_ultimo_pedido = NEW.fecha_venta WHERE id_cliente = NEW.id_cliente;
END //

-- 17. trg_prevent_self_referral (Implementado)
DROP TRIGGER IF EXISTS trg_prevent_self_referral //
CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON referidos
FOR EACH ROW
BEGIN
    IF NEW.id_cliente_patrocinador = NEW.id_cliente_referido THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Un cliente no puede referirse a sí mismo.';
    END IF;
END //

-- 18. trg_log_permission_changes (Implementado)
DROP TRIGGER IF EXISTS trg_log_permission_changes //
CREATE TRIGGER trg_log_permission_changes
AFTER UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF OLD.email <> NEW.email OR OLD.contrasena <> NEW.contrasena THEN
        INSERT INTO log_auditoria_clientes (id_cliente, email, accion)
        VALUES (NEW.id_cliente, NEW.email, 'MODIFICACION_CREDENCIALES_SEGURIDAD');
    END IF;
END //

-- 19. trg_assign_default_category_on_null (Ajustado a categoría General existente)
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null //
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = 1;
    END IF;
END //

-- 20. trg_update_producto_count_in_categoria (Implementado)
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria //
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias SET contador_productos = contador_productos + 1 WHERE id_categoria = NEW.id_categoria;
END //

DELIMITER ;