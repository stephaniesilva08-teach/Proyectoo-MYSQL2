-- Archivo: 01_Esquema_y_Datos.sql
-- Descripción: Creación del esquema relacional completo, índices, restricciones y datos iniciales de prueba para el e-commerce
-- Motor de Base de Datos: MySQL 8.0+
-- Proyecto: E-commerce Core & Advanced Database Architecture

CREATE DATABASE IF NOT EXISTS ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS usuarios_sucursal;
DROP TABLE IF EXISTS cola_notificaciones;
DROP TABLE IF EXISTS log_ajustes_stock;
DROP TABLE IF EXISTS creditos_cliente;
DROP TABLE IF EXISTS devoluciones;
DROP TABLE IF EXISTS referidos;
DROP TABLE IF EXISTS resenas;
DROP TABLE IF EXISTS promociones;
DROP TABLE IF EXISTS visitas;
DROP TABLE IF EXISTS detalle_ventas;
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS proveedores;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS categorias;
DROP TABLE IF EXISTS sucursales;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- DEFINICIÓN DE TABLAS Y RELACIONES (DDL)
-- =====================================================================

-- 1. sucursales: Almacena las ubicaciones físicas de la empresa. Relación 1:N con ventas y usuarios_sucursal.
CREATE TABLE sucursales (
    id_sucursal INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200) NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. categorias: Organización jerárquica de productos. Relación 1:N autoseleccionada (categoría padre) y con productos.
