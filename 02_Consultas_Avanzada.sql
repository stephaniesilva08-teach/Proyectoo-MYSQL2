-- =====================================================================
-- Archivo: 02_Consultas_Avanzadas.sql
-- Descripción: Consultas de análisis, reportes y Business Intelligence (DQL)
-- Motor de Base de Datos: MySQL 8.0+
-- Proyecto: E-commerce Core & Advanced Database Architecture
-- =====================================================================

USE ecommerce_db;

-- ---------------------------------------------------------------------
-- 1. Top 10 Productos Más Vendidos
-- Pregunta: ¿Cuáles son los 10 productos que han generado más ingresos acumulados?
-- ---------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre AS producto,
    p.sku,
    SUM(dv.cantidad) AS total_unidades_vendidas,
    SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos_totales
FROM productos p
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta
WHERE v.estado != 'Cancelado'
GROUP BY p.id_producto, p.nombre, p.sku
ORDER BY ingresos_totales DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- 2. Productos con Bajas Ventas
-- Pregunta: ¿Qué productos se encuentran en el 10% inferior de ventas en términos de unidades?
-- ---------------------------------------------------------------------
WITH VentasProductos AS (
    SELECT 
        p.id_producto,
        p.nombre,
        p.sku,
        COALESCE(SUM(dv.cantidad), 0) AS total_vendido,
        PERCENT_RANK() OVER (ORDER BY COALESCE(SUM(dv.cantidad), 0) ASC) as p_rank
    FROM productos p
    LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
    GROUP BY p.id_producto, p.nombre, p.sku
)
SELECT id_producto, nombre, sku, total_vendido
FROM VentasProductos
WHERE p_rank <= 0.10
ORDER BY total_vendido ASC;

-- ---------------------------------------------------------------------
-- 3. Clientes VIP
-- Pregunta: ¿Quiénes son los 5 clientes con mayor valor de vida (LTV) basado en su gasto histórico?
-- ---------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    COUNT(v.id_venta) AS total_compras,
    SUM(v.total) AS ltv_gasto_total
FROM clientes c
JOIN ventas v ON c.id_cliente = v.id_cliente
WHERE v.estado != 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.email
ORDER BY ltv_gasto_total DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 4. Análisis de Ventas Mensuales
-- Pregunta: ¿Cuáles son las ventas totales agrupadas por mes y año?
-- ---------------------------------------------------------------------
SELECT 
    YEAR(v.fecha_venta) AS anio,
    MONTH(v.fecha_venta) AS mes,
    COUNT(v.id_venta) AS cantidad_pedidos,
    SUM(v.total) AS ventas_totales
FROM ventas v
WHERE v.estado != 'Cancelado'
GROUP BY YEAR(v.fecha_venta), MONTH(v.fecha_venta)
ORDER BY anio DESC, mes DESC;

-- ---------------------------------------------------------------------
-- 5. Crecimiento de Clientes
-- Pregunta: ¿Cuántos nuevos clientes se han registrado por trimestre?
-- ---------------------------------------------------------------------
SELECT 
    YEAR(fecha_registro) AS anio,
    QUARTER(fecha_registro) AS trimestre,
    COUNT(id_cliente) AS nuevos_clientes
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY anio DESC, trimestre DESC;

-- ---------------------------------------------------------------------
-- 6. Tasa de Compra Repetida
-- Pregunta: ¿Qué porcentaje de clientes ha realizado más de una compra?
-- ---------------------------------------------------------------------
WITH ComprasPorCliente AS (
    SELECT c.id_cliente, COUNT(v.id_venta) AS num_compras
    FROM clientes c
    LEFT JOIN ventas v ON c.id_cliente = v.id_cliente AND v.estado != 'Cancelado'
    GROUP BY c.id_cliente
)
SELECT 
    (SELECT COUNT(*) FROM ComprasPorCliente WHERE num_compras > 1) AS clientes_recurrentes,
    (SELECT COUNT(*) FROM ComprasPorCliente) AS total_clientes,
    ROUND(
        (SELECT COUNT(*) FROM ComprasPorCliente WHERE num_compras > 1) * 100.0 / 
        NULLIF((SELECT COUNT(*) FROM ComprasPorCliente), 0), 2
    ) AS tasa_compra_repetida_porcentaje;

