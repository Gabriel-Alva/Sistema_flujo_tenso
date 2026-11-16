CREATE OR REPLACE VIEW vw_cola_cocina_activa AS
SELECT
    d.id_detalle,
    d.id_comanda,
    c.id_pedido,
    c.numero_ronda,
    c.enviado_en AS fecha_envio,
    p.tipo AS tipo_pedido,
    p.id_mesa,
    m.numero AS numero_mesa,
    z.nombre AS zona,
    CONCAT_WS(' ', per.nombres, per.primer_apellido) AS nombre_mesero,
    d.id_producto,
    prod.imagen_url,
    d.nombre_snapshot,
    d.id_variante,
    d.cantidad,
    d.nota,
    pr.prioridad,
    pr.color_hex,
    d.estado_item,
    d.id_estacion_cocina,
    e.nombre AS estacion,
    COALESCE(progreso.total_items_estacion, 0) AS total_items_estacion,
    COALESCE(progreso.items_listos_estacion, 0) AS items_listos_estacion,
    TIMESTAMPDIFF(SECOND, c.enviado_en, NOW()) AS segundos_transcurridos,
    (
        SELECT GROUP_CONCAT(dm.nombre_snapshot ORDER BY dm.id_detalle_mod SEPARATOR ', ')
        FROM DETALLE_MODIFICADOR dm
        WHERE dm.id_detalle = d.id_detalle
    ) AS modificadores
FROM DETALLE_COMANDA d
INNER JOIN COMANDA c ON c.id_comanda = d.id_comanda
INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
LEFT JOIN MESA m ON m.id_mesa = p.id_mesa
LEFT JOIN ZONA z ON z.id_zona = m.id_zona
LEFT JOIN USUARIO u ON u.id_usuario = p.id_usuario
LEFT JOIN PERSONA per ON per.id_persona = u.id_persona
LEFT JOIN PRODUCTO prod ON prod.id_producto = d.id_producto
INNER JOIN PRIORIDAD pr ON pr.id_prioridad = d.prioridad
LEFT JOIN ESTACION_COCINA e ON e.id_estacion = d.id_estacion_cocina
LEFT JOIN (
    SELECT
        id_comanda,
        id_estacion_cocina,
        COUNT(*) AS total_items_estacion,
        SUM(CASE WHEN estado_item IN ('LISTO', 'ENTREGADO') THEN 1 ELSE 0 END) AS items_listos_estacion
    FROM DETALLE_COMANDA
    WHERE estado_item <> 'CANCELADO'
    GROUP BY id_comanda, id_estacion_cocina
) progreso ON progreso.id_comanda = d.id_comanda
    AND progreso.id_estacion_cocina = d.id_estacion_cocina
WHERE d.estado_item IN ('PENDIENTE', 'EN_PREPARACION', 'LISTO')
  AND p.estado IN ('ABIERTO', 'EN_PAGO');
