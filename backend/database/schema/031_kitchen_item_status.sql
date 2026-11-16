DROP PROCEDURE IF EXISTS sp_kitchen_update_item_status;
DROP PROCEDURE IF EXISTS sp_kitchen_cancel_command;

DELIMITER $$

CREATE PROCEDURE sp_kitchen_update_item_status(
    IN p_id_detalle INT UNSIGNED,
    IN p_estado_item VARCHAR(20),
    IN p_id_usuario INT UNSIGNED,
    IN p_id_estacion SMALLINT UNSIGNED,
    IN p_motivo VARCHAR(250)
)
BEGIN
    DECLARE v_estado_actual VARCHAR(20);
    DECLARE v_id_estacion SMALLINT UNSIGNED;
    DECLARE v_motivo_actual VARCHAR(250);
    DECLARE v_id_comanda INT UNSIGNED;
    DECLARE v_encontrado TINYINT DEFAULT 1;
    DECLARE v_fecha DATETIME;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_encontrado = 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_estado_item = 'CANCELADO'
        AND (p_motivo IS NULL OR CHAR_LENGTH(TRIM(p_motivo)) < 3) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_CANCEL_REASON_REQUIRED';
    END IF;

    START TRANSACTION;
    SELECT id_comanda
    INTO v_id_comanda
    FROM DETALLE_COMANDA
    WHERE id_detalle = p_id_detalle;

    IF v_encontrado = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_NOT_FOUND';
    END IF;

    SET v_encontrado = 1;
    SELECT id_comanda
    INTO v_id_comanda
    FROM COMANDA
    WHERE id_comanda = v_id_comanda
    FOR UPDATE;

    IF v_encontrado = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_NOT_FOUND';
    END IF;

    SET v_encontrado = 1;
    SELECT estado_item, id_estacion_cocina, motivo_cancelacion
    INTO v_estado_actual, v_id_estacion, v_motivo_actual
    FROM DETALLE_COMANDA
    WHERE id_detalle = p_id_detalle
    FOR UPDATE;

    IF v_encontrado = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_NOT_FOUND';
    END IF;
    IF p_id_estacion IS NOT NULL AND NOT (v_id_estacion <=> p_id_estacion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FORBIDDEN_STATION';
    END IF;
    IF NOT (
        (p_estado_item = 'EN_PREPARACION' AND v_estado_actual = 'PENDIENTE')
        OR (p_estado_item = 'LISTO' AND v_estado_actual = 'EN_PREPARACION')
        OR (
            p_estado_item = 'CANCELADO'
            AND v_estado_actual IN ('PENDIENTE', 'EN_PREPARACION')
        )
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'INVALID_ITEM_TRANSITION';
    END IF;

    SET v_fecha = NOW();
    SET @sipan_current_user_id = p_id_usuario;
    IF p_estado_item = 'EN_PREPARACION' THEN
        UPDATE DETALLE_COMANDA
        SET estado_item = p_estado_item, iniciado_en = v_fecha
        WHERE id_detalle = p_id_detalle;
    ELSEIF p_estado_item = 'LISTO' THEN
        UPDATE DETALLE_COMANDA
        SET estado_item = p_estado_item, listo_en = v_fecha
        WHERE id_detalle = p_id_detalle;
    ELSE
        UPDATE DETALLE_COMANDA
        SET estado_item = p_estado_item, motivo_cancelacion = TRIM(p_motivo)
        WHERE id_detalle = p_id_detalle;

        INSERT INTO AUDITORIA (
            tabla, id_registro, accion, datos_antes, datos_despues, id_usuario, fecha
        ) VALUES (
            'DETALLE_COMANDA',
            CAST(p_id_detalle AS CHAR),
            'U',
            JSON_OBJECT('estado_item', v_estado_actual, 'motivo_cancelacion', v_motivo_actual),
            JSON_OBJECT('estado_item', p_estado_item, 'motivo_cancelacion', TRIM(p_motivo)),
            p_id_usuario,
            v_fecha
        );
    END IF;

    INSERT INTO HISTORIAL_ESTADO (
        entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, fecha
    ) VALUES (
        'DETALLE_COMANDA', p_id_detalle, v_estado_actual, p_estado_item, p_id_usuario, v_fecha
    );

    SET @sipan_current_user_id = NULL;
    COMMIT;
END$$

CREATE PROCEDURE sp_kitchen_cancel_command(
    IN p_id_comanda INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    IN p_id_estacion SMALLINT UNSIGNED,
    IN p_motivo VARCHAR(250)
)
BEGIN
    DECLARE v_encontrado TINYINT DEFAULT 1;
    DECLARE v_id_comanda INT UNSIGNED;
    DECLARE v_items_estacion INT UNSIGNED DEFAULT 0;
    DECLARE v_items_pendientes INT UNSIGNED DEFAULT 0;
    DECLARE v_items_no_pendientes INT UNSIGNED DEFAULT 0;
    DECLARE v_fecha DATETIME;
    DECLARE v_actualizados INT UNSIGNED DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_encontrado = 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_motivo IS NULL OR CHAR_LENGTH(TRIM(p_motivo)) < 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COMMAND_CANCEL_REASON_REQUIRED';
    END IF;
    IF p_id_estacion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FORBIDDEN_STATION';
    END IF;

    START TRANSACTION;
    SELECT id_comanda
    INTO v_id_comanda
    FROM COMANDA
    WHERE id_comanda = p_id_comanda
    FOR UPDATE;

    IF v_encontrado = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COMMAND_NOT_FOUND';
    END IF;

    SELECT COUNT(*)
    INTO v_items_estacion
    FROM DETALLE_COMANDA
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion;

    IF v_items_estacion = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FORBIDDEN_STATION';
    END IF;

    SELECT COUNT(*)
    INTO v_items_no_pendientes
    FROM DETALLE_COMANDA
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion
      AND estado_item NOT IN ('PENDIENTE', 'CANCELADO');

    IF v_items_no_pendientes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COMMAND_CANCEL_NOT_ALLOWED';
    END IF;

    SELECT COUNT(*)
    INTO v_items_pendientes
    FROM DETALLE_COMANDA
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion
      AND estado_item = 'PENDIENTE';

    IF v_items_pendientes = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COMMAND_NO_PENDING_ITEMS';
    END IF;

    SET v_fecha = NOW();
    SET @sipan_current_user_id = p_id_usuario;

    INSERT INTO HISTORIAL_ESTADO (
        entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, fecha
    )
    SELECT
        'DETALLE_COMANDA', id_detalle, estado_item, 'CANCELADO', p_id_usuario, v_fecha
    FROM DETALLE_COMANDA
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion
      AND estado_item = 'PENDIENTE';

    INSERT INTO AUDITORIA (
        tabla, id_registro, accion, datos_antes, datos_despues, id_usuario, fecha
    )
    SELECT
        'DETALLE_COMANDA',
        CAST(id_detalle AS CHAR),
        'U',
        JSON_OBJECT('estado_item', estado_item, 'motivo_cancelacion', motivo_cancelacion),
        JSON_OBJECT('estado_item', 'CANCELADO', 'motivo_cancelacion', TRIM(p_motivo)),
        p_id_usuario,
        v_fecha
    FROM DETALLE_COMANDA
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion
      AND estado_item = 'PENDIENTE';

    UPDATE DETALLE_COMANDA
    SET estado_item = 'CANCELADO',
        motivo_cancelacion = TRIM(p_motivo)
    WHERE id_comanda = p_id_comanda
      AND id_estacion_cocina = p_id_estacion
      AND estado_item = 'PENDIENTE';

    SET v_actualizados = ROW_COUNT();
    IF v_actualizados <> v_items_pendientes THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'COMMAND_CANCEL_NOT_ALLOWED';
    END IF;

    SET @sipan_current_user_id = NULL;
    COMMIT;
END$$

DELIMITER ;