CREATE TABLE categorias (
    id_categoria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    id_categoria_padre INT UNSIGNED NULL,
    contador_productos INT NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_categoria_padre FOREIGN KEY (id_categoria_padre) REFERENCES categorias(id_categoria) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 3. proveedores: Fabricantes o distribuidores de mercancía. Relación 1:N con productos.
CREATE TABLE proveedores (
    id_proveedor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(150) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(30) NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4. clientes: Compradores registrados en la plataforma. Relación 1:N con ventas, visitas, reseñas, referidos, créditos.
CREATE TABLE clientes (
    id_cliente INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL,
    direccion_envio TEXT,
    fecha_nacimiento DATE,
    total_gastado DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    fecha_ultimo_pedido TIMESTAMP NULL,
    nivel_lealtad ENUM('Bronce','Plata','Oro') NOT NULL DEFAULT 'Bronce',
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 5. productos: Artículos disponibles para la venta. Relación N:1 con categorías y proveedores. 1:N con detalle_ventas, visitas, reseñas, promociones.
CREATE TABLE productos (
    id_producto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL CHECK (precio > 0),
    costo DECIMAL(12,2) NOT NULL CHECK (costo >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo INT NOT NULL DEFAULT 5,
    sku VARCHAR(100) NOT NULL UNIQUE,
    peso DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    ubicacion VARCHAR(100) NOT NULL DEFAULT 'Almacén Central - Pasillo A',
    id_categoria INT UNSIGNED NOT NULL DEFAULT 1,
    id_proveedor INT UNSIGNED NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_prod_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_prod_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
) ENGINE=InnoDB;

-- 6. ventas: Transacciones comerciales de compra. Relación N:1 con clientes y sucursales. 1:N con detalle_ventas, devoluciones, notificaciones.
CREATE TABLE ventas (
    id_venta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    fecha_venta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago', 'Pagado', 'Procesando', 'Enviado', 'Entregado', 'Cancelado', 'Devuelto') NOT NULL DEFAULT 'Pendiente de Pago',
    total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal),
    INDEX idx_ventas_estado_fecha (estado, fecha_venta),
    INDEX idx_ventas_cliente_fecha (id_cliente, fecha_venta)
) ENGINE=InnoDB;

-- 7. detalle_ventas: Líneas de productos por cada venta. Relación N:1 con ventas y productos.
CREATE TABLE detalle_ventas (
    id_detalle INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario_congelado DECIMAL(12,2) NOT NULL CHECK (precio_unitario_congelado > 0),
    CONSTRAINT fk_det_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_det_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    INDEX idx_det_ventas_producto (id_producto)
) ENGINE=InnoDB;

-- 8. visitas: Registro de tráfico o visualización de productos. Relación N:1 con productos y clientes (opcional).
CREATE TABLE visitas (
    id_visita INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED NULL,
    fecha_visita TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_visita_prod FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_visita_cli FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE SET NULL,
    INDEX idx_visitas_prod_fecha (id_producto, fecha_visita)
) ENGINE=InnoDB;

-- 9. promociones: Campañas de descuentos aplicables a productos específicos. Relación N:1 con productos.
CREATE TABLE promociones (
    id_promocion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    descuento_porcentaje DECIMAL(5,2) NOT NULL CHECK (descuento_porcentaje > 0 AND descuento_porcentaje <= 100),
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_promo_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- 10. resenas: Calificaciones y comentarios de clientes sobre productos comprados. Relación N:1 con clientes y productos.
CREATE TABLE resenas (
    id_resena INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    calificacion INT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario TEXT,
    fecha_resena TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_resena_cli FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_resena_prod FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT uq_cliente_producto_resena UNIQUE (id_cliente, id_producto)
) ENGINE=InnoDB;

-- 11. referidos: Programa de recomendación entre clientes. Relación N:1 con clientes (patrocinador y referido).
CREATE TABLE referidos (
    id_referido INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente_patrocinador INT UNSIGNED NOT NULL,
    id_cliente_referido INT UNSIGNED NOT NULL,
    estado VARCHAR(50) NOT NULL DEFAULT 'Pendiente',
    fecha_referido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ref_patrocinador FOREIGN KEY (id_cliente_patrocinador) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_ref_referido FOREIGN KEY (id_cliente_referido) REFERENCES clientes(id_cliente)
) ENGINE=InnoDB;

-- 12. devoluciones: Registro de productos devueltos por los clientes tras una venta. Relación N:1 con ventas y productos.
CREATE TABLE devoluciones (
    id_devolucion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    motivo VARCHAR(255) NOT NULL,
    fecha_devolucion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dev_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta),
    CONSTRAINT fk_dev_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- 13. creditos_cliente: Monedero virtual o saldos a favor derivados de devoluciones. Relación N:1 con clientes.
CREATE TABLE creditos_cliente (
    id_credito INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto > 0),
    descripcion VARCHAR(255) NOT NULL,
    fecha_credito TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_credito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
) ENGINE=InnoDB;

-- 14. log_ajustes_stock: Auditoría de cambios manuales o extraordinarios en el inventario. Relación N:1 con productos.
CREATE TABLE log_ajustes_stock (
    id_log INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    stock_anterior INT NOT NULL,
    stock_nuevo INT NOT NULL,
    motivo VARCHAR(255) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_stock_prod FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

-- 15. cola_notificaciones: Cola de mensajes transaccionales pendientes de envío al cliente. Relación N:1 con ventas.
CREATE TABLE cola_notificaciones (
    id_notificacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    mensaje TEXT NOT NULL,
    procesada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
) ENGINE=InnoDB;

-- 16. usuarios_sucursal: Tabla asociativa N:M que vincula usuarios del sistema con sucursales asignadas.
CREATE TABLE usuarios_sucursal (
    usuario VARCHAR(100) NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    PRIMARY KEY (usuario, id_sucursal),
    CONSTRAINT fk_usu_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal) ON DELETE CASCADE
) ENGINE=InnoDB;


-- =====================================================================
-- POBLADO DE DATOS DE PRUEBA (DML)
-- =====================================================================

-- 3 Sucursales
INSERT INTO sucursales (id_sucursal, nombre, ubicacion) VALUES 
(1, 'Sucursal Central Madrid', 'Calle Gran Vía 15, Madrid'),
(2, 'Sucursal Barcelona', 'Passeig de Gràcia 40, Barcelona'),
(3, 'Sucursal Valencia', 'Calle Colón 22, Valencia');

-- Categorías (id 1 obligatoriamente 'General', más 5 categorías con subcategorías)
INSERT INTO categorias (id_categoria, nombre, descripcion, id_categoria_padre) VALUES 
(1, 'General', 'Categoría raíz por defecto', NULL),
(2, 'Electrónica', 'Dispositivos y gadgets tecnológicos', NULL),
(3, 'Smartphones', 'Teléfonos inteligentes y accesorios', 2),
(4, 'Audio y Sonido', 'Auriculares y altavoces inalámbricos', 2),
(5, 'Hogar Inteligente', 'Automatización y domótica para el hogar', NULL),
(6, 'Iluminación LED', 'Bombillas y tiras LED inteligentes', 5);

-- 5 Proveedores
INSERT INTO proveedores (id_proveedor, nombre, email_contacto, telefono_contacto) VALUES 
(1, 'TechGlobal S.A.', 'ventas@techglobal.com', '+34911223344'),
(2, 'Innovacion Digital S.L.', 'contacto@innovacion.es', '+34933445566'),
(3, 'AudioFirst Distribuciones', 'info@audiofirst.com', NULL),
(4, 'SmartHome Solutions', 'support@smarthome.org', '+34963332211'),
(5, 'MegaElectro Corp', 'b2b@megaelectro.com', '+34954443322');

-- 12 Clientes (con apellidos compuestos, un cliente sin compras id 11, y uno inactivo id 12)
INSERT INTO clientes (id_cliente, nombre, apellido, email, contrasena, direccion_envio, fecha_nacimiento, activo) VALUES
(1, 'Carlos Alberto', 'Gómez de la Cruz', 'carlos.gomez@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Mayor 45, Madrid', '1985-06-12', TRUE),
(2, 'María Teresa', 'Martínez Ruiz', 'maria.martinez@yahoo.es', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Av. Diagonal 120, Barcelona', '1990-11-25', TRUE),
(3, 'Juan José', 'Pérez del Río', 'juan.perez@outlook.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Colón 10, Valencia', '1982-03-15', TRUE),
(4, 'Ana Belén', 'Fernández Soto', 'ana.fernandez@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Plaza España 3, Sevilla', '1995-09-04', TRUE),
(5, 'Luis Miguel', 'Sánchez Blanco', 'luis.sanchez@hotmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Larios 8, Málaga', '1978-12-01', TRUE),
(6, 'Elena Sofía', 'García Morales', 'elena.garcia@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Gran Vía 88, Madrid', '1992-07-19', TRUE),
(7, 'David Alejandro', 'Rodríguez Silva', 'david.rodriguez@yahoo.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle San Vicente 14, Valencia', '1988-04-30', TRUE),
(8, 'Carmen Rosa', 'López Navarro', 'carmen.lopez@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Paseo de Gracia 12, Barcelona', '1991-10-10', TRUE),
(9, 'Francisco Javier', 'Alonso Torres', 'francisco.alonso@outlook.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Tetuán 5, Sevilla', '1980-01-22', TRUE),
(10, 'Lucía Beatriz', 'Jiménez Ruiz', 'lucia.jimenez@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Alcalá 200, Madrid', '1996-05-14', TRUE),
(11, 'Pedro Pablo', 'Iglesias Castro', 'pedro.iglesias@gmail.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Betis 22, Sevilla', '1993-08-08', TRUE), -- Sin compras
(12, 'Rosa María', 'Blanco Gómez', 'rosa.blanco@inactivo.es', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Calle Falsa 123, Madrid', '1975-02-20', FALSE); -- Inactivo

-- 16 Productos (algunos con stock <= stock_minimo, uno stock 0, uno inactivo, con pesos y ubicaciones reales)
-- Nota sobre cambios de precio: Productos como id 1 y id 2 simulan histórico donde el precio unitario en detalle_ventas refleja el valor de la fecha correspondiente.
INSERT INTO productos (id_producto, nombre, descripcion, precio, costo, stock, stock_minimo, sku, peso, ubicacion, id_categoria, id_proveedor, activo) VALUES
(1, 'Smartphone Alpha Pro X', 'Teléfono inteligente de alta gama con 256GB', 899.99, 600.00, 25, 5, 'PHN-ALP-001', 0.18, 'Pasillo A-01', 3, 1, TRUE),
(2, 'Auriculares Inalámbricos SoundMax', 'Auriculares Bluetooth con cancelación activa de ruido', 149.99, 80.00, 4, 10, 'AUD-SND-002', 0.25, 'Pasillo B-02', 4, 3, TRUE),
(3, 'Smartwatch Horizon 3', 'Reloj inteligente deportivo con GPS integrado', 249.99, 140.00, 2, 5, 'WTC-HRZ-003', 0.08, 'Pasillo A-03', 3, 1, TRUE),
(4, 'Altavoz Inteligente Echo Home', 'Altavoz con asistente de voz y sonido 360', 79.99, 45.00, 0, 5, 'AUD-ECH-004', 0.60, 'Pasillo B-05', 4, 3, TRUE),
(5, 'Bombilla LED Inteligente RGB', 'Bombilla Wi-Fi multicolor E27 regulable', 19.99, 8.00, 120, 15, 'LIG-BUL-005', 0.10, 'Pasillo C-01', 6, 4, TRUE),
(6, 'Tira LED Ambiental 5m', 'Tira de luces LED con control remoto y app', 34.99, 15.00, 8, 10, 'LIG-STR-006', 0.30, 'Pasillo C-02', 6, 4, TRUE),
(7, 'Cámara de Seguridad Wi-Fi 360', 'Cámara de vigilancia interior HD con visión nocturna', 59.99, 30.00, 15, 5, 'HOM-CAM-007', 0.20, 'Pasillo D-01', 5, 4, TRUE),
(8, 'Enchufe Inteligente Wi-Fi', 'Enchufe programable compatible con asistentes', 24.99, 10.00, 50, 10, 'HOM-PLG-008', 0.12, 'Pasillo D-02', 5, 4, TRUE),
(9, 'Tablet Nexus Tab 10', 'Tablet de 10.1 pulgadas con 128GB de almacenamiento', 329.99, 210.00, 18, 5, 'TAB-NEX-009', 0.45, 'Pasillo A-04', 2, 2, TRUE),
(10, 'Cargador Inalámbrico Rápido 15W', 'Base de carga rápida Qi para smartphones', 29.99, 12.00, 65, 10, 'ACC-CHG-010', 0.15, 'Pasillo A-05', 3, 2, TRUE),
(11, 'PowerBank Ultra 20000mAh', 'Batería externa portátil con carga rápida USB-C', 49.99, 22.00, 30, 8, 'ACC-PWR-011', 0.35, 'Pasillo A-06', 3, 2, TRUE),
(12, 'Barra de Sonido CineMax', 'Barra de sonido Dolby Atmos con subwoofer inalámbrico', 299.99, 180.00, 12, 4, 'AUD-BAR-012', 3.50, 'Pasillo B-06', 4, 3, TRUE),
(13, 'Termostato Inteligente WiFi', 'Controlador digital de temperatura para calefacción', 129.99, 75.00, 7, 5, 'HOM-TRM-013', 0.40, 'Pasillo D-03', 5, 4, TRUE),
(14, 'Sensor de Movimiento Inalámbrico', 'Sensor PIR para automatización del hogar', 39.99, 18.00, 22, 6, 'HOM-SNS-014', 0.09, 'Pasillo D-04', 5, 4, TRUE),
(15, 'Router Wi-Fi 6 Mesh Gigabit', 'Sistema de red mallada de alta velocidad', 199.99, 120.00, 14, 5, 'NET-RTR-015', 0.80, 'Pasillo E-01', 2, 5, TRUE),
(16, 'Dispositivo Descontinuado Antiguo', 'Modelo obsoleto fuera de catálogo', 99.99, 50.00, 0, 5, 'OLD-DSC-016', 1.00, 'Pasillo Z-99', 1, 5, FALSE); -- Inactivo

-- 30 Ventas repartidas en 7 meses de 2026 (con los 7 estados representados) y sus detalles correspondientes
INSERT INTO ventas (id_venta, id_cliente, id_sucursal, fecha_venta, estado, total) VALUES
(1, 1, 1, '2026-01-10 10:30:00', 'Pagado', 929.98),
(2, 2, 2, '2026-01-15 14:20:00', 'Entregado', 249.99),
(3, 3, 3, '2026-01-20 09:15:00', 'Enviado', 184.98),
(4, 4, 1, '2026-02-05 16:45:00', 'Procesando', 899.99),
(5, 5, 2, '2026-02-14 11:10:00', 'Pagado', 79.99),
(6, 6, 3, '2026-02-22 18:30:00', 'Entregado', 359.98),
(7, 7, 1, '2026-03-01 12:00:00', 'Pendiente de Pago', 199.99),
(8, 8, 2, '2026-03-12 15:00:00', 'Cancelado', 129.99),
(9, 9, 3, '2026-03-25 10:00:00', 'Devuelto', 149.99),
(10, 10, 1, '2026-04-02 11:30:00', 'Entregado', 94.98),
(11, 1, 2, '2026-04-10 13:45:00', 'Pagado', 329.99),
(12, 2, 3, '2026-04-18 17:20:00', 'Enviado', 249.99),
(13, 3, 1, '2026-05-03 09:50:00', 'Entregado', 149.99),
(14, 4, 2, '2026-05-12 14:15:00', 'Procesando', 299.99),
(15, 5, 3, '2026-05-20 16:00:00', 'Pagado', 79.99),
(16, 6, 1, '2026-06-01 10:00:00', 'Entregado', 899.99),
(17, 7, 2, '2026-06-11 12:30:00', 'Enviado', 54.98),
(18, 8, 3, '2026-06-25 15:40:00', 'Pendiente de Pago', 129.99),
(19, 9, 1, '2026-07-02 11:15:00', 'Pagado', 199.99),
(20, 10, 2, '2026-07-10 16:20:00', 'Entregado', 179.98),
(21, 1, 3, '2026-07-19 09:30:00', 'Procesando', 329.99),
(22, 2, 1, '2026-07-28 13:00:00', 'Pagado', 149.99),
(23, 3, 2, '2026-08-04 10:45:00', 'Entregado', 249.99),
(24, 4, 3, '2026-08-15 14:30:00', 'Enviado', 89.98),
(25, 5, 1, '2026-08-22 17:10:00', 'Pagado', 299.99),
(26, 6, 2, '2026-09-01 11:00:00', 'Entregado', 199.99),
(27, 7, 3, '2026-09-10 15:15:00', 'Procesando', 79.99),
(28, 8, 1, '2026-09-18 12:40:00', 'Pagado', 149.99),
(29, 9, 2, '2026-09-22 16:00:00', 'Entregado', 329.99),
(30, 10, 3, '2026-09-26 10:20:00', 'Pagado', 89.99);

-- Detalles de ventas (1 a 4 líneas por venta, precios congelados coherentes)
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado) VALUES
(1, 1, 1, 899.99), (1, 10, 1, 29.99),
(2, 3, 1, 249.99),
(3, 5, 2, 19.99), (3, 6, 4, 36.50),
(4, 1, 1, 899.99),
(5, 4, 1, 79.99),
(6, 9, 1, 329.99), (6, 10, 1, 29.99),
(7, 15, 1, 199.99),
(8, 13, 1, 129.99),
(9, 2, 1, 149.99),
(10, 5, 1, 19.99), (10, 8, 3, 24.99),
(11, 9, 1, 329.99),
(12, 3, 1, 249.99),
(13, 2, 1, 149.99),
(14, 12, 1, 299.99),
(15, 4, 1, 79.99),
(16, 1, 1, 899.99),
(17, 8, 1, 24.99), (17, 10, 1, 29.99),
(18, 13, 1, 129.99),
(19, 15, 1, 199.99),
(20, 7, 1, 59.99), (20, 11, 1, 49.99), (20, 14, 1, 70.00),
(21, 9, 1, 329.99),
(22, 2, 1, 149.99),
(23, 3, 1, 249.99),
(24, 5, 2, 44.99),
(25, 12, 1, 299.99),
(26, 15, 1, 199.99),
(27, 4, 1, 79.99),
(28, 2, 1, 149.99),
(29, 9, 1, 329.99),
(30, 3, 1, 89.99);

-- 80 Visitas
INSERT INTO visitas (id_producto, id_cliente, fecha_visita) VALUES
(1, 1, '2026-01-05 10:00:00'), (1, 2, '2026-01-06 11:00:00'), (1, 3, '2026-01-07 12:00:00'), (1, 4, '2026-01-08 13:00:00'),
(1, 5, '2026-01-09 14:00:00'), (1, 6, '2026-01-10 15:00:00'), (1, 7, '2026-01-11 16:00:00'), (1, 8, '2026-01-12 17:00:00'),
(2, 1, '2026-01-13 10:00:00'), (2, 2, '2026-01-14 11:00:00'), (2, 3, '2026-01-15 12:00:00'), (2, 4, '2026-01-16 13:00:00'),
(2, 5, '2026-01-17 14:00:00'), (2, 6, '2026-01-18 15:00:00'), (2, 7, '2026-01-19 16:00:00'), (2, 8, '2026-01-20 17:00:00'),
(3, 1, '2026-02-01 10:00:00'), (3, 2, '2026-02-02 11:00:00'), (3, 3, '2026-02-03 12:00:00'), (3, 4, '2026-02-04 13:00:00'),
(3, 5, '2026-02-05 14:00:00'), (3, 6, '2026-02-06 15:00:00'), (3, 7, '2026-02-07 16:00:00'), (3, 8, '2026-02-08 17:00:00'),
(4, 1, '2026-02-09 10:00:00'), (4, 2, '2026-02-10 11:00:00'), (4, 3, '2026-02-11 12:00:00'), (4, 4, '2026-02-12 13:00:00'),
(4, 5, '2026-02-13 14:00:00'), (4, 6, '2026-02-14 15:00:00'), (4, 7, '2026-02-15 16:00:00'), (4, 8, '2026-02-16 17:00:00'),
(5, 1, '2026-03-01 10:00:00'), (5, 2, '2026-03-02 11:00:00'), (5, 3, '2026-03-03 12:00:00'), (5, 4, '2026-03-04 13:00:00'),
(5, 5, '2026-03-05 14:00:00'), (5, 6, '2026-03-06 15:00:00'), (5, 7, '2026-03-07 16:00:00'), (5, 8, '2026-03-08 17:00:00'),
(6, 1, '2026-03-09 10:00:00'), (6, 2, '2026-03-10 11:00:00'), (6, 3, '2026-03-11 12:00:00'), (6, 4, '2026-03-12 13:00:00'),
(6, 5, '2026-03-13 14:00:00'), (6, 6, '2026-03-14 15:00:00'), (6, 7, '2026-03-15 16:00:00'), (6, 8, '2026-03-16 17:00:00'),
(7, 1, '2026-04-01 10:00:00'), (7, 2, '2026-04-02 11:00:00'), (7, 3, '2026-04-03 12:00:00'), (7, 4, '2026-04-04 13:00:00'),
(7, 5, '2026-04-05 14:00:00'), (7, 6, '2026-04-06 15:00:00'), (7, 7, '2026-04-07 16:00:00'), (7, 8, '2026-04-08 17:00:00'),
(8, 1, '2026-04-09 10:00:00'), (8, 2, '2026-04-10 11:00:00'), (8, 3, '2026-04-11 12:00:00'), (8, 4, '2026-04-12 13:00:00'),
(8, 5, '2026-04-13 14:00:00'), (8, 6, '2026-04-14 15:00:00'), (8, 7, '2026-04-15 16:00:00'), (8, 8, '2026-04-16 17:00:00'),
(9, 1, '2026-05-01 10:00:00'), (9, 2, '2026-05-02 11:00:00'), (9, 3, '2026-05-03 12:00:00'), (9, 4, '2026-05-04 13:00:00'),
(9, 5, '2026-05-05 14:00:00'), (9, 6, '2026-05-06 15:00:00'), (9, 7, '2026-05-07 16:00:00'), (9, 8, '2026-05-08 17:00:00'),
(10, 1, '2026-05-09 10:00:00'), (10, 2, '2026-05-10 11:00:00'), (10, 3, '2026-05-11 12:00:00'), (10, 4, '2026-05-12 13:00:00'),
(10, 5, '2026-05-13 14:00:00'), (10, 6, '2026-05-14 15:00:00'), (10, 7, '2026-05-15 16:00:00'), (10, 8, '2026-05-16 17:00:00');

-- 4 Promociones
INSERT INTO promociones (id_promocion, id_producto, codigo, descuento_porcentaje, fecha_inicio, fecha_fin, activa) VALUES
(1, 1, 'PROMO_ALPHA20', 20.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE),
(2, 2, 'SOUND10', 10.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE),
(3, 3, 'WATCH15', 15.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE),
(4, 5, 'LED5', 5.00, '2026-01-01 00:00:00', '2026-12-31 23:59:59', TRUE);

-- 8 Reseñas de compras reales
INSERT INTO resenas (id_resena, id_cliente, id_producto, calificacion, comentario) VALUES
(1, 1, 1, 5, 'Excelente smartphone, la batería dura muchísimo.'),
(2, 2, 3, 4, 'Muy buen reloj, aunque la correa podría ser mejor.'),
(3, 3, 5, 5, 'Las bombillas LED funcionan de maravilla con la app.'),
(4, 4, 1, 5, 'Impresionante calidad de cámara y rendimiento.'),
(5, 5, 4, 3, 'El altavoz está bien pero el volumen máximo es justo.'),
(6, 6, 9, 4, 'Tablet fluida para trabajo y entretenimiento.'),
(7, 7, 15, 5, 'Cobertura Wi-Fi perfecta en toda la casa de dos plantas.'),
(8, 10, 7, 4, 'Buena calidad de imagen nocturna.');

-- 3 Referidos válidos (patrocinador distinto del referido)
INSERT INTO referidos (id_referido, id_cliente_patrocinador, id_cliente_referido, estado) VALUES
(1, 1, 2, 'Completado'),
(2, 2, 3, 'Completado'),
(3, 3, 4, 'Pendiente');

-- 3 Devoluciones con su crédito coherente
INSERT INTO devoluciones (id_devolucion, id_venta, id_producto, cantidad, motivo) VALUES
(1, 9, 2, 1, 'El cliente reporta defecto de fábrica en auricular izquierdo.'),
(2, 3, 6, 1, 'Color incorrecto recibido por parte del almacén.'),
(3, 8, 13, 1, 'Incompatible con el sistema de calefacción del usuario.');

INSERT INTO creditos_cliente (id_credito, id_cliente, monto, descripcion) VALUES
(1, 9, 149.99, 'Devolución Venta #9'),
(2, 3, 36.50, 'Devolución Venta #3'),
(3, 8, 129.99, 'Devolución Venta #8');

-- Filas en usuarios_sucursal
INSERT INTO usuarios_sucursal (usuario, id_sucursal) VALUES
('marketing_user', 1),
('support_user', 2),
('analista_user', 3);


-- =====================================================================
-- ACTUALIZACIÓN DE DATOS DERIVADOS (SINCRONIZACIÓN INICIAL)
-- =====================================================================

-- 1. Actualizar contador_productos en categorías
UPDATE categorias c
SET c.contador_productos = (
    SELECT COUNT(*) FROM productos p WHERE p.id_categoria = c.id_categoria AND p.activo = TRUE
);

-- 2. Actualizar total_gastado y fecha_ultimo_pedido en clientes basándose en ventas válidas ('Pagado','Procesando','Enviado','Entregado')
UPDATE clientes cl
SET 
    cl.total_gastado = COALESCE((
        SELECT SUM(v.total) 
        FROM ventas v 
        WHERE v.id_cliente = cl.id_cliente 
          AND v.estado IN ('Pagado','Procesando','Enviado','Entregado')
    ), 0.00),
    cl.fecha_ultimo_pedido = (
        SELECT MAX(v.fecha_venta) 
        FROM ventas v 
        WHERE v.id_cliente = cl.id_cliente 
          AND v.estado IN ('Pagado','Procesando','Enviado','Entregado')
    );

-- 3. Actualizar nivel_lealtad de clientes según gasto acumulado (>=1000 Oro, >=500 Plata, Bronce por defecto)
UPDATE clientes
SET nivel_lealtad = CASE 
    WHEN total_gastado >= 1000.00 THEN 'Oro'
    WHEN total_gastado >= 500.00 THEN 'Plata'
    ELSE 'Bronce'
END;

-- 4. Actualizar stock de productos descontando unidades vendidas en estados activos (no Cancelado ni Devuelto)
UPDATE productos p
SET p.stock = p.stock - COALESCE((
    SELECT SUM(dv.cantidad)
    FROM detalle_ventas dv
    JOIN ventas v ON dv.id_venta = v.id_venta
    WHERE dv.id_producto = p.id_producto
      AND v.estado NOT IN ('Cancelado', 'Devuelto')
), 0);