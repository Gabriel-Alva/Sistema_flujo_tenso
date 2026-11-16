-- Mantiene el archivo ejecutable en phpMyAdmin si falta la columna usada
-- para validar idempotencia de las rondas.
SET @db := DATABASE();
SET @exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db
      AND LOWER(TABLE_NAME) = 'comanda'
      AND COLUMN_NAME = 'request_hash'
);
SET @sql := IF(
    @exists = 0,
    'ALTER TABLE COMANDA ADD COLUMN request_hash CHAR(64) NULL AFTER client_request_id',
    'SELECT 1'
);
PREPARE sipan_stmt FROM @sql;
EXECUTE sipan_stmt;
DEALLOCATE PREPARE sipan_stmt;

DROP PROCEDURE IF EXISTS sp_registrar_ronda_pedido;
DROP PROCEDURE IF EXISTS sp_registrar_pago_y_cerrar_cuenta;
DROP PROCEDURE IF EXISTS sp_cerrar_sesion_caja;
DROP PROCEDURE IF EXISTS sp_listar_pedidos_operativos;
DROP PROCEDURE IF EXISTS sp_detalle_pedido_operativo;
DROP PROCEDURE IF EXISTS sp_marcar_item_entregado;
DROP PROCEDURE IF EXISTS sp_cancelar_pedido_mesero;
DROP PROCEDURE IF EXISTS sp_buscar_clientes_delivery;
DROP PROCEDURE IF EXISTS sp_historial_pagos_pedido;

DELIMITER $$

