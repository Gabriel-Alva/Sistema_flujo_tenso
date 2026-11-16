DROP TRIGGER IF EXISTS trg_detalle_comanda_before_update;
DROP TRIGGER IF EXISTS trg_detalle_comanda_before_delete;
DROP TRIGGER IF EXISTS trg_producto_after_update;
DROP TRIGGER IF EXISTS trg_plato_after_update;
DROP TRIGGER IF EXISTS trg_variante_after_update;
DROP TRIGGER IF EXISTS trg_modificador_after_update;
DROP TRIGGER IF EXISTS trg_categoria_after_update;
DROP TRIGGER IF EXISTS trg_estacion_after_update;
DROP TRIGGER IF EXISTS trg_producto_estacion_after_update;
DROP TRIGGER IF EXISTS trg_prioridad_after_update;
DROP TRIGGER IF EXISTS trg_usuario_after_update;
DROP TRIGGER IF EXISTS trg_parametro_after_update;
DROP TRIGGER IF EXISTS trg_pedido_after_insert;
DROP TRIGGER IF EXISTS trg_pedido_after_update;
DROP TRIGGER IF EXISTS trg_auditoria_no_update;
DROP TRIGGER IF EXISTS trg_auditoria_no_delete;
DROP TRIGGER IF EXISTS trg_historial_no_update;
DROP TRIGGER IF EXISTS trg_historial_no_delete;
DROP TRIGGER IF EXISTS trg_pago_no_update;
DROP TRIGGER IF EXISTS trg_pago_no_delete;
DROP TRIGGER IF EXISTS trg_comprobante_no_update;
DROP TRIGGER IF EXISTS trg_comprobante_no_delete;

DELIMITER $$

CREATE TRIGGER trg_detalle_comanda_before_update
BEFORE UPDATE ON DETALLE_COMANDA
FOR EACH ROW
BEGIN
    IF NEW.precio_unitario_venta <> OLD.precio_unitario_venta
        OR NEW.nombre_snapshot <> OLD.nombre_snapshot
        OR NOT (NEW.id_producto <=> OLD.id_producto)
        OR NOT (NEW.id_variante <=> OLD.id_variante)
        OR NEW.cantidad <> OLD.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_FINANCIAL_IMMUTABLE';
    END IF;
    IF NEW.estado_item = 'CANCELADO' AND (NEW.motivo_cancelacion IS NULL OR NEW.motivo_cancelacion = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_CANCEL_REASON_REQUIRED';
    END IF;
END$$

CREATE TRIGGER trg_detalle_comanda_before_delete
BEFORE DELETE ON DETALLE_COMANDA
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ITEM_DELETE_FORBIDDEN';
END$$

CREATE TRIGGER trg_producto_after_update
AFTER UPDATE ON PRODUCTO
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre)
        OR NOT (NEW.descripcion <=> OLD.descripcion)
        OR NEW.requiere_preparacion <> OLD.requiere_preparacion
        OR NEW.precio_actual <> OLD.precio_actual
        OR NEW.tiempo_prep_min <> OLD.tiempo_prep_min
        OR NOT (NEW.imagen_url <=> OLD.imagen_url)
        OR NEW.activo <> OLD.activo THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario, fecha)
        VALUES (
            'PRODUCTO',
            OLD.id_producto,
            'U',
            JSON_OBJECT(
                'nombre', OLD.nombre, 'descripcion', OLD.descripcion,
                'requiere_preparacion', OLD.requiere_preparacion,
                'precio_actual', OLD.precio_actual, 'tiempo_prep_min', OLD.tiempo_prep_min,
                'imagen_url', OLD.imagen_url, 'activo', OLD.activo
            ),
            JSON_OBJECT(
                'nombre', NEW.nombre, 'descripcion', NEW.descripcion,
                'requiere_preparacion', NEW.requiere_preparacion,
                'precio_actual', NEW.precio_actual, 'tiempo_prep_min', NEW.tiempo_prep_min,
                'imagen_url', NEW.imagen_url, 'activo', NEW.activo
            ),
            @sipan_current_user_id,
            NOW()
        );
    END IF;
