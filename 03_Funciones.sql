-- =====================================================================
-- Archivo: 03_Funciones.sql
-- Descripción: Creación de 20 Funciones Definidas por el Usuario (UDFs)
-- Motor de Base de Datos: MySQL 8.0+
-- Proyecto: E-commerce Core & Advanced Database Architecture
-- =====================================================================

USE ecommerce_db;

-- Eliminar funciones si ya existen para evitar errores al recrearlas
DROP FUNCTION IF EXISTS fn_CalcularTotalVenta;
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock;
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto;
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente;
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto;
DROP FUNCTION IF EXISTS fn_EsClienteNuevo;
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio;
DROP FUNCTION IF EXISTS fn_AplicarDescuento;
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra;
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail;
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria;
DROP FUNCTION IF EXISTS fn_ContarVentasCliente;
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra;
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad;
DROP FUNCTION IF EXISTS fn_GenerarSKU;
DROP FUNCTION IF EXISTS fn_CalcularIVA;
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria;
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega;
DROP FUNCTION IF EXISTS fn_ConvertirMoneda;
DROP FUNCTION IF EXISTS fn_ValidarComplejidadContraseña;

DELIMITER //

-- 1. fn_CalcularTotalVenta
-- Calcula el monto total de una venta específica sumando sus detalles.
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT UNSIGNED) 
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT COALESCE(SUM(cantidad * precio_unitario_congelado), 0.00)
    INTO v_total
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    RETURN v_total;
END //

-- 2. fn_VerificarDisponibilidadStock
-- Valida si hay stock suficiente para un producto dado.
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT UNSIGNED, p_cantidad_requerida INT UNSIGNED) 
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock_actual INT UNSIGNED;
    SELECT stock INTO v_stock_actual
    FROM productos
    WHERE id_producto = p_id_producto;
    
    IF v_stock_actual >= p_cantidad_requerida THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END //

-- 3. fn_ObtenerPrecioProducto
-- Devuelve el precio actual de un producto.
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT UNSIGNED) 
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2);
    SELECT precio INTO v_precio
    FROM productos
    WHERE id_producto = p_id_producto;
    RETURN v_precio;
END //

-- 4. fn_CalcularEdadCliente
-- Calcula la edad de un cliente a partir de su fecha de nacimiento.
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT UNSIGNED) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_fecha_nac DATE;
    SELECT fecha_nacimiento INTO v_fecha_nac
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    
    IF v_fecha_nac IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN TIMESTAMPDIFF(YEAR, v_fecha_nac, CURDATE());
END //

-- 5. fn_FormatearNombreCompleto
-- Devuelve el nombre y apellido de un cliente en formato estandarizado (Apellidos, Nombres).
CREATE FUNCTION fn_FormatearNombreCompleto(p_id_cliente INT UNSIGNED) 
RETURNS VARCHAR(250)
READS SQL DATA
BEGIN
    DECLARE v_nombre_completo VARCHAR(250);
    SELECT CONCAT(apellido, ', ', nombre) INTO v_nombre_completo
    FROM clientes
    WHERE id_cliente = p_id_cliente;
    RETURN v_nombre_completo;
END //

-- 6. fn_EsClienteNuevo
-- Devuelve VERDADERO si el cliente realizó su primera compra en los últimos 30 días.
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT UNSIGNED) 
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_primera_compra TIMESTAMP;
    SELECT MIN(fecha_venta) INTO v_primera_compra
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    
    IF v_primera_compra IS NOT NULL AND v_primera_compra >= (NOW() - INTERVAL 30 DAY) THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END //

-- 7. fn_CalcularCostoEnvio
-- Calcula el costo de envío base (ej. tarifa fija + variable por cantidad de artículos).
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT UNSIGNED) 
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_total_items INT;
    DECLARE v_tarifa_base DECIMAL(10,2) DEFAULT 5.00;
    
    SELECT COALESCE(SUM(cantidad), 0) INTO v_total_items
    FROM detalle_ventas
    WHERE id_venta = p_id_venta;
    
    RETURN v_tarifa_base + (v_total_items * 1.50);
END //

-- 8. fn_AplicarDescuento
-- Aplica un porcentaje de descuento a un monto dado.
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(12,2), p_porcentaje_descuento DECIMAL(5,2)) 
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    IF p_porcentaje_descuento < 0 OR p_porcentaje_descuento > 100 THEN
        RETURN p_monto;
    END IF;
    RETURN p_monto - (p_monto * (p_porcentaje_descuento / 100.00));
END //

-- 9. fn_ObtenerUltimaFechaCompra
-- Devuelve la fecha de la última compra realizada por un cliente.
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT UNSIGNED) 
RETURNS TIMESTAMP
READS SQL DATA
BEGIN
    DECLARE v_ultima_fecha TIMESTAMP;
    SELECT MAX(fecha_venta) INTO v_ultima_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    RETURN v_ultima_fecha;