CREATE PROCEDURE sp_registrar_ronda_pedido(
    IN p_client_request_id CHAR(36),
    IN p_request_hash CHAR(64),
    IN p_id_usuario INT UNSIGNED,
    IN p_id_pedido INT UNSIGNED,
    IN p_tipo VARCHAR(20),
    IN p_id_mesa INT UNSIGNED,
    IN p_num_comensales SMALLINT UNSIGNED,
    IN p_notas_generales TEXT,
    IN p_id_cliente INT UNSIGNED,
    IN p_id_direccion_entrega INT UNSIGNED,
    IN p_direccion_snapshot JSON,
    IN p_items JSON,
    OUT p_id_pedido_out INT UNSIGNED,
    OUT p_id_comanda_out INT UNSIGNED
)
main: BEGIN
    DECLARE v_id_pedido INT UNSIGNED;
    DECLARE v_id_comanda INT UNSIGNED;
    DECLARE v_ronda SMALLINT UNSIGNED;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_id_producto VARCHAR(15);
    DECLARE v_id_variante INT UNSIGNED;
    DECLARE v_cantidad SMALLINT UNSIGNED;
    DECLARE v_prioridad VARCHAR(12);
    DECLARE v_nota VARCHAR(250);
    DECLARE v_mods JSON;
    DECLARE v_nombre VARCHAR(160);
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_estacion SMALLINT UNSIGNED;
    DECLARE v_id_detalle INT UNSIGNED;
    DECLARE v_j INT DEFAULT 0;
    DECLARE v_mn INT DEFAULT 0;
    DECLARE v_id_mod INT UNSIGNED;
    DECLARE v_mod_nombre VARCHAR(80);
    DECLARE v_mod_precio DECIMAL(10,2);
    DECLARE v_ocupado INT DEFAULT 0;
    DECLARE v_estado_pedido VARCHAR(20);
    DECLARE v_estado_mesa VARCHAR(20);
    DECLARE v_mesa_activa TINYINT;
    DECLARE v_requiere_preparacion TINYINT;
    DECLARE v_variante_count INT DEFAULT 0;
    DECLARE v_modificador_count INT DEFAULT 0;
    DECLARE v_prioridad_count INT DEFAULT 0;
    DECLARE v_request_hash CHAR(64);
    DECLARE v_pedido_usuario INT UNSIGNED;
    DECLARE v_lock_acquired TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK(CONCAT('sipan_order_', p_client_request_id));
        END IF;
        RESIGNAL;
    END;

    SET v_lock_acquired = GET_LOCK(CONCAT('sipan_order_', p_client_request_id), 10);
    IF v_lock_acquired IS NULL OR v_lock_acquired <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_IDEMPOTENCY_BUSY';
    END IF;

    START TRANSACTION;

    SELECT c.id_comanda, c.id_pedido, c.request_hash, p.id_usuario
    INTO v_id_comanda, v_id_pedido, v_request_hash, v_pedido_usuario
    FROM COMANDA c
    INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
    WHERE c.client_request_id = p_client_request_id
    LIMIT 1;

    IF v_id_comanda IS NOT NULL THEN
        IF v_pedido_usuario <> p_id_usuario THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_FORBIDDEN';
        END IF;
        IF v_request_hash IS NOT NULL AND v_request_hash <> p_request_hash THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'IDEMPOTENCY_CONFLICT';
        END IF;
        SET p_id_pedido_out = v_id_pedido;
        SET p_id_comanda_out = v_id_comanda;
        COMMIT;
        DO RELEASE_LOCK(CONCAT('sipan_order_', p_client_request_id));
        SET v_lock_acquired = 0;
    ELSE
        SET v_id_pedido = p_id_pedido;

        IF v_id_pedido IS NULL THEN
            IF p_tipo = 'SALON' THEN
                SELECT estado, activa INTO v_estado_mesa, v_mesa_activa
                FROM MESA WHERE id_mesa = p_id_mesa FOR UPDATE;
                IF v_estado_mesa IS NULL OR v_mesa_activa <> 1 OR v_estado_mesa <> 'LIBRE' THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_TABLE_UNAVAILABLE';
                END IF;
                SELECT COUNT(*) INTO v_ocupado
                FROM PEDIDO
                WHERE id_mesa = p_id_mesa AND estado IN ('ABIERTO', 'EN_PAGO');
                IF v_ocupado > 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_TABLE_OCCUPIED';
                END IF;
            END IF;

            INSERT INTO PEDIDO (
                tipo, id_mesa, id_usuario, num_comensales, notas_generales,
                estado, version, id_cliente, id_direccion_entrega, direccion_snapshot, client_request_id
            ) VALUES (
                p_tipo, p_id_mesa, p_id_usuario, p_num_comensales, p_notas_generales,
                'ABIERTO', 1, p_id_cliente, p_id_direccion_entrega, p_direccion_snapshot, p_client_request_id
            );
            SET v_id_pedido = LAST_INSERT_ID();
        ELSE
            SELECT id_pedido, id_usuario INTO v_id_pedido, v_pedido_usuario
            FROM PEDIDO WHERE id_pedido = p_id_pedido FOR UPDATE;
            IF v_id_pedido IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_FOUND';
            END IF;
            IF v_pedido_usuario <> p_id_usuario THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_FORBIDDEN';
            END IF;
            SELECT estado INTO v_estado_pedido FROM PEDIDO WHERE id_pedido = v_id_pedido;
            IF v_estado_pedido <> 'ABIERTO' THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_OPEN';
            END IF;
        END IF;

        SELECT c.id_comanda, c.id_pedido, c.request_hash, p.id_usuario
        INTO v_id_comanda, v_id_pedido, v_request_hash, v_pedido_usuario
        FROM COMANDA c
        INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
        WHERE c.client_request_id = p_client_request_id
        LIMIT 1
        FOR UPDATE;
        IF v_id_comanda IS NOT NULL THEN
            IF v_pedido_usuario <> p_id_usuario THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_FORBIDDEN';
            END IF;
            IF v_request_hash IS NOT NULL AND v_request_hash <> p_request_hash THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'IDEMPOTENCY_CONFLICT';
            END IF;
            SET p_id_pedido_out = v_id_pedido;
            SET p_id_comanda_out = v_id_comanda;
            COMMIT;
            DO RELEASE_LOCK(CONCAT('sipan_order_', p_client_request_id));
            SET v_lock_acquired = 0;
            LEAVE main;
        END IF;

        SELECT COALESCE(MAX(numero_ronda), 0) + 1 INTO v_ronda
        FROM COMANDA WHERE id_pedido = v_id_pedido;

        INSERT INTO COMANDA (id_pedido, numero_ronda, client_request_id, request_hash, enviado_en)
        VALUES (v_id_pedido, v_ronda, p_client_request_id, p_request_hash, NOW());
        SET v_id_comanda = LAST_INSERT_ID();

        SET v_n = JSON_LENGTH(p_items);
        SET v_i = 0;

        WHILE v_i < v_n DO
            SET v_id_producto = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].id_producto')));
            SET v_id_variante = JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].id_variante'));
            SET v_cantidad = JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].cantidad'));
            SET v_prioridad = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].prioridad')));
            SET v_nota = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].nota')));
            IF v_nota = 'null' THEN SET v_nota = NULL; END IF;
            SET v_mods = JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].modificadores'));

            SELECT pr.nombre, pr.precio_actual, pr.requiere_preparacion,
                   (
                       SELECT pe.id_estacion FROM PRODUCTO_ESTACION pe
                       WHERE pe.id_producto = pr.id_producto
                       ORDER BY pe.es_principal DESC, pe.id_estacion
                       LIMIT 1
                   )
            INTO v_nombre, v_precio, v_requiere_preparacion, v_estacion
            FROM PRODUCTO pr
            WHERE pr.id_producto = v_id_producto AND pr.activo = 1;

            IF v_nombre IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PRODUCT_NOT_FOUND';
            END IF;
            IF v_id_variante IS NOT NULL THEN
                SELECT COUNT(*) INTO v_variante_count
                FROM PLATO_VARIANTE
                WHERE id_variante = v_id_variante
                  AND id_plato = v_id_producto
                  AND activo = 1;
                IF v_variante_count = 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'VARIANT_INVALID';
                END IF;
                SELECT precio INTO v_precio
                FROM PLATO_VARIANTE
                WHERE id_variante = v_id_variante;
            END IF;
            IF v_requiere_preparacion = 1 AND v_estacion IS NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PRODUCT_STATION_UNCONFIGURED';
            END IF;
            SELECT COUNT(*) INTO v_prioridad_count
            FROM PRIORIDAD
            WHERE id_prioridad = v_prioridad AND activa = 1;
            IF v_prioridad_count = 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PRIORITY_INVALID';
            END IF;

            INSERT INTO DETALLE_COMANDA (
                id_comanda, id_producto, id_variante, nombre_snapshot, precio_unitario_venta,
                id_estacion_cocina, cantidad, estado_item, prioridad, nota
            ) VALUES (
                v_id_comanda, v_id_producto, v_id_variante, v_nombre, v_precio,
                v_estacion, v_cantidad, 'PENDIENTE', COALESCE(v_prioridad, 'NORMAL'), v_nota
            );
            SET v_id_detalle = LAST_INSERT_ID();

            IF v_mods IS NOT NULL AND JSON_LENGTH(v_mods) > 0 THEN
                SET v_j = 0;
                SET v_mn = JSON_LENGTH(v_mods);
                WHILE v_j < v_mn DO
                    SET v_id_mod = JSON_EXTRACT(v_mods, CONCAT('$[', v_j, ']'));
                    SELECT COUNT(*) INTO v_modificador_count
                    FROM MODIFICADOR WHERE id_modificador = v_id_mod AND activo = 1;
                    IF v_modificador_count = 0 THEN
                        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MODIFIER_NOT_FOUND';
                    END IF;
                    SELECT nombre, precio_extra INTO v_mod_nombre, v_mod_precio
                    FROM MODIFICADOR WHERE id_modificador = v_id_mod;
                    INSERT INTO DETALLE_MODIFICADOR (id_detalle, id_modificador, nombre_snapshot, precio_venta)
                    VALUES (v_id_detalle, v_id_mod, v_mod_nombre, v_mod_precio);
                    SET v_j = v_j + 1;
                END WHILE;
            END IF;

            SET v_i = v_i + 1;
            SET v_nombre = NULL;
        END WHILE;

        INSERT INTO HISTORIAL_ESTADO (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, fecha)
        VALUES ('COMANDA', v_id_comanda, NULL, 'ENVIADA', p_id_usuario, NOW());

        SET p_id_pedido_out = v_id_pedido;
        SET p_id_comanda_out = v_id_comanda;
        SET @sipan_current_user_id = NULL;
        COMMIT;
        DO RELEASE_LOCK(CONCAT('sipan_order_', p_client_request_id));
        SET v_lock_acquired = 0;
    END IF;
