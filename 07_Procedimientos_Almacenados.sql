-- =====================================================================
-- Archivo: 07_Procedimientos_Almacenados.sql (Versión Definitiva)
-- Descripción: Stored Procedures con manejo estricto de transacciones y lógica real
-- Motor de Base de Datos: MySQL 8.0+
-- =====================================================================

USE ecommerce_db;

DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta;
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto;
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente;
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente;
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock;
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura;
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria;
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas;
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido;
DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente;
DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto;
DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente;
DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor;
DROP PROCEDURE IF EXISTS sp_BuscarProductos;
DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin;
DROP PROCEDURE IF EXISTS sp_ProcesarPago;
DROP PROCEDURE IF EXISTS sp_AñadirReseñaProducto;
DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados;
DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias;

DELIMITER //

-- 1. sp_RealizarNuevaVenta corregido
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT UNSIGNED,
    IN p_id_sucursal INT UNSIGNED,
    IN p_id_producto INT UNSIGNED,
    IN p_cantidad INT UNSIGNED
)
BEGIN
    DECLARE v_id_venta INT UNSIGNED;
    DECLARE v_precio DECIMAL(10,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Verificar existencia y bloquear fila de producto para evitar condiciones de carrera
    SELECT precio INTO v_precio FROM productos WHERE id_producto = p_id_producto FOR UPDATE;
    
    IF v_precio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Producto no encontrado.';
    END IF;

    -- Crear cabecera de venta
    INSERT INTO ventas (id_cliente, id_sucursal, estado, total)
    VALUES (p_id_cliente, p_id_sucursal, 'Pendiente de Pago', 0.00);
    
    SET v_id_venta = LAST_INSERT_ID();

    -- Insertar detalle (activará triggers de stock y recálculo de total)
    INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado)
    VALUES (v_id_venta, p_id_producto, p_cantidad, v_precio);

    COMMIT;
END //

-- 2. sp_AgregarNuevoProducto
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(150),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2),
    IN p_stock INT UNSIGNED,
    IN p_sku VARCHAR(100),
    IN p_id_categoria INT UNSIGNED,
    IN p_id_proveedor INT UNSIGNED
)
BEGIN
    INSERT INTO productos (nombre, descripcion, precio, costo, stock, sku, id_categoria, id_proveedor, activo)
    VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku, p_id_categoria, p_id_proveedor, TRUE);
END //

-- 3. sp_ActualizarDireccionCliente
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT UNSIGNED,
    IN p_nueva_direccion TEXT
)
BEGIN
    UPDATE clientes 
    SET direccion_envio = p_nueva_direccion 
    WHERE id_cliente = p_id_cliente;
END //

-- 4. sp_ProcesarDevolucion corregido con transacciones
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT UNSIGNED,
    IN p_id_producto INT UNSIGNED,
    IN p_cantidad INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE productos 
    SET stock = stock + p_cantidad 
    WHERE id_producto = p_id_producto;

    UPDATE ventas 
    SET estado = 'Devuelto' 
    WHERE id_venta = p_id_venta;

    COMMIT;
END //

-- 5. sp_ObtenerHistorialComprasCliente
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(
    IN p_id_cliente INT UNSIGNED
)
BEGIN
    SELECT 
        v.id_venta,
        v.fecha_venta,
        v.estado,
        v.total,
        dv.id_producto,
        p.nombre AS producto,
        dv.cantidad,
        dv.precio_unitario_congelado
    FROM ventas v
    JOIN detalle_ventas dv ON v.id_venta = dv.id_venta
    JOIN productos p ON dv.id_producto = p.id_producto
    WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END //

-- 6. sp_AjustarNivelStock
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT UNSIGNED,
    IN p_nuevo_stock INT UNSIGNED
)
BEGIN
    UPDATE productos 
    SET stock = p_nuevo_stock 
    WHERE id_producto = p_id_producto;
END //

-- 7. sp_EliminarClienteDeFormaSegura
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(
    IN p_id_cliente INT UNSIGNED
)
BEGIN
    UPDATE clientes 
    SET nombre = 'ANÓNIMO', 
        apellido = 'ANÓNIMO', 
        email = CONCAT('eliminado_', p_id_cliente, '@system.local'), 
        direccion_envio = NULL,
        contrasena = 'REDACTED'
    WHERE id_cliente = p_id_cliente;
END //

-- 8. sp_AplicarDescuentoPorCategoria
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT UNSIGNED,
    IN p_porcentaje DECIMAL(5,2)
)
BEGIN
    UPDATE productos 
    SET precio = precio - (precio * (p_porcentaje / 100.00))
    WHERE id_categoria = p_id_categoria AND activo = TRUE;
END //

-- 9. sp_GenerarReporteMensualVentas
CREATE PROCEDURE sp_GenerarReporteMensualVentas(
    IN p_anio INT,
    IN p_mes INT
)
BEGIN
    SELECT 
        DATE(fecha_venta) AS fecha,
        COUNT(id_venta) AS total_pedidos,
        SUM(total) AS ingresos_diarios
    FROM ventas
    WHERE YEAR(fecha_venta) = p_anio 
      AND MONTH(fecha_venta) = p_mes 
      AND estado != 'Cancelado'
    GROUP BY DATE(fecha_venta)
    ORDER BY fecha ASC;
END //

-- 10. sp_CambiarEstadoPedido
CREATE PROCEDURE sp_CambiarEstadoPedido(
    IN p_id_venta INT UNSIGNED,
    IN p_nuevo_estado VARCHAR(50)
)
BEGIN
    UPDATE ventas 
    SET estado = p_nuevo_estado 
    WHERE id_venta = p_id_venta;
END //

