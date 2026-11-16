DROP PROCEDURE IF EXISTS sp_cajero_resumen_dashboard;
DROP PROCEDURE IF EXISTS sp_cajero_ventas_ultimos_7_dias;
DROP PROCEDURE IF EXISTS sp_cajero_comandas_concluidas;

CREATE OR REPLACE VIEW vw_caja_comandas_concluidas AS
SELECT
    p.id_pedido,
    p.fecha,
    p.tipo,
    p.estado,
    p.id_mesa,
    m.numero AS numero_mesa,
    r.saldo_pendiente,
    (
        SELECT COUNT(*)
        FROM COMANDA co
        INNER JOIN DETALLE_COMANDA d ON d.id_comanda = co.id_comanda
        WHERE co.id_pedido = p.id_pedido
          AND d.estado_item <> 'CANCELADO'
          AND (d.estado_item IN ('LISTO', 'ENTREGADO') OR d.id_estacion_cocina IS NULL)
    ) AS items_concluidos
FROM PEDIDO p
INNER JOIN vw_resumen_cuenta_pedido r ON r.id_pedido = p.id_pedido
LEFT JOIN MESA m ON m.id_mesa = p.id_mesa
WHERE p.estado IN ('ABIERTO', 'EN_PAGO')
  AND r.saldo_pendiente > 0.009
  AND EXISTS (
      SELECT 1
      FROM COMANDA co
      INNER JOIN DETALLE_COMANDA d ON d.id_comanda = co.id_comanda
      WHERE co.id_pedido = p.id_pedido
        AND d.estado_item <> 'CANCELADO'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM COMANDA co
      INNER JOIN DETALLE_COMANDA d ON d.id_comanda = co.id_comanda
      WHERE co.id_pedido = p.id_pedido
        AND d.estado_item NOT IN ('LISTO', 'ENTREGADO', 'CANCELADO')
        AND d.id_estacion_cocina IS NOT NULL
  );

DELIMITER $$

CREATE PROCEDURE sp_cajero_resumen_dashboard(IN p_id_usuario INT UNSIGNED)
BEGIN
    SELECT
        COUNT(*) AS pedidos_cobrados_hoy,
        COALESCE(SUM(v.total_pedido), 0.00) AS ventas_hoy,
        COALESCE(AVG(v.total_pedido), 0.00) AS ticket_promedio,
        COALESCE(SUM(v.efectivo), 0.00) AS efectivo_hoy,
        COALESCE(SUM(v.tarjeta), 0.00) AS tarjeta_hoy,
        COALESCE(SUM(v.yape), 0.00) AS yape_hoy,
        COALESCE(SUM(v.plin), 0.00) AS plin_hoy,
        COALESCE(SUM(v.transferencia), 0.00) AS transferencia_hoy,
        (
            SELECT COUNT(*)
            FROM vw_resumen_cuenta_pedido r
            WHERE r.estado IN ('ABIERTO', 'EN_PAGO')
              AND r.saldo_pendiente > 0.009
        ) AS pedidos_pendientes_cobro,
        (SELECT COUNT(*) FROM vw_caja_comandas_concluidas) AS comandas_concluidas
    FROM (
        SELECT
            c.id_pedido,
            SUM(pg.monto) AS total_pedido,
            SUM(CASE WHEN pg.metodo = 'EFECTIVO' THEN pg.monto ELSE 0 END) AS efectivo,
            SUM(CASE WHEN pg.metodo = 'TARJETA' THEN pg.monto ELSE 0 END) AS tarjeta,
            SUM(CASE WHEN pg.metodo = 'YAPE' THEN pg.monto ELSE 0 END) AS yape,
            SUM(CASE WHEN pg.metodo = 'PLIN' THEN pg.monto ELSE 0 END) AS plin,
            SUM(CASE WHEN pg.metodo = 'TRANSFERENCIA' THEN pg.monto ELSE 0 END) AS transferencia
        FROM PAGO pg
        INNER JOIN CAJA_SESION cs ON cs.id_caja_sesion = pg.id_caja_sesion
        INNER JOIN COMPROBANTE c ON c.id_comprobante = pg.id_comprobante
        WHERE cs.id_usuario = p_id_usuario
          AND c.estado = 'EMITIDO'
          AND pg.created_at >= CURRENT_DATE()
          AND pg.created_at < DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)
        GROUP BY c.id_pedido
    ) v;
END$$

CREATE PROCEDURE sp_cajero_ventas_ultimos_7_dias(IN p_id_usuario INT UNSIGNED)
BEGIN
    SELECT
        fechas.fecha,
        COALESCE(ventas.total_ventas, 0.00) AS ventas,
        COALESCE(ventas.pedidos, 0) AS pedidos
    FROM (
        SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS fecha
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 4 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        UNION ALL SELECT CURRENT_DATE()
    ) fechas
    LEFT JOIN (
        SELECT
            DATE(pg.created_at) AS fecha,
            SUM(pg.monto) AS total_ventas,
            COUNT(DISTINCT c.id_pedido) AS pedidos
        FROM PAGO pg
        INNER JOIN CAJA_SESION cs ON cs.id_caja_sesion = pg.id_caja_sesion
        INNER JOIN COMPROBANTE c ON c.id_comprobante = pg.id_comprobante
        WHERE cs.id_usuario = p_id_usuario
          AND c.estado = 'EMITIDO'
          AND pg.created_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY)
          AND pg.created_at < DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)
        GROUP BY DATE(pg.created_at)
    ) ventas ON ventas.fecha = fechas.fecha
    ORDER BY fechas.fecha;
END$$

CREATE PROCEDURE sp_cajero_comandas_concluidas()
BEGIN
    SELECT
        id_pedido,
        fecha,
        tipo,
        estado,
        id_mesa,
        numero_mesa,
        saldo_pendiente,
        items_concluidos
    FROM vw_caja_comandas_concluidas
    ORDER BY fecha ASC, id_pedido ASC
    LIMIT 100;
END$$

DELIMITER ;