END main$$

CREATE PROCEDURE sp_registrar_pago_y_cerrar_cuenta(
    IN p_payment_request_id CHAR(36),
    IN p_id_comprobante INT UNSIGNED,
    IN p_id_caja_sesion INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    IN p_metodo VARCHAR(20),
    IN p_monto DECIMAL(12,2),
    IN p_monto_recibido DECIMAL(12,2),
    OUT p_vuelto DECIMAL(12,2),
    OUT p_id_pago_out INT UNSIGNED,
    OUT p_pedido_estado VARCHAR(20),
    OUT p_replayed TINYINT
)
BEGIN
    DECLARE v_sesion_estado VARCHAR(20);
    DECLARE v_sesion_usuario INT UNSIGNED;
    DECLARE v_id_pedido INT UNSIGNED;
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_id_pago INT UNSIGNED;
    DECLARE v_id_mesa INT UNSIGNED;
    DECLARE v_tipo VARCHAR(20);
    DECLARE v_existente INT UNSIGNED;
    DECLARE v_pago_comprobante INT UNSIGNED;
    DECLARE v_pago_sesion INT UNSIGNED;
    DECLARE v_pago_usuario INT UNSIGNED;
    DECLARE v_pago_metodo VARCHAR(20);
    DECLARE v_pago_monto DECIMAL(12,2);
    DECLARE v_pago_recibido DECIMAL(12,2);
    DECLARE v_estado_pedido VARCHAR(20);
    DECLARE v_lock_acquired TINYINT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK(CONCAT('sipan_payment_', p_payment_request_id));
        END IF;
        RESIGNAL;
    END;

    SET v_lock_acquired = GET_LOCK(CONCAT('sipan_payment_', p_payment_request_id), 10);
    IF v_lock_acquired IS NULL OR v_lock_acquired <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_IDEMPOTENCY_BUSY';
    END IF;

    START TRANSACTION;
    SET p_replayed = 0;

    SELECT pg.id_pago, pg.id_comprobante, pg.id_caja_sesion, cs.id_usuario, pg.metodo, pg.monto, pg.monto_recibido
    INTO v_existente, v_pago_comprobante, v_pago_sesion, v_pago_usuario, v_pago_metodo, v_pago_monto, v_pago_recibido
    FROM PAGO pg
    INNER JOIN CAJA_SESION cs ON cs.id_caja_sesion = pg.id_caja_sesion
    WHERE pg.payment_request_id = p_payment_request_id
    LIMIT 1
    FOR UPDATE;
    IF v_existente IS NOT NULL THEN
        SET p_replayed = 1;
        IF v_pago_usuario <> p_id_usuario
            OR v_pago_comprobante <> p_id_comprobante
            OR v_pago_sesion <> p_id_caja_sesion
            OR v_pago_metodo <> p_metodo
            OR v_pago_monto <> p_monto
            OR NOT (v_pago_recibido <=> p_monto_recibido) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_REQUEST_REUSED';
        END IF;
        SELECT id_pago, vuelto INTO p_id_pago_out, p_vuelto FROM PAGO WHERE id_pago = v_existente;
        SELECT p.estado INTO p_pedido_estado
        FROM COMPROBANTE c INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
        WHERE c.id_comprobante = v_pago_comprobante;
        COMMIT;
        DO RELEASE_LOCK(CONCAT('sipan_payment_', p_payment_request_id));
        SET v_lock_acquired = 0;
    ELSE
        SELECT estado, id_usuario INTO v_sesion_estado, v_sesion_usuario
        FROM CAJA_SESION WHERE id_caja_sesion = p_id_caja_sesion FOR UPDATE;

        IF v_sesion_estado IS NULL OR v_sesion_estado <> 'ABIERTA' OR v_sesion_usuario <> p_id_usuario THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CASH_SESSION_INVALID';
        END IF;

        SELECT id_pedido INTO v_id_pedido FROM COMPROBANTE WHERE id_comprobante = p_id_comprobante FOR UPDATE;
        IF v_id_pedido IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RECEIPT_NOT_FOUND';
        END IF;

        SELECT estado INTO v_estado_pedido
        FROM PEDIDO WHERE id_pedido = v_id_pedido FOR UPDATE;
        IF v_estado_pedido IS NULL OR v_estado_pedido NOT IN ('ABIERTO', 'EN_PAGO') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_OPEN';
        END IF;

        SELECT estado, tipo INTO v_sesion_estado, v_tipo
        FROM COMPROBANTE
        WHERE id_comprobante = p_id_comprobante;
        IF v_sesion_estado <> 'EMITIDO' OR v_tipo = 'NOTA_CREDITO' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RECEIPT_NOT_PAYABLE';
        END IF;

        SELECT saldo_pendiente, tipo, id_mesa INTO v_saldo, v_tipo, v_id_mesa
        FROM vw_resumen_cuenta_pedido r
        INNER JOIN PEDIDO p ON p.id_pedido = r.id_pedido
        WHERE r.id_pedido = v_id_pedido;

        IF v_saldo IS NULL OR v_saldo <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_OPEN';
        END IF;
        IF p_monto IS NULL OR p_monto <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_AMOUNT_INVALID';
        END IF;
        SET p_vuelto = 0.00;
        IF p_metodo = 'EFECTIVO' THEN
            IF p_monto_recibido IS NULL OR p_monto_recibido < p_monto THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CASH_RECEIVED_INVALID';
            END IF;
            SET p_vuelto = p_monto_recibido - p_monto;
        ELSEIF p_monto_recibido IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CASH_RECEIVED_INVALID';
        END IF;

        IF p_monto > v_saldo + 0.009 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_EXCEEDS_BALANCE';
        END IF;

        INSERT INTO PAGO (
            payment_request_id, id_comprobante, id_caja_sesion, metodo, monto, monto_recibido, vuelto
        ) VALUES (
            p_payment_request_id, p_id_comprobante, p_id_caja_sesion, p_metodo, p_monto, p_monto_recibido, p_vuelto
        );
        SET v_id_pago = LAST_INSERT_ID();

        SELECT saldo_pendiente INTO v_saldo FROM vw_resumen_cuenta_pedido WHERE id_pedido = v_id_pedido;

        SET @sipan_current_user_id = p_id_usuario;
        IF v_saldo <= 0.009 THEN
            UPDATE PEDIDO SET estado = 'PAGADO', version = version + 1 WHERE id_pedido = v_id_pedido;
            SET p_pedido_estado = 'PAGADO';
        ELSE
            UPDATE PEDIDO SET estado = 'EN_PAGO', version = version + 1 WHERE id_pedido = v_id_pedido;
            SET p_pedido_estado = 'EN_PAGO';
        END IF;
        SET @sipan_current_user_id = NULL;

        SET p_id_pago_out = v_id_pago;
        COMMIT;
        DO RELEASE_LOCK(CONCAT('sipan_payment_', p_payment_request_id));
        SET v_lock_acquired = 0;
    END IF;