-- 11. sp_RegistrarNuevoCliente
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_contrasena VARCHAR(255),
    IN p_direccion TEXT,
    IN p_fecha_nac DATE
)
BEGIN
    IF EXISTS (SELECT 1 FROM clientes WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El correo electrónico ya se encuentra registrado.';
    END IF;

    INSERT INTO clientes (nombre, apellido, email, contrasena, direccion_envio, fecha_nacimiento)
    VALUES (p_nombre, p_apellido, p_email, p_contrasena, p_direccion, p_fecha_nac);
END //

-- 12. sp_ObtenerDetallesProductoCompleto
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(
    IN p_id_producto INT UNSIGNED
)
BEGIN
    SELECT 
        p.id_producto,
        p.nombre AS producto,
        p.descripcion,
        p.precio,
        p.costo,
        p.stock,
        p.sku,
        c.nombre AS categoria,
        pr.nombre AS proveedor,
        pr.email_contacto,
        p.activo
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    JOIN proveedores pr ON p.id_proveedor = pr.id_proveedor
    WHERE p.id_producto = p_id_producto;
END //

-- 13. sp_FusionarCuentasCliente
CREATE PROCEDURE sp_FusionarCuentasCliente(
    IN p_id_cliente_principal INT UNSIGNED,
    IN p_id_cliente_secundario INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    UPDATE ventas 
    SET id_cliente = p_id_cliente_principal 
    WHERE id_cliente = p_id_cliente_secundario;

    UPDATE clientes 
    SET email = CONCAT('merged_', p_id_cliente_secundario, '@system.local'),
        nombre = 'MERGED_ACCOUNT'
    WHERE id_cliente = p_id_cliente_secundario;

    COMMIT;
END //

-- 14. sp_AsignarProductoAProveedor
CREATE PROCEDURE sp_AsignarProductoAProveedor(
    IN p_id_producto INT UNSIGNED,
    IN p_id_nuevo_proveedor INT UNSIGNED
)
BEGIN
    UPDATE productos 
    SET id_proveedor = p_id_nuevo_proveedor 
    WHERE id_producto = p_id_producto;
END //

-- 15. sp_BuscarProductos
CREATE PROCEDURE sp_BuscarProductos(
    IN p_termino VARCHAR(100),
    IN p_id_categoria INT UNSIGNED
)
BEGIN
    SELECT *
    FROM productos
    WHERE activo = TRUE
      AND (p_termino IS NULL OR nombre LIKE CONCAT('%', p_termino, '%'))
      AND (p_id_categoria IS NULL OR id_categoria = p_id_categoria);
END //

-- 16. sp_ObtenerDashboardAdmin
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT 
        (SELECT COUNT(*) FROM ventas WHERE DATE(fecha_venta) = CURDATE() AND estado != 'Cancelado') AS ventas_hoy,
        (SELECT COALESCE(SUM(total), 0) FROM ventas WHERE DATE(fecha_venta) = CURDATE() AND estado != 'Cancelado') AS ingresos_hoy,
        (SELECT COUNT(*) FROM clientes WHERE fecha_registro >= CURDATE() - INTERVAL 30 DAY) AS nuevos_clientes_mes,
        (SELECT COUNT(*) FROM productos WHERE stock <= 5) AS productos_stock_critico;
END //

-- 17. sp_ProcesarPago (Simula el pago exitoso de una venta con control transaccional)
CREATE PROCEDURE sp_ProcesarPago(
    IN p_id_venta INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM ventas WHERE id_venta = p_id_venta AND estado = 'Pendiente de Pago') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La venta no existe o no se encuentra en estado Pendiente de Pago.';
    END IF;

    UPDATE ventas 
    SET estado = 'Pagado' 
    WHERE id_venta = p_id_venta;
    
    COMMIT;
END //

-- 18. sp_AñadirReseñaProducto (Valida rigurosamente que el cliente haya comprado y pagado el producto)
CREATE PROCEDURE sp_AñadirReseñaProducto(
    IN p_id_cliente INT UNSIGNED,
    IN p_id_producto INT UNSIGNED,
    IN p_calificacion INT,
    IN p_comentario TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM ventas v 
        JOIN detalle_ventas dv ON v.id_venta = dv.id_venta 
        WHERE v.id_cliente = p_id_cliente 
          AND dv.id_producto = p_id_producto 
          AND v.estado = 'Pagado'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Solo puede reseñar productos que haya comprado y pagado previamente.';
    END IF;

    INSERT INTO resenas (id_cliente, id_producto, calificacion, comentario)
    VALUES (p_id_cliente, p_id_producto, p_calificacion, p_comentario);
END //

-- 19. sp_ObtenerProductosRelacionados (Basado en co-compras reales de otros clientes)
CREATE PROCEDURE sp_ObtenerProductosRelacionados(
    IN p_id_producto INT UNSIGNED
)
BEGIN
    SELECT DISTINCT p.id_producto, p.nombre, p.precio, p.stock
    FROM detalle_ventas dv1
    JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta
    JOIN productos p ON dv2.id_producto = p.id_producto
    WHERE dv1.id_producto = p_id_producto
      AND dv2.id_producto <> p_id_producto
      AND p.activo = TRUE
    LIMIT 5;
END //

-- 20. sp_MoverProductosEntreCategorias (Manejo transaccional seguro para el cambio de categoría)
CREATE PROCEDURE sp_MoverProductosEntreCategorias(
    IN p_id_producto INT UNSIGNED,
    IN p_nueva_categoria INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM categorias WHERE id_categoria = p_nueva_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: La categoría de destino no existe.';
    END IF;

    UPDATE productos 
    SET id_categoria = p_nueva_categoria 
    WHERE id_producto = p_id_producto;

    COMMIT;
END //

DELIMITER ;