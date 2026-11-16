CREATE OR REPLACE VIEW vw_resumen_cuenta_pedido AS
SELECT
    p.id_pedido,
    p.tipo,
    p.estado,
    p.id_mesa,
    p.id_cliente,
    CAST(COALESCE(items.subtotal_items, 0) AS DECIMAL(12,2)) AS subtotal_items,
    CAST(COALESCE(mods.subtotal_mods, 0) AS DECIMAL(12,2)) AS subtotal_modificadores,
    CAST(COALESCE(items.subtotal_items, 0) + COALESCE(mods.subtotal_mods, 0) AS DECIMAL(12,2)) AS base_imponible,
    CAST(
        ROUND((COALESCE(items.subtotal_items, 0) + COALESCE(mods.subtotal_mods, 0)) *
              (CAST(COALESCE(par.valor, '18') AS DECIMAL(8,4)) / 100), 2)
        AS DECIMAL(12,2)
    ) AS impuestos,
    CAST(
        ROUND((COALESCE(items.subtotal_items, 0) + COALESCE(mods.subtotal_mods, 0)) *
              (1 + CAST(COALESCE(par.valor, '18') AS DECIMAL(8,4)) / 100), 2)
        AS DECIMAL(12,2)
    ) AS total,
    CAST(COALESCE(pagos.total_pagado, 0) AS DECIMAL(12,2)) AS total_pagado,
    CAST(
        ROUND((COALESCE(items.subtotal_items, 0) + COALESCE(mods.subtotal_mods, 0)) *
              (1 + CAST(COALESCE(par.valor, '18') AS DECIMAL(8,4)) / 100), 2)
        - COALESCE(pagos.total_pagado, 0)
        AS DECIMAL(12,2)
    ) AS saldo_pendiente
FROM PEDIDO p
LEFT JOIN PARAMETRO_SISTEMA par ON par.clave = 'IGV'
LEFT JOIN (
    SELECT c.id_pedido, SUM(d.cantidad * d.precio_unitario_venta) AS subtotal_items
    FROM COMANDA c
    INNER JOIN DETALLE_COMANDA d ON d.id_comanda = c.id_comanda
    WHERE d.estado_item <> 'CANCELADO'
    GROUP BY c.id_pedido
) items ON items.id_pedido = p.id_pedido
LEFT JOIN (
    SELECT c.id_pedido, SUM(dm.precio_venta * d.cantidad) AS subtotal_mods
    FROM COMANDA c
    INNER JOIN DETALLE_COMANDA d ON d.id_comanda = c.id_comanda
    INNER JOIN DETALLE_MODIFICADOR dm ON dm.id_detalle = d.id_detalle
    WHERE d.estado_item <> 'CANCELADO'
    GROUP BY c.id_pedido
) mods ON mods.id_pedido = p.id_pedido
LEFT JOIN (
    SELECT co.id_pedido, SUM(pg.monto) AS total_pagado
    FROM COMPROBANTE co
    INNER JOIN PAGO pg ON pg.id_comprobante = co.id_comprobante
    WHERE co.estado = 'EMITIDO'
    GROUP BY co.id_pedido
) pagos ON pagos.id_pedido = p.id_pedido;

CREATE OR REPLACE VIEW vw_estado_salon_tiempo_real AS
SELECT
    m.id_mesa,
    m.id_zona,
    z.nombre AS zona,
    m.numero,
    m.capacidad,
    m.estado,
    m.activa,
    pe.id_pedido,
    pe.num_comensales,
    pe.fecha AS ocupado_desde,
    TIMESTAMPDIFF(MINUTE, pe.fecha, NOW()) AS minutos_ocupacion,
    u.id_usuario AS id_mesero,
    CONCAT(per.nombres, ' ', per.primer_apellido) AS nombre_mesero
FROM MESA m
LEFT JOIN ZONA z ON z.id_zona = m.id_zona
LEFT JOIN PEDIDO pe ON pe.id_mesa = m.id_mesa AND pe.estado IN ('ABIERTO', 'EN_PAGO')
LEFT JOIN USUARIO u ON u.id_usuario = pe.id_usuario
LEFT JOIN PERSONA per ON per.id_persona = u.id_persona;

CREATE OR REPLACE VIEW vw_arqueo_sesion_caja AS
SELECT
    cs.id_caja_sesion,
    cs.id_usuario,
    cs.estado,
    cs.monto_apertura,
    cs.apertura_en,
    cs.cierre_en,
    COALESCE(SUM(CASE WHEN pg.metodo = 'EFECTIVO' THEN pg.monto ELSE 0 END), 0) AS total_efectivo,
    COALESCE(SUM(CASE WHEN pg.metodo = 'TARJETA' THEN pg.monto ELSE 0 END), 0) AS total_tarjeta,
    COALESCE(SUM(CASE WHEN pg.metodo = 'YAPE' THEN pg.monto ELSE 0 END), 0) AS total_yape,
    COALESCE(SUM(CASE WHEN pg.metodo = 'PLIN' THEN pg.monto ELSE 0 END), 0) AS total_plin,
    COALESCE(SUM(CASE WHEN pg.metodo = 'TRANSFERENCIA' THEN pg.monto ELSE 0 END), 0) AS total_transferencia,
    COALESCE(mov.ingresos, 0) AS movimientos_ingreso,
    COALESCE(mov.egresos, 0) AS movimientos_egreso,
    CAST(
        cs.monto_apertura
        + COALESCE(SUM(CASE WHEN pg.metodo = 'EFECTIVO' THEN pg.monto ELSE 0 END), 0)
        + COALESCE(mov.ingresos, 0)
        - COALESCE(mov.egresos, 0)
        AS DECIMAL(12,2)
    ) AS saldo_teorico_gaveta
FROM CAJA_SESION cs
LEFT JOIN PAGO pg ON pg.id_caja_sesion = cs.id_caja_sesion
LEFT JOIN (
    SELECT
        id_caja_sesion,
        SUM(CASE WHEN tipo = 'INGRESO' THEN monto ELSE 0 END) AS ingresos,
        SUM(CASE WHEN tipo = 'EGRESO' THEN monto ELSE 0 END) AS egresos
    FROM MOVIMIENTO_CAJA
    GROUP BY id_caja_sesion
) mov ON mov.id_caja_sesion = cs.id_caja_sesion
GROUP BY
    cs.id_caja_sesion, cs.id_usuario, cs.estado, cs.monto_apertura, cs.apertura_en, cs.cierre_en,
    mov.ingresos, mov.egresos;

CREATE OR REPLACE VIEW vw_auditoria_legible AS
SELECT
    a.id_auditoria,
    a.tabla,
    a.id_registro,
    a.accion,
    a.datos_antes,
    a.datos_despues,
    a.fecha,
    a.id_usuario,
    u.username,
    CONCAT(per.nombres, ' ', per.primer_apellido, ' ', COALESCE(per.segundo_apellido, '')) AS nombre_completo
FROM AUDITORIA a
LEFT JOIN USUARIO u ON u.id_usuario = a.id_usuario
LEFT JOIN PERSONA per ON per.id_persona = u.id_persona;