END$$

CREATE PROCEDURE sp_cerrar_sesion_caja(
    IN p_id_caja_sesion INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    IN p_monto_declarado DECIMAL(12,2),
    IN p_observaciones TEXT,
    OUT p_diferencia DECIMAL(12,2)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_usuario INT UNSIGNED;
    DECLARE v_teorico DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT estado, id_usuario INTO v_estado, v_usuario
    FROM CAJA_SESION WHERE id_caja_sesion = p_id_caja_sesion FOR UPDATE;

    IF v_estado IS NULL OR v_estado <> 'ABIERTA' OR v_usuario <> p_id_usuario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CASH_SESSION_INVALID';
    END IF;

    SELECT saldo_teorico_gaveta
    INTO v_teorico
    FROM vw_arqueo_sesion_caja
    WHERE id_caja_sesion = p_id_caja_sesion;

    SET p_diferencia = p_monto_declarado - v_teorico;

    SET @sipan_current_user_id = p_id_usuario;
    UPDATE CAJA_SESION
    SET estado = 'CERRADA',
        monto_cierre_sistema = v_teorico,
        monto_cierre_declarado = p_monto_declarado,
        cierre_en = NOW(),
        observaciones = p_observaciones
    WHERE id_caja_sesion = p_id_caja_sesion;

    INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario, fecha)
    VALUES (
        'CAJA_SESION',
        CAST(p_id_caja_sesion AS CHAR),
        'U',
        JSON_OBJECT('estado', 'ABIERTA', 'saldo_teorico', v_teorico),
        JSON_OBJECT('estado', 'CERRADA', 'declarado', p_monto_declarado, 'diferencia', p_diferencia),
        p_id_usuario,
        NOW()
    );

    SET @sipan_current_user_id = NULL;
    COMMIT;