-- ---------------------------------------------------------------------
-- 7. Productos Comprados Juntos Frecuentemente
-- Pregunta: ¿Qué pares de productos se compran con mayor frecuencia en la misma transacción?
-- ---------------------------------------------------------------------
SELECT 
    p1.nombre AS producto_1,
    p2.nombre AS producto_2,
    COUNT(*) AS veces_comprados_juntos
FROM detalle_ventas dv1
JOIN detalle_ventas dv2 ON dv1.id_venta = dv2.id_venta AND dv1.id_producto < dv2.id_producto
JOIN productos p1 ON dv1.id_producto = p1.id_producto
JOIN productos p2 ON dv2.id_producto = p2.id_producto
GROUP BY dv1.id_producto, dv2.id_producto, p1.nombre, p2.nombre
ORDER BY veces_comprados_juntos DESC;

-- ---------------------------------------------------------------------
-- 8. Rotación de Inventario
-- Pregunta: ¿Cuál es el valor del stock actual y la rotación estimada por categoría?
-- ---------------------------------------------------------------------
SELECT 
    cat.id_categoria,
    cat.nombre AS categoria,
    COUNT(p.id_producto) AS variedad_productos,
    SUM(p.stock) AS stock_total_unidades,
    SUM(p.stock * p.costo) AS valor_total_inventario_costo
FROM categorias cat
LEFT JOIN productos p ON cat.id_categoria = p.id_categoria
GROUP BY cat.id_categoria, cat.nombre;

-- ---------------------------------------------------------------------
-- 9. Productos que Necesitan Reabastecimiento
-- Pregunta: ¿Qué productos tienen un stock crítico (ej. menor o igual a 10 unidades)?
-- ---------------------------------------------------------------------
SELECT 
    id_producto,
    nombre,
    sku,
    stock,
    id_proveedor
FROM productos
WHERE stock <= 10 AND activo = TRUE
ORDER BY stock ASC;

-- ---------------------------------------------------------------------
-- 10. Análisis de Carrito Abandonado (Simulado)
-- Pregunta: ¿Qué clientes tienen carritos pendientes de pago con más de 24 horas de antigüedad?
-- ---------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.email,
    v.id_venta,
    v.fecha_venta,
    v.total
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado = 'Pendiente de Pago' 
  AND v.fecha_venta < NOW() - INTERVAL 24 HOUR;

-- ---------------------------------------------------------------------
-- 11. Rendimiento de Proveedores
-- Pregunta: ¿Cómo se clasifican los proveedores según el volumen de ventas y los ingresos generados?
-- ---------------------------------------------------------------------
SELECT 
    prov.id_proveedor,
    prov.nombre AS proveedor,
    COUNT(DISTINCT p.id_producto) AS productos_ofertados,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM(dv.cantidad * dv.precio_unitario_congelado), 0.00) AS ingresos_generados
FROM proveedores prov
LEFT JOIN productos p ON prov.id_proveedor = p.id_proveedor
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
LEFT JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado != 'Cancelado'
GROUP BY prov.id_proveedor, prov.nombre
ORDER BY ingresos_generados DESC;

-- ---------------------------------------------------------------------
-- 12. Análisis Geográfico de Ventas
-- Pregunta: ¿Cómo se distribuyen las ventas totales según la dirección de envío de los clientes?
-- ---------------------------------------------------------------------
SELECT 
    SUBSTRING_INDEX(c.direccion_envio, ',', -1) AS region_o_ciudad,
    COUNT(v.id_venta) AS total_pedidos,
    SUM(v.total) AS ingresos_totales
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado != 'Cancelado'
GROUP BY region_o_ciudad
ORDER BY ingresos_totales DESC;

-- ---------------------------------------------------------------------
-- 13. Ventas por Hora del Día
-- Pregunta: ¿A qué hora del día se registra la mayor cantidad de compras para optimizar campañas?
-- ---------------------------------------------------------------------
SELECT 
    HOUR(fecha_venta) AS hora_dia,
    COUNT(id_venta) AS total_ventas,
    SUM(total) AS ingresos_totales
FROM ventas
WHERE estado != 'Cancelado'
GROUP BY HOUR(fecha_venta)
ORDER BY total_ventas DESC;

-- ---------------------------------------------------------------------
-- 14. Impacto de Promociones (Simulado por estado/fecha)
-- Pregunta: ¿Cuál es el volumen de ventas comparando periodos recientes?
-- ---------------------------------------------------------------------
SELECT 
    DATE(fecha_venta) AS fecha,
    COUNT(id_venta) AS cantidad_ordenes,
    SUM(total) AS ingreso_diario
