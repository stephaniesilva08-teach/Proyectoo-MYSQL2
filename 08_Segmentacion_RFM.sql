-- =====================================================================
-- Archivo: 08_Analisis_RFM_final.sql
-- Descripcion: Segmentacion de clientes mediante analisis RFM
-- Motor: MySQL 8.0+
-- =====================================================================
--
-- Requisitos del archivo .md:
--   1. Recencia: dias desde la ultima compra.
--   2. Frecuencia: numero total de compras.
--   3. Monetario: gasto total historico.
--   4. Puntuacion de 1 a 4 para cada metrica (4 = mejor).
--   5. Segmentacion final mediante CASE.
--
-- Seguridad:
--   - Consulta exclusivamente de lectura.
--   - No utiliza SQL dinamico.
--   - No modifica datos ni estructura.
--   - No concatena parametros o entradas externas.
--
-- Manejo defensivo de datos:
--   - LEFT JOIN conserva clientes sin compras.
--   - Clientes sin compras reciben frecuencia y monetario = 0.
--   - Clientes sin compras reciben puntuaciones = 1.
--   - SUM(NULL) se normaliza a 0.00.
--   - Fechas nulas o fechas cero se excluyen del calculo de recencia.
--   - Fechas futuras no generan una recencia artificial.
--   - Las ventas con estado 'Cancelado' se excluyen.
--
-- =====================================================================

USE ecommerce_db;

WITH metricas_rfm AS (
    SELECT
        c.id_cliente,

        CONCAT(
            COALESCE(c.nombre, ''),
            CASE
                WHEN c.nombre IS NOT NULL
                 AND c.apellido IS NOT NULL
                THEN ' '
                ELSE ''
            END,
            COALESCE(c.apellido, '')
        ) AS cliente,

        -- Ignorar fechas nulas y fechas cero (0000-00-00).
        -- CAST a CHAR evita comparar una fecha invalida como DATETIME.
       MAX(
		    CASE
		        WHEN v.fecha_venta IS NULL THEN NULL
		        WHEN CAST(v.fecha_venta AS CHAR) LIKE '0000-00-00%' THEN NULL
		        ELSE CAST(v.fecha_venta AS CHAR)
		    END
		) AS ultima_compra,

        COUNT(v.id_venta) AS frecuencia_compras,
        COALESCE(SUM(v.total), 0.00) AS valor_monetario

    FROM clientes AS c

    LEFT JOIN ventas AS v
        ON v.id_cliente = c.id_cliente
       AND (v.estado IS NULL OR v.estado <> 'Cancelado')

    GROUP BY
        c.id_cliente,
        c.nombre,
        c.apellido
),

metricas_calculadas AS (
    SELECT
        id_cliente,
        cliente,

       CASE
		    WHEN ultima_compra IS NULL THEN NULL
		    WHEN ultima_compra LIKE '0000-00-00%' THEN NULL
		    WHEN STR_TO_DATE(ultima_compra, '%Y-%m-%d %H:%i:%s') > CURRENT_DATE THEN NULL
		    ELSE DATEDIFF(
		        CURRENT_DATE,
		        STR_TO_DATE(ultima_compra, '%Y-%m-%d %H:%i:%s')
		    )
		END AS recencia_dias,

        frecuencia_compras,
        valor_monetario

    FROM metricas_rfm
),

clientes_con_compra AS (
    SELECT
        id_cliente,
        cliente,
        recencia_dias,
        frecuencia_compras,
        valor_monetario,

        -- Recencia: menor numero de dias = mejor puntuacion.
        -- Los valores NULL se envian al final y luego reciben puntuacion 1.
        NTILE(4) OVER (
            ORDER BY
                CASE WHEN recencia_dias IS NULL THEN 1 ELSE 0 END ASC,
                recencia_dias ASC,
                id_cliente ASC
        ) AS cuartil_recencia,

        -- Frecuencia y monetario: mayor valor = mejor puntuacion.
        NTILE(4) OVER (
            ORDER BY frecuencia_compras ASC, id_cliente ASC
        ) AS cuartil_frecuencia,

        NTILE(4) OVER (
            ORDER BY valor_monetario ASC, id_cliente ASC
        ) AS cuartil_monetario

    FROM metricas_calculadas
    WHERE frecuencia_compras > 0
),

puntuaciones_rfm AS (
    SELECT
        m.id_cliente,
        m.cliente,
        m.recencia_dias,
        m.frecuencia_compras,
        m.valor_monetario,

        CASE
            WHEN m.frecuencia_compras = 0 THEN 1
            WHEN m.recencia_dias IS NULL THEN 1
            WHEN c.cuartil_recencia IS NULL THEN 1
            ELSE 5 - c.cuartil_recencia
        END AS puntuacion_recencia,

        CASE
            WHEN m.frecuencia_compras = 0 THEN 1
            WHEN c.cuartil_frecuencia IS NULL THEN 1
            ELSE 5 - c.cuartil_frecuencia
        END AS puntuacion_frecuencia,

        CASE
            WHEN m.frecuencia_compras = 0 THEN 1
            WHEN c.cuartil_monetario IS NULL THEN 1
            ELSE 5 - c.cuartil_monetario
        END AS puntuacion_monetario

    FROM metricas_calculadas AS m

    LEFT JOIN clientes_con_compra AS c
        ON c.id_cliente = m.id_cliente
)

SELECT
    id_cliente,
    cliente,
    recencia_dias,
    frecuencia_compras,
    valor_monetario,
    puntuacion_recencia,
    puntuacion_frecuencia,
    puntuacion_monetario,

    (
        puntuacion_recencia
        + puntuacion_frecuencia
        + puntuacion_monetario
    ) AS puntuacion_rfm,

    CASE
        WHEN frecuencia_compras = 0
            THEN 'Sin Compras'

        WHEN puntuacion_recencia = 4
         AND puntuacion_frecuencia = 4
         AND puntuacion_monetario >= 3
            THEN 'Campeones'

        WHEN puntuacion_recencia >= 3
         AND puntuacion_frecuencia >= 3
            THEN 'Leales'

        WHEN puntuacion_recencia <= 2
         AND puntuacion_frecuencia >= 3
            THEN 'En Riesgo'

        WHEN puntuacion_recencia <= 2
         AND puntuacion_frecuencia <= 2
            THEN 'Perdidos'

        ELSE 'Oportunidades'
    END AS segmento_cliente

FROM puntuaciones_rfm

ORDER BY
    puntuacion_rfm DESC,
    recencia_dias ASC,
    id_cliente ASC;