END$$

CREATE TRIGGER trg_plato_after_update
AFTER UPDATE ON PLATO
FOR EACH ROW
BEGIN
    IF NEW.id_categoria <> OLD.id_categoria OR NOT (NEW.porcion <=> OLD.porcion) THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'PLATO', OLD.id_producto, 'U',
            JSON_OBJECT('id_categoria', OLD.id_categoria, 'porcion', OLD.porcion),
            JSON_OBJECT('id_categoria', NEW.id_categoria, 'porcion', NEW.porcion),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_variante_after_update
AFTER UPDATE ON PLATO_VARIANTE
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre) OR NEW.precio <> OLD.precio OR NEW.activo <> OLD.activo THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'PLATO_VARIANTE', CAST(OLD.id_variante AS CHAR), 'U',
            JSON_OBJECT('id_plato', OLD.id_plato, 'nombre', OLD.nombre, 'precio', OLD.precio, 'activo', OLD.activo),
            JSON_OBJECT('id_plato', NEW.id_plato, 'nombre', NEW.nombre, 'precio', NEW.precio, 'activo', NEW.activo),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_modificador_after_update
AFTER UPDATE ON MODIFICADOR
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre) OR NEW.precio_extra <> OLD.precio_extra OR NEW.activo <> OLD.activo THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'MODIFICADOR', CAST(OLD.id_modificador AS CHAR), 'U',
            JSON_OBJECT('nombre', OLD.nombre, 'precio_extra', OLD.precio_extra, 'activo', OLD.activo),
            JSON_OBJECT('nombre', NEW.nombre, 'precio_extra', NEW.precio_extra, 'activo', NEW.activo),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_categoria_after_update
AFTER UPDATE ON CATEGORIA_PLATO
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre) OR NEW.activa <> OLD.activa THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'CATEGORIA_PLATO', CAST(OLD.id_categoria AS CHAR), 'U',
            JSON_OBJECT('nombre', OLD.nombre, 'activa', OLD.activa),
            JSON_OBJECT('nombre', NEW.nombre, 'activa', NEW.activa),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_estacion_after_update
AFTER UPDATE ON ESTACION_COCINA
FOR EACH ROW
BEGIN
    IF NOT (NEW.nombre <=> OLD.nombre) OR NEW.activa <> OLD.activa THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'ESTACION_COCINA', CAST(OLD.id_estacion AS CHAR), 'U',
            JSON_OBJECT('nombre', OLD.nombre, 'activa', OLD.activa),
            JSON_OBJECT('nombre', NEW.nombre, 'activa', NEW.activa),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_producto_estacion_after_update
AFTER UPDATE ON PRODUCTO_ESTACION
FOR EACH ROW
BEGIN
    IF NEW.es_principal <> OLD.es_principal THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'PRODUCTO_ESTACION', CONCAT(OLD.id_producto, ':', OLD.id_estacion), 'U',
            JSON_OBJECT('es_principal', OLD.es_principal),
            JSON_OBJECT('es_principal', NEW.es_principal),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_prioridad_after_update
AFTER UPDATE ON PRIORIDAD
FOR EACH ROW
BEGIN
    IF NOT (NEW.prioridad <=> OLD.prioridad)
        OR NOT (NEW.color_hex <=> OLD.color_hex)
        OR NEW.activa <> OLD.activa THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario)
        VALUES (
            'PRIORIDAD', OLD.id_prioridad, 'U',
            JSON_OBJECT('prioridad', OLD.prioridad, 'color_hex', OLD.color_hex, 'activa', OLD.activa),
            JSON_OBJECT('prioridad', NEW.prioridad, 'color_hex', NEW.color_hex, 'activa', NEW.activa),
            @sipan_current_user_id
        );
    END IF;
END$$