END$$

CREATE PROCEDURE sp_listar_pedidos_operativos(
    IN p_id_usuario_filtro INT UNSIGNED,
    IN p_estado VARCHAR(20),
    IN p_tipo VARCHAR(20)
)
BEGIN
    SELECT p.*, m.numero AS numero_mesa
    FROM PEDIDO p
    LEFT JOIN MESA m ON m.id_mesa = p.id_mesa
    WHERE (p_id_usuario_filtro IS NULL OR p.id_usuario = p_id_usuario_filtro)
      AND (p_estado IS NULL OR p.estado = p_estado)
      AND (p_tipo IS NULL OR p.tipo = p_tipo)
    ORDER BY p.id_pedido DESC
    LIMIT 100;
END$$

CREATE PROCEDURE sp_detalle_pedido_operativo(
    IN p_id_pedido INT UNSIGNED,
    IN p_id_usuario_filtro INT UNSIGNED
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO v_existe
    FROM PEDIDO
    WHERE id_pedido = p_id_pedido
      AND (p_id_usuario_filtro IS NULL OR id_usuario = p_id_usuario_filtro);

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_FOUND';
    END IF;

    SELECT
        p.*,
        m.numero AS numero_mesa,
        r.subtotal_items, r.subtotal_modificadores, r.base_imponible, r.impuestos,
        r.total, r.total_pagado, r.saldo_pendiente,
        c.id_comanda, c.numero_ronda,
        c.client_request_id AS ronda_client_request_id,
        c.request_hash AS ronda_request_hash,
        c.enviado_en,
        d.id_detalle, d.id_producto, d.id_variante, d.nombre_snapshot,
        d.precio_unitario_venta, d.id_estacion_cocina, d.cantidad, d.estado_item,
        d.prioridad, d.nota, d.iniciado_en, d.listo_en, d.entregado_en,
        d.motivo_cancelacion
    FROM PEDIDO p
    LEFT JOIN MESA m ON m.id_mesa = p.id_mesa
    LEFT JOIN vw_resumen_cuenta_pedido r ON r.id_pedido = p.id_pedido
    LEFT JOIN COMANDA c ON c.id_pedido = p.id_pedido
    LEFT JOIN DETALLE_COMANDA d ON d.id_comanda = c.id_comanda
    WHERE p.id_pedido = p_id_pedido
    ORDER BY c.numero_ronda, d.id_detalle;
END$$

CREATE PROCEDURE sp_marcar_item_entregado(
    IN p_id_detalle INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    OUT p_estado_item_out VARCHAR(20)
)
BEGIN
    DECLARE v_estado_item VARCHAR(20);
    DECLARE v_id_usuario_pedido INT UNSIGNED;
    DECLARE v_encontrado TINYINT DEFAULT 1;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_encontrado = 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT d.estado_item, p.id_usuario
    INTO v_estado_item, v_id_usuario_pedido
    FROM DETALLE_COMANDA d
    INNER JOIN COMANDA c ON c.id_comanda = d.id_comanda
    INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
    WHERE d.id_detalle = p_id_detalle
    FOR UPDATE;

    IF v_encontrado = 0 OR v_id_usuario_pedido <> p_id_usuario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_NOT_FOUND';
    END IF;
    IF v_estado_item = 'ENTREGADO' THEN
        SET p_estado_item_out = 'ENTREGADO';
        COMMIT;
    ELSEIF v_estado_item <> 'LISTO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'INVALID_ITEM_TRANSITION';
    ELSE
        SET @sipan_current_user_id = p_id_usuario;
        UPDATE DETALLE_COMANDA
        SET estado_item = 'ENTREGADO', entregado_en = NOW()
        WHERE id_detalle = p_id_detalle;
        INSERT INTO HISTORIAL_ESTADO (
            entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, fecha
        ) VALUES (
            'DETALLE_COMANDA', p_id_detalle, 'LISTO', 'ENTREGADO', p_id_usuario, NOW()
        );
        SET @sipan_current_user_id = NULL;
        SET p_estado_item_out = 'ENTREGADO';
        COMMIT;
    END IF;
END$$

CREATE PROCEDURE sp_cancelar_pedido_mesero(
    IN p_id_pedido INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    IN p_motivo VARCHAR(250),
    OUT p_estado_pedido_out VARCHAR(20)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_id_usuario_pedido INT UNSIGNED;
    DECLARE v_encontrado TINYINT DEFAULT 1;
    DECLARE v_items_en_preparacion INT DEFAULT 0;
    DECLARE v_comprobantes_o_pagos INT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_encontrado = 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_motivo IS NULL OR CHAR_LENGTH(TRIM(p_motivo)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_CANCELLATION_REASON_REQUIRED';
    END IF;

    START TRANSACTION;
    SELECT estado, id_usuario
    INTO v_estado, v_id_usuario_pedido
    FROM PEDIDO
    WHERE id_pedido = p_id_pedido
    FOR UPDATE;

    IF v_encontrado = 0 OR v_id_usuario_pedido <> p_id_usuario THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_FOUND';
    END IF;
    IF v_estado <> 'ABIERTO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_CANCELLABLE';
    END IF;

    SELECT COUNT(*) INTO v_items_en_preparacion
    FROM DETALLE_COMANDA d
    INNER JOIN COMANDA c ON c.id_comanda = d.id_comanda
    WHERE c.id_pedido = p_id_pedido
      AND d.estado_item NOT IN ('PENDIENTE', 'CANCELADO');
    IF v_items_en_preparacion > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_HAS_PREPARATION';
    END IF;

    SELECT COUNT(*) INTO v_comprobantes_o_pagos
    FROM COMPROBANTE co
    LEFT JOIN PAGO pg ON pg.id_comprobante = co.id_comprobante
    WHERE co.id_pedido = p_id_pedido
      AND (co.estado = 'EMITIDO' OR pg.id_pago IS NOT NULL);
    IF v_comprobantes_o_pagos > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_HAS_PAYMENT';
    END IF;

    SET @sipan_current_user_id = p_id_usuario;
    INSERT INTO HISTORIAL_ESTADO (
        entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, fecha
    )
    SELECT
        'DETALLE_COMANDA', d.id_detalle, d.estado_item, 'CANCELADO', p_id_usuario, NOW()
    FROM DETALLE_COMANDA d
    INNER JOIN COMANDA c ON c.id_comanda = d.id_comanda
    WHERE c.id_pedido = p_id_pedido AND d.estado_item = 'PENDIENTE';

    UPDATE DETALLE_COMANDA d
    INNER JOIN COMANDA c ON c.id_comanda = d.id_comanda
    SET d.estado_item = 'CANCELADO', d.motivo_cancelacion = TRIM(p_motivo)
    WHERE c.id_pedido = p_id_pedido AND d.estado_item = 'PENDIENTE';

    UPDATE PEDIDO
    SET estado = 'ANULADO', version = version + 1
    WHERE id_pedido = p_id_pedido;
    SET @sipan_current_user_id = NULL;
    SET p_estado_pedido_out = 'ANULADO';
    COMMIT;
END$$

CREATE PROCEDURE sp_buscar_clientes_delivery(IN p_busqueda VARCHAR(120))
BEGIN
    SELECT
        c.id_cliente, c.nombre, c.telefono,
        d.id_direccion, d.linea_direccion, d.distrito
    FROM CLIENTE c
    INNER JOIN DIRECCION_CLIENTE d ON d.id_direccion = c.id_direccion
    WHERE p_busqueda IS NOT NULL
      AND CHAR_LENGTH(TRIM(p_busqueda)) >= 2
      AND (
          LOWER(c.nombre) LIKE CONCAT('%', LOWER(TRIM(p_busqueda)), '%')
          OR c.telefono LIKE CONCAT('%', TRIM(p_busqueda), '%')
          OR c.numero_documento LIKE CONCAT('%', TRIM(p_busqueda), '%')
      )
    ORDER BY c.nombre
    LIMIT 30;
END$$

CREATE PROCEDURE sp_historial_pagos_pedido(
    IN p_id_pedido INT UNSIGNED,
    IN p_id_usuario_filtro INT UNSIGNED
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    SELECT COUNT(*) INTO v_existe
    FROM PEDIDO
    WHERE id_pedido = p_id_pedido
      AND (p_id_usuario_filtro IS NULL OR id_usuario = p_id_usuario_filtro);
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ORDER_NOT_FOUND';
    END IF;

    SELECT pg.id_pago, pg.metodo, pg.monto, pg.created_at
    FROM PAGO pg
    INNER JOIN COMPROBANTE co ON co.id_comprobante = pg.id_comprobante
    WHERE co.id_pedido = p_id_pedido AND co.estado = 'EMITIDO'
    ORDER BY pg.created_at, pg.id_pago;
END$$

DELIMITER ;