FROM ventas
WHERE estado != 'Cancelado'
GROUP BY DATE(fecha_venta)
ORDER BY fecha DESC;

-- ---------------------------------------------------------------------
-- 15. Análisis de Cohort (Retención Básica)
-- Pregunta: ¿Cuántos clientes realizaron compras agrupados por su mes de registro?
-- ---------------------------------------------------------------------
SELECT 
    DATE_FORMAT(c.fecha_registro, '%Y-%m') AS cohort_mes,
    COUNT(DISTINCT c.id_cliente) AS total_clientes_cohort,
    COUNT(DISTINCT v.id_cliente) AS clientes_con_compras
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente AND v.estado != 'Cancelado'
GROUP BY DATE_FORMAT(c.fecha_registro, '%Y-%m')
ORDER BY cohort_mes ASC;

-- ---------------------------------------------------------------------
-- 16. Margen de Beneficio por Producto
-- Pregunta: ¿Cuál es el margen de beneficio unitario y porcentual estimado para cada producto?
-- ---------------------------------------------------------------------
SELECT 
    id_producto,
    nombre,
    sku,
    precio,
    costo,
    (precio - costo) AS beneficio_unitario,
    ROUND(((precio - costo) / NULLIF(precio, 0)) * 100, 2) AS margen_porcentaje
FROM productos
WHERE activo = TRUE
ORDER BY margen_porcentaje DESC;

-- ---------------------------------------------------------------------
-- 17. Tiempo Promedio Entre Compras
-- Pregunta: ¿Cuál es el intervalo promedio de días entre pedidos consecutivos por cliente?
-- ---------------------------------------------------------------------
WITH VentasOrdenadas AS (
    SELECT 
        id_cliente,
        fecha_venta,
        LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta) AS compra_anterior
    FROM ventas
    WHERE estado != 'Cancelado'
),
Diferencias AS (
    SELECT 
        id_cliente,
        DATEDIFF(fecha_venta, compra_anterior) AS dias_entre_compras
    FROM VentasOrdenadas
    WHERE compra_anterior IS NOT NULL
)
SELECT 
    id_cliente,
    ROUND(AVG(dias_entre_compras), 1) AS promedio_dias_entre_compras
FROM Diferencias
GROUP BY id_cliente;

-- ---------------------------------------------------------------------
-- 18. Productos Más Vendidos vs Listados
-- Pregunta: Listado general de productos ordenados por su desempeño de ventas actual.
-- ---------------------------------------------------------------------
SELECT 
    p.id_producto,
    p.nombre,
    p.stock,
    COALESCE(SUM(dv.cantidad), 0) AS unidades_vendidas
FROM productos p
LEFT JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre, p.stock
ORDER BY unidades_vendidas DESC;

-- ---------------------------------------------------------------------
-- 19. Segmentación de Clientes (RFM - Recencia, Frecuencia, Monetario)
-- Pregunta: Calcular métricas básicas de Recencia (días desde última compra), Frecuencia y Monetario.
-- ---------------------------------------------------------------------
SELECT 
    c.id_cliente,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    DATEDIFF(NOW(), MAX(v.fecha_venta)) AS dias_ultima_compra,
    COUNT(v.id_venta) AS frecuencia_compras,
    SUM(v.total) AS valor_monetario_total
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente AND v.estado != 'Cancelado'
GROUP BY c.id_cliente, c.nombre, c.apellido;

-- ---------------------------------------------------------------------
-- 20. Predicción de Demanda Simple (Promedio Histórico por Categoría)
-- Pregunta: ¿Cuál es el promedio mensual de unidades vendidas por categoría para proyección de stock?
-- ---------------------------------------------------------------------
SELECT 
    cat.id_categoria,
    cat.nombre AS categoria,
    COUNT(DISTINCT DATE_FORMAT(v.fecha_venta, '%Y-%m')) AS meses_con_ventas,
    SUM(dv.cantidad) AS total_unidades_historicas,
    ROUND(SUM(dv.cantidad) / NULLIF(COUNT(DISTINCT DATE_FORMAT(v.fecha_venta, '%Y-%m')), 0), 2) AS promedio_demanda_mensual
FROM categorias cat
JOIN productos p ON cat.id_categoria = p.id_categoria
JOIN detalle_ventas dv ON p.id_producto = dv.id_producto
JOIN ventas v ON dv.id_venta = v.id_venta AND v.estado != 'Cancelado'
GROUP BY cat.id_categoria, cat.nombre;