END //

-- 10. fn_ValidarFormatoEmail
-- Comprueba si una cadena de texto tiene un formato de correo electrónico válido básico.
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150)) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    IF p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END //

-- 11. fn_ObtenerNombreCategoria
-- Devuelve el nombre de la categoría a partir del ID de un producto.
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT UNSIGNED) 
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_nombre_cat VARCHAR(100);
    SELECT c.nombre INTO v_nombre_cat
    FROM productos p
    JOIN categorias c ON p.id_categoria = c.id_categoria
    WHERE p.id_producto = p_id_producto;
    RETURN v_nombre_cat;
END //

-- 12. fn_ContarVentasCliente
-- Cuenta el número total de compras válidas realizadas por un cliente.
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT UNSIGNED) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total_ventas INT;
    SELECT COUNT(*) INTO v_total_ventas
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    RETURN v_total_ventas;
END //

-- 13. fn_CalcularDiasDesdeUltimaCompra
-- Devuelve el número de días transcurridos desde la última compra de un cliente.
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT UNSIGNED) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_ultima_fecha TIMESTAMP;
    SELECT MAX(fecha_venta) INTO v_ultima_fecha
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    
    IF v_ultima_fecha IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN DATEDIFF(NOW(), v_ultima_fecha);
END //

-- 14. fn_DeterminarEstadoLealtad
-- Asigna un estado de lealtad (Bronce, Plata, Oro) según el gasto total histórico.
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT UNSIGNED) 
RETURNS VARCHAR(20)
READS SQL DATA
BEGIN
    DECLARE v_gasto_total DECIMAL(12,2);
    SELECT COALESCE(SUM(total), 0.00) INTO v_gasto_total
    FROM ventas
    WHERE id_cliente = p_id_cliente AND estado != 'Cancelado';
    
    IF v_gasto_total >= 1000.00 THEN
        RETURN 'Oro';
    ELSEIF v_gasto_total >= 500.00 THEN
        RETURN 'Plata';
    ELSE
        RETURN 'Bronce';
    END IF;
END //

-- 15. fn_GenerarSKU
-- Genera un código SKU simulado basado en el ID y nombre abreviado.
CREATE FUNCTION fn_GenerarSKU(p_id_producto INT UNSIGNED, p_prefijo VARCHAR(5)) 
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    RETURN CONCAT(UPPER(p_prefijo), '-', LPAD(p_id_producto, 5, '0'));
END //

-- 16. fn_CalcularIVA
-- Calcula el impuesto (IVA 21%) sobre un monto dado.
CREATE FUNCTION fn_CalcularIVA(p_monto DECIMAL(12,2)) 
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * 0.21, 2);
END //

-- 17. fn_ObtenerStockTotalPorCategoria
-- Suma el stock de todos los productos pertenecientes a una categoría.
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT UNSIGNED) 
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock_total INT;
    SELECT COALESCE(SUM(stock), 0) INTO v_stock_total
    FROM productos
    WHERE id_categoria = p_id_categoria;
    RETURN v_stock_total;
END //

-- 18. fn_EstimarFechaEntrega
-- Estima la fecha de entrega sumando días base según la ubicación simulada.
CREATE FUNCTION fn_EstimarFechaEntrega(p_id_venta INT UNSIGNED) 
RETURNS DATE
READS SQL DATA
BEGIN
    DECLARE v_fecha_venta TIMESTAMP;
    SELECT fecha_venta INTO v_fecha_venta
    FROM ventas
    WHERE id_venta = p_id_venta;
    
    IF v_fecha_venta IS NULL THEN
        SET v_fecha_venta = NOW();
    END IF;
    
    -- Estimación estándar: 3 días hábiles
    RETURN DATE_ADD(v_fecha_venta, INTERVAL 3 DAY);
END //

-- 19. fn_ConvertirMoneda
-- Convierte un monto a otra moneda usando una tasa de cambio fija simulada (ej. USD a EUR = 0.92).
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_moneda_destino VARCHAR(3)) 
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_tasa DECIMAL(6,4) DEFAULT 1.0000;
    
    IF UPPER(p_moneda_destino) = 'EUR' THEN
        SET v_tasa = 0.9200;
    ELSEIF UPPER(p_moneda_destino) = 'GBP' THEN
        SET v_tasa = 0.7900;
    ELSEIF UPPER(p_moneda_destino) = 'MXN' THEN
        SET v_tasa = 17.0500;
    END IF;
    
    RETURN ROUND(p_monto * v_tasa, 2);
END //

-- 20. fn_ValidarComplejidadContraseña
-- Verifica si una contraseña cumple con criterios básicos de seguridad (longitud mínima).
CREATE FUNCTION fn_ValidarComplejidadContraseña(p_contrasena VARCHAR(255)) 
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    IF CHAR_LENGTH(p_contrasena) >= 8 THEN
        RETURN TRUE;
    END IF;
    RETURN FALSE;
END //

DELIMITER ;