CREATE TRIGGER trg_usuario_after_update
AFTER UPDATE ON USUARIO
FOR EACH ROW
BEGIN
    IF NOT (NEW.bloqueado_hasta <=> OLD.bloqueado_hasta) OR NEW.activo <> OLD.activo THEN
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, id_usuario, fecha)
        VALUES (
            'USUARIO',
            CAST(OLD.id_usuario AS CHAR),
            'U',
            JSON_OBJECT('activo', OLD.activo, 'bloqueado_hasta', OLD.bloqueado_hasta),
            JSON_OBJECT('activo', NEW.activo, 'bloqueado_hasta', NEW.bloqueado_hasta),
            @sipan_current_user_id,
            NOW()
        );
    END IF;
END$$

CREATE TRIGGER trg_parametro_after_update
AFTER UPDATE ON PARAMETRO_SISTEMA
FOR EACH ROW
BEGIN
    INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, datos_despues, fecha, id_usuario)
    VALUES (
        'PARAMETRO_SISTEMA',
        OLD.clave,
        'U',
        JSON_OBJECT('valor', OLD.valor),
        JSON_OBJECT('valor', NEW.valor),
        NOW(),
        @sipan_current_user_id
    );
END$$

CREATE TRIGGER trg_pedido_after_insert
AFTER INSERT ON PEDIDO
FOR EACH ROW
BEGIN
    IF NEW.tipo = 'SALON' AND NEW.id_mesa IS NOT NULL THEN
        UPDATE MESA SET estado = 'OCUPADA' WHERE id_mesa = NEW.id_mesa;
    END IF;
    INSERT INTO HISTORIAL_ESTADO (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario)
    VALUES ('PEDIDO', NEW.id_pedido, NULL, NEW.estado, NEW.id_usuario);
END$$

CREATE TRIGGER trg_pedido_after_update
AFTER UPDATE ON PEDIDO
FOR EACH ROW
BEGIN
    DECLARE v_otros INT DEFAULT 0;
    IF NEW.estado <> OLD.estado THEN
        INSERT INTO HISTORIAL_ESTADO (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario)
        VALUES ('PEDIDO', NEW.id_pedido, OLD.estado, NEW.estado, @sipan_current_user_id);
    END IF;
    IF NEW.tipo = 'SALON' AND NEW.id_mesa IS NOT NULL AND NEW.estado IN ('PAGADO', 'ANULADO') THEN
        SELECT COUNT(*) INTO v_otros
        FROM PEDIDO
        WHERE id_mesa = NEW.id_mesa
          AND id_pedido <> NEW.id_pedido
          AND estado IN ('ABIERTO', 'EN_PAGO');
        IF v_otros = 0 THEN
            UPDATE MESA SET estado = 'LIBRE' WHERE id_mesa = NEW.id_mesa;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_auditoria_no_update
BEFORE UPDATE ON AUDITORIA
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_APPEND_ONLY';
END$$

CREATE TRIGGER trg_auditoria_no_delete
BEFORE DELETE ON AUDITORIA
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_APPEND_ONLY';
END$$

CREATE TRIGGER trg_historial_no_update
BEFORE UPDATE ON HISTORIAL_ESTADO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HISTORY_APPEND_ONLY';
END$$

CREATE TRIGGER trg_historial_no_delete
BEFORE DELETE ON HISTORIAL_ESTADO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HISTORY_APPEND_ONLY';
END$$

CREATE TRIGGER trg_pago_no_update
BEFORE UPDATE ON PAGO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_APPEND_ONLY';
END$$

CREATE TRIGGER trg_pago_no_delete
BEFORE DELETE ON PAGO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PAYMENT_APPEND_ONLY';
END$$

CREATE TRIGGER trg_comprobante_no_update
BEFORE UPDATE ON COMPROBANTE
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RECEIPT_APPEND_ONLY';
END$$

CREATE TRIGGER trg_comprobante_no_delete
BEFORE DELETE ON COMPROBANTE
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RECEIPT_APPEND_ONLY';
END$$

DELIMITER ;
