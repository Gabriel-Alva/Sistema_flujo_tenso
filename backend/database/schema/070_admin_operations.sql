DROP PROCEDURE IF EXISTS sp_admin_dashboard;
DROP PROCEDURE IF EXISTS sp_admin_dashboard_graficos;
DROP PROCEDURE IF EXISTS sp_admin_listar_parametros;
DROP PROCEDURE IF EXISTS sp_admin_actualizar_parametro;
DROP PROCEDURE IF EXISTS sp_admin_listar_categorias;
DROP PROCEDURE IF EXISTS sp_admin_listar_estaciones;
DROP PROCEDURE IF EXISTS sp_admin_listar_modificadores;
DROP PROCEDURE IF EXISTS sp_admin_listar_prioridades;
DROP PROCEDURE IF EXISTS sp_admin_guardar_categoria;
DROP PROCEDURE IF EXISTS sp_admin_guardar_estacion;
DROP PROCEDURE IF EXISTS sp_admin_guardar_modificador;
DROP PROCEDURE IF EXISTS sp_admin_guardar_prioridad;
DROP PROCEDURE IF EXISTS sp_admin_listar_catalogo;
DROP PROCEDURE IF EXISTS sp_admin_listar_variantes;
DROP PROCEDURE IF EXISTS sp_admin_guardar_producto;
DROP PROCEDURE IF EXISTS sp_admin_guardar_variante;
DROP PROCEDURE IF EXISTS sp_admin_estado_producto;
DROP PROCEDURE IF EXISTS sp_admin_listar_personal;
DROP PROCEDURE IF EXISTS sp_admin_crear_usuario;
DROP PROCEDURE IF EXISTS sp_admin_estado_usuario;
DROP PROCEDURE IF EXISTS sp_admin_listar_zonas;
DROP PROCEDURE IF EXISTS sp_admin_listar_mesas;
DROP PROCEDURE IF EXISTS sp_admin_guardar_zona;
DROP PROCEDURE IF EXISTS sp_admin_guardar_mesa;
DROP PROCEDURE IF EXISTS sp_admin_resumen_financiero;
DROP PROCEDURE IF EXISTS sp_admin_listar_comprobantes;
DROP PROCEDURE IF EXISTS sp_admin_saldos_pendientes;
DROP PROCEDURE IF EXISTS sp_admin_reporte_ventas;
DROP PROCEDURE IF EXISTS sp_admin_sesiones_caja;
DROP PROCEDURE IF EXISTS sp_admin_listar_auditoria;
DROP FUNCTION IF EXISTS fn_admin_saldo_pedido;

DELIMITER $$

CREATE FUNCTION fn_admin_saldo_pedido(p_id_pedido INT UNSIGNED)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(12,2) DEFAULT NULL;

    SELECT saldo_pendiente
    INTO v_saldo
    FROM vw_resumen_cuenta_pedido
    WHERE id_pedido = p_id_pedido;

    RETURN v_saldo;
END$$

CREATE PROCEDURE sp_admin_dashboard()
BEGIN
    SELECT
        (SELECT COUNT(*) FROM MESA WHERE estado = 'OCUPADA' AND activa = 1) AS mesas_ocupadas,
        (SELECT COUNT(*) FROM vw_cola_cocina_activa) AS items_cocina,
        (SELECT COUNT(*) FROM CAJA_SESION WHERE estado = 'ABIERTA') AS cajas_abiertas,
        (SELECT COUNT(*) FROM PEDIDO WHERE estado IN ('ABIERTO', 'EN_PAGO')) AS pedidos_abiertos,
        (SELECT COUNT(*) FROM PEDIDO WHERE fecha >= CURRENT_DATE()) AS pedidos_hoy,
        (SELECT COALESCE(SUM(total), 0)
         FROM COMPROBANTE
         WHERE estado = 'EMITIDO' AND created_at >= CURRENT_DATE()) AS venta_hoy;
END$$

CREATE PROCEDURE sp_admin_dashboard_graficos()
BEGIN
    SELECT
        'VENTAS' AS tipo,
        DATE_FORMAT(f.fecha, '%Y-%m-%d') AS etiqueta,
        COALESCE(SUM(c.total), 0.00) AS valor
    FROM (
        SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY) AS fecha
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 4 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
        UNION ALL SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        UNION ALL SELECT CURRENT_DATE()
    ) AS f
    LEFT JOIN COMPROBANTE c
        ON c.estado = 'EMITIDO'
        AND c.created_at >= f.fecha
        AND c.created_at < DATE_ADD(f.fecha, INTERVAL 1 DAY)
    GROUP BY f.fecha

    UNION ALL

    SELECT
        'PEDIDOS' AS tipo,
        estados.estado AS etiqueta,
        COUNT(p.id_pedido) AS valor
    FROM (
        SELECT 'ABIERTO' AS estado
        UNION ALL SELECT 'EN_PAGO'
        UNION ALL SELECT 'PAGADO'
        UNION ALL SELECT 'ANULADO'
    ) AS estados
    LEFT JOIN PEDIDO p
        ON p.estado = estados.estado
        AND p.fecha >= CURRENT_DATE()
        AND p.fecha < DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)
    GROUP BY estados.estado
    ORDER BY tipo, etiqueta;
END$$

CREATE PROCEDURE sp_admin_listar_parametros()
BEGIN
    SELECT clave, valor, descripcion, updated_at
    FROM PARAMETRO_SISTEMA
    ORDER BY clave;
END$$

CREATE PROCEDURE sp_admin_actualizar_parametro(
    IN p_actor INT UNSIGNED,
    IN p_clave VARCHAR(60),
    IN p_valor VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    IF p_valor IS NULL OR CHAR_LENGTH(TRIM(p_valor)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PARAMETER_VALUE_INVALID';
    END IF;
    IF p_clave = 'IGV' AND (
        TRIM(p_valor) NOT REGEXP '^[0-9]+([.][0-9]{1,2})?$'
        OR CAST(TRIM(p_valor) AS DECIMAL(8,2)) > 100
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PARAMETER_VALUE_INVALID';
    END IF;
    IF p_clave = 'ruc' AND TRIM(p_valor) NOT REGEXP '^[0-9]{11}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PARAMETER_VALUE_INVALID';
    END IF;
    IF LEFT(p_clave, 6) = 'serie_' AND TRIM(p_valor) NOT REGEXP '^[A-Za-z0-9]{4}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PARAMETER_VALUE_INVALID';
    END IF;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    SELECT COUNT(*) INTO v_existe
    FROM PARAMETRO_SISTEMA
    WHERE clave = p_clave;

    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PARAMETER_NOT_FOUND';
    END IF;

    UPDATE PARAMETRO_SISTEMA
    SET valor = TRIM(p_valor)
    WHERE clave = p_clave AND valor <> TRIM(p_valor);
    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_listar_categorias()
BEGIN
    SELECT id_categoria, nombre, activa
    FROM CATEGORIA_PLATO
    ORDER BY nombre;
END$$

CREATE PROCEDURE sp_admin_listar_estaciones()
BEGIN
    SELECT id_estacion, nombre, activa
    FROM ESTACION_COCINA
    ORDER BY nombre;
END$$

CREATE PROCEDURE sp_admin_listar_modificadores()
BEGIN
    SELECT id_modificador, nombre, precio_extra, activo
    FROM MODIFICADOR
    ORDER BY nombre;
END$$

CREATE PROCEDURE sp_admin_listar_prioridades()
BEGIN
    SELECT id_prioridad, prioridad, color_hex, activa
    FROM PRIORIDAD
    ORDER BY prioridad;
END$$

CREATE PROCEDURE sp_admin_guardar_categoria(
    IN p_actor INT UNSIGNED,
    IN p_id_categoria SMALLINT UNSIGNED,
    IN p_nombre VARCHAR(60),
    IN p_activa TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_productos_activos INT DEFAULT 0;
    DECLARE v_id SMALLINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    IF p_id_categoria IS NULL THEN
        INSERT INTO CATEGORIA_PLATO (nombre, activa) VALUES (p_nombre, p_activa);
        SET v_id = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES ('CATEGORIA_PLATO', CAST(v_id AS CHAR), 'I', JSON_OBJECT('nombre', p_nombre, 'activa', p_activa), p_actor);
    ELSE
        SELECT COUNT(*) INTO v_existe FROM CATEGORIA_PLATO WHERE id_categoria = p_id_categoria;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_CATEGORY_NOT_FOUND';
        END IF;
        IF p_activa = 0 THEN
            SELECT COUNT(*) INTO v_productos_activos
            FROM PLATO pl
            INNER JOIN PRODUCTO pr ON pr.id_producto = pl.id_producto
            WHERE pl.id_categoria = p_id_categoria AND pr.activo = 1;
            IF v_productos_activos > 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_CATEGORY_HAS_ACTIVE_PRODUCTS';
            END IF;
        END IF;
        UPDATE CATEGORIA_PLATO SET nombre = p_nombre, activa = p_activa
        WHERE id_categoria = p_id_categoria;
    END IF;
    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_guardar_estacion(
    IN p_actor INT UNSIGNED,
    IN p_id_estacion SMALLINT UNSIGNED,
    IN p_nombre VARCHAR(50),
    IN p_activa TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_en_uso INT DEFAULT 0;
    DECLARE v_id SMALLINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    IF p_id_estacion IS NULL THEN
        INSERT INTO ESTACION_COCINA (nombre, activa) VALUES (p_nombre, p_activa);
        SET v_id = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES ('ESTACION_COCINA', CAST(v_id AS CHAR), 'I', JSON_OBJECT('nombre', p_nombre, 'activa', p_activa), p_actor);
    ELSE
        SELECT COUNT(*) INTO v_existe FROM ESTACION_COCINA WHERE id_estacion = p_id_estacion;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_STATION_NOT_FOUND';
        END IF;
        IF p_activa = 0 THEN
            SELECT COUNT(*) INTO v_en_uso
            FROM PRODUCTO_ESTACION pe
            INNER JOIN PRODUCTO pr ON pr.id_producto = pe.id_producto
            WHERE pe.id_estacion = p_id_estacion AND pr.activo = 1;
            IF v_en_uso > 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_STATION_IN_USE';
            END IF;
            SELECT COUNT(*) INTO v_en_uso
            FROM COCINERO co
            INNER JOIN USUARIO u ON u.id_persona = co.id_persona
            WHERE co.id_estacion = p_id_estacion AND u.activo = 1;
            IF v_en_uso > 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_STATION_IN_USE';
            END IF;
        END IF;
        UPDATE ESTACION_COCINA SET nombre = p_nombre, activa = p_activa
        WHERE id_estacion = p_id_estacion;
    END IF;
    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_guardar_modificador(
    IN p_actor INT UNSIGNED,
    IN p_id_modificador INT UNSIGNED,
    IN p_nombre VARCHAR(80),
    IN p_precio_extra DECIMAL(10,2),
    IN p_activo TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_id INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    IF p_precio_extra < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_VALUE_INVALID';
    END IF;
    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    IF p_id_modificador IS NULL THEN
        INSERT INTO MODIFICADOR (nombre, precio_extra, activo)
        VALUES (p_nombre, p_precio_extra, p_activo);
        SET v_id = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'MODIFICADOR', CAST(v_id AS CHAR), 'I',
            JSON_OBJECT('nombre', p_nombre, 'precio_extra', p_precio_extra, 'activo', p_activo),
            p_actor
        );
    ELSE
        SELECT COUNT(*) INTO v_existe FROM MODIFICADOR WHERE id_modificador = p_id_modificador;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_MODIFIER_NOT_FOUND';
        END IF;
        UPDATE MODIFICADOR
        SET nombre = p_nombre, precio_extra = p_precio_extra, activo = p_activo
        WHERE id_modificador = p_id_modificador;
    END IF;
    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_guardar_prioridad(
    IN p_actor INT UNSIGNED,
    IN p_id_prioridad VARCHAR(12),
    IN p_prioridad VARCHAR(10),
    IN p_color_hex CHAR(7),
    IN p_activa TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    IF p_color_hex NOT REGEXP '^#[0-9A-Fa-f]{6}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRIORITY_COLOR_INVALID';
    END IF;
    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    SELECT COUNT(*) INTO v_existe FROM PRIORIDAD WHERE id_prioridad = p_id_prioridad;
    IF v_existe = 0 THEN
        INSERT INTO PRIORIDAD (id_prioridad, prioridad, color_hex, activa)
        VALUES (p_id_prioridad, p_prioridad, p_color_hex, p_activa);
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'PRIORIDAD', p_id_prioridad, 'I',
            JSON_OBJECT('prioridad', p_prioridad, 'color_hex', p_color_hex, 'activa', p_activa),
            p_actor
        );
    ELSE
        UPDATE PRIORIDAD
        SET prioridad = p_prioridad, color_hex = p_color_hex, activa = p_activa
        WHERE id_prioridad = p_id_prioridad;
    END IF;
    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_listar_catalogo(
    IN p_busqueda VARCHAR(120),
    IN p_estado VARCHAR(10)
)
BEGIN
    SELECT
        pr.id_producto,
        pr.nombre,
        pr.descripcion,
        pr.requiere_preparacion,
        pr.precio_actual,
        pr.tiempo_prep_min,
        pr.imagen_url,
        pr.activo,
        CASE WHEN pl.id_producto IS NOT NULL THEN 'PLATO'
             WHEN be.id_producto IS NOT NULL THEN 'BEBIDA'
             ELSE 'OTRO' END AS tipo,
        cp.id_categoria,
        cp.nombre AS categoria,
        be.volumen_ml,
        be.es_alcoholica,
        be.temperatura,
        (
            SELECT GROUP_CONCAT(
                CONCAT(pv.id_variante, ':', pv.nombre, ':', pv.precio)
                ORDER BY pv.id_variante SEPARATOR '|'
            )
            FROM PLATO_VARIANTE pv
            WHERE pv.id_plato = pr.id_producto
        ) AS variantes,
        (
            SELECT ec.nombre
            FROM PRODUCTO_ESTACION pe
            INNER JOIN ESTACION_COCINA ec ON ec.id_estacion = pe.id_estacion
            WHERE pe.id_producto = pr.id_producto
            ORDER BY pe.es_principal DESC, pe.id_estacion
            LIMIT 1
        ) AS estacion,
        (
            SELECT pe.id_estacion
            FROM PRODUCTO_ESTACION pe
            WHERE pe.id_producto = pr.id_producto
            ORDER BY pe.es_principal DESC, pe.id_estacion
            LIMIT 1
        ) AS id_estacion
    FROM PRODUCTO pr
    LEFT JOIN PLATO pl ON pl.id_producto = pr.id_producto
    LEFT JOIN CATEGORIA_PLATO cp ON cp.id_categoria = pl.id_categoria
    LEFT JOIN BEBIDAS be ON be.id_producto = pr.id_producto
    WHERE (p_busqueda IS NULL OR p_busqueda = ''
           OR pr.id_producto LIKE CONCAT('%', p_busqueda, '%')
           OR pr.nombre LIKE CONCAT('%', p_busqueda, '%'))
      AND (p_estado = 'TODOS'
           OR (p_estado = 'ACTIVO' AND pr.activo = 1)
           OR (p_estado = 'INACTIVO' AND pr.activo = 0))
    ORDER BY pr.nombre, pr.id_producto;
END$$

CREATE PROCEDURE sp_admin_listar_variantes()
BEGIN
    SELECT id_variante, id_plato, nombre, precio, activo
    FROM PLATO_VARIANTE
    ORDER BY id_plato, nombre;
END$$

CREATE PROCEDURE sp_admin_guardar_producto(
    IN p_actor INT UNSIGNED,
    IN p_id_producto VARCHAR(15),
    IN p_nombre VARCHAR(120),
    IN p_descripcion TEXT,
    IN p_tipo VARCHAR(10),
    IN p_precio DECIMAL(10,2),
    IN p_requiere_preparacion TINYINT,
    IN p_tiempo_prep_min SMALLINT UNSIGNED,
    IN p_imagen_url VARCHAR(255),
    IN p_id_categoria SMALLINT UNSIGNED,
    IN p_id_estacion SMALLINT UNSIGNED,
    IN p_volumen_ml INT,
    IN p_es_alcoholica TINYINT,
    IN p_temperatura VARCHAR(30)
)
main: BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_estacion_activa INT DEFAULT 0;
    DECLARE v_asignacion_estacion INT DEFAULT 0;
    DECLARE v_tipo_actual VARCHAR(10) DEFAULT 'OTRO';

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    IF p_tipo NOT IN ('PLATO', 'BEBIDA', 'OTRO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_TYPE_INVALID';
    END IF;
    IF p_precio < 0 OR p_tiempo_prep_min < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_VALUE_INVALID';
    END IF;
    IF p_tipo = 'PLATO' AND p_id_categoria IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_CATEGORY_REQUIRED';
    END IF;
    IF p_requiere_preparacion = 1 AND p_id_estacion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_STATION_REQUIRED';
    END IF;
    IF p_requiere_preparacion = 1 THEN
        SELECT COUNT(*) INTO v_estacion_activa
        FROM ESTACION_COCINA
        WHERE id_estacion = p_id_estacion AND activa = 1;
        IF v_estacion_activa = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_STATION_INVALID';
        END IF;
    END IF;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;

    SELECT COUNT(*) INTO v_existe
    FROM PRODUCTO WHERE id_producto = p_id_producto FOR UPDATE;

    IF v_existe = 1 THEN
        SELECT CASE WHEN EXISTS (
            SELECT 1 FROM PLATO WHERE id_producto = p_id_producto
        ) THEN 'PLATO'
        WHEN EXISTS (
            SELECT 1 FROM BEBIDAS WHERE id_producto = p_id_producto
        ) THEN 'BEBIDA'
        ELSE 'OTRO' END INTO v_tipo_actual;

        IF v_tipo_actual <> p_tipo THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_TYPE_IMMUTABLE';
        END IF;

        UPDATE PRODUCTO
        SET nombre = p_nombre,
            descripcion = p_descripcion,
            requiere_preparacion = p_requiere_preparacion,
            precio_actual = p_precio,
            tiempo_prep_min = p_tiempo_prep_min,
            imagen_url = p_imagen_url
        WHERE id_producto = p_id_producto;

        IF p_tipo = 'PLATO' THEN
            UPDATE PLATO SET id_categoria = p_id_categoria
            WHERE id_producto = p_id_producto;
        ELSEIF p_tipo = 'BEBIDA' THEN
            UPDATE BEBIDAS
            SET volumen_ml = p_volumen_ml,
                es_alcoholica = p_es_alcoholica,
                temperatura = p_temperatura
            WHERE id_producto = p_id_producto;
        END IF;
    ELSE
        INSERT INTO PRODUCTO (
            id_producto, nombre, descripcion, requiere_preparacion,
            precio_actual, tiempo_prep_min, imagen_url, activo
        ) VALUES (
            p_id_producto, p_nombre, p_descripcion, p_requiere_preparacion,
            p_precio, p_tiempo_prep_min, p_imagen_url, 1
        );

        IF p_tipo = 'PLATO' THEN
            INSERT INTO PLATO (id_producto, id_categoria) VALUES (p_id_producto, p_id_categoria);
        ELSEIF p_tipo = 'BEBIDA' THEN
            INSERT INTO BEBIDAS (id_producto, volumen_ml, es_alcoholica, temperatura)
            VALUES (p_id_producto, p_volumen_ml, p_es_alcoholica, p_temperatura);
        END IF;

        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'PRODUCTO', p_id_producto, 'I',
            JSON_OBJECT('nombre', p_nombre, 'tipo', p_tipo, 'precio_actual', p_precio, 'activo', 1),
            p_actor
        );
    END IF;

    IF p_requiere_preparacion = 1 THEN
        SELECT COUNT(*) INTO v_asignacion_estacion
        FROM PRODUCTO_ESTACION
        WHERE id_producto = p_id_producto AND id_estacion = p_id_estacion;
        UPDATE PRODUCTO_ESTACION
        SET es_principal = 0
        WHERE id_producto = p_id_producto AND id_estacion <> p_id_estacion;
        INSERT INTO PRODUCTO_ESTACION (id_producto, id_estacion, es_principal)
        VALUES (p_id_producto, p_id_estacion, 1)
        ON DUPLICATE KEY UPDATE es_principal = 1;
        IF v_asignacion_estacion = 0 THEN
            INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
            VALUES (
                'PRODUCTO_ESTACION',
                CONCAT(p_id_producto, ':', p_id_estacion),
                'I',
                JSON_OBJECT('id_producto', p_id_producto, 'id_estacion', p_id_estacion, 'es_principal', 1),
                p_actor
            );
        END IF;
    ELSE
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_antes, id_usuario)
        SELECT 'PRODUCTO_ESTACION', CONCAT(id_producto, ':', id_estacion), 'D',
               JSON_OBJECT('es_principal', es_principal), p_actor
        FROM PRODUCTO_ESTACION
        WHERE id_producto = p_id_producto;
        DELETE FROM PRODUCTO_ESTACION WHERE id_producto = p_id_producto;
    END IF;

    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_guardar_variante(
    IN p_actor INT UNSIGNED,
    IN p_id_variante INT UNSIGNED,
    IN p_id_plato VARCHAR(15),
    IN p_nombre VARCHAR(40),
    IN p_precio DECIMAL(10,2),
    IN p_activo TINYINT
)
BEGIN
    DECLARE v_tipo VARCHAR(15);
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_id_variante INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    SELECT CASE WHEN EXISTS (
        SELECT 1 FROM PLATO WHERE id_producto = p_id_plato
    ) THEN 'PLATO' ELSE 'OTRO' END INTO v_tipo;
    IF v_tipo <> 'PLATO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_VARIANT_REQUIRES_DISH';
    END IF;
    IF p_precio < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_VALUE_INVALID';
    END IF;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;
    IF p_id_variante IS NULL THEN
        INSERT INTO PLATO_VARIANTE (id_plato, nombre, precio, activo)
        VALUES (p_id_plato, p_nombre, p_precio, p_activo);
        SET v_id_variante = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'PLATO_VARIANTE', CAST(v_id_variante AS CHAR), 'I',
            JSON_OBJECT('id_plato', p_id_plato, 'nombre', p_nombre, 'precio', p_precio, 'activo', p_activo),
            p_actor
        );
    ELSE
        SELECT COUNT(*) INTO v_existe
        FROM PLATO_VARIANTE
        WHERE id_variante = p_id_variante AND id_plato = p_id_plato;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_VARIANT_NOT_FOUND';
        END IF;
        UPDATE PLATO_VARIANTE
        SET nombre = p_nombre, precio = p_precio, activo = p_activo
        WHERE id_variante = p_id_variante AND id_plato = p_id_plato;
    END IF;

    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_estado_producto(
    IN p_actor INT UNSIGNED,
    IN p_id_producto VARCHAR(15),
    IN p_activo TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    SET @sipan_current_user_id = p_actor;
    SELECT COUNT(*) INTO v_existe
    FROM PRODUCTO WHERE id_producto = p_id_producto;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_NOT_FOUND';
    END IF;
    UPDATE PRODUCTO SET activo = p_activo WHERE id_producto = p_id_producto;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_listar_personal(IN p_busqueda VARCHAR(120))
BEGIN
    SELECT
        u.id_usuario,
        u.username,
        u.activo,
        u.ultimo_login,
        p.id_persona,
        p.nombres,
        p.primer_apellido,
        p.segundo_apellido,
        p.tipo_documento,
        p.numero_documento,
        p.telefono,
        p.email,
        CASE
            WHEN ad.id_persona IS NOT NULL THEN 'ADMINISTRADOR'
            WHEN ca.id_persona IS NOT NULL THEN 'CAJERO'
            WHEN me.id_persona IS NOT NULL THEN 'MESERO'
            WHEN co.id_persona IS NOT NULL THEN 'COCINERO'
            ELSE 'SIN_ROL'
        END AS rol,
        ec.nombre AS estacion
    FROM USUARIO u
    INNER JOIN PERSONA p ON p.id_persona = u.id_persona
    LEFT JOIN ADMINISTRADOR ad ON ad.id_persona = p.id_persona
    LEFT JOIN CAJERO ca ON ca.id_persona = p.id_persona
    LEFT JOIN MESERO me ON me.id_persona = p.id_persona
    LEFT JOIN COCINERO co ON co.id_persona = p.id_persona
    LEFT JOIN ESTACION_COCINA ec ON ec.id_estacion = co.id_estacion
    WHERE p_busqueda IS NULL OR p_busqueda = ''
       OR u.username LIKE CONCAT('%', p_busqueda, '%')
       OR p.nombres LIKE CONCAT('%', p_busqueda, '%')
       OR p.primer_apellido LIKE CONCAT('%', p_busqueda, '%')
       OR p.numero_documento LIKE CONCAT('%', p_busqueda, '%')
    ORDER BY p.primer_apellido, p.nombres;
END$$

CREATE PROCEDURE sp_admin_crear_usuario(
    IN p_actor INT UNSIGNED,
    IN p_id_persona VARCHAR(20),
    IN p_nombres VARCHAR(80),
    IN p_primer_apellido VARCHAR(80),
    IN p_segundo_apellido VARCHAR(80),
    IN p_tipo_documento VARCHAR(20),
    IN p_numero_documento VARCHAR(20),
    IN p_telefono VARCHAR(20),
    IN p_email VARCHAR(150),
    IN p_username VARCHAR(80),
    IN p_password_hash VARCHAR(255),
    IN p_rol VARCHAR(20),
    IN p_id_estacion SMALLINT UNSIGNED
)
BEGIN
    DECLARE v_id_usuario INT UNSIGNED;
    DECLARE v_estacion_activa INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    IF p_rol NOT IN ('ADMINISTRADOR', 'CAJERO', 'MESERO', 'COCINERO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_ROLE_INVALID';
    END IF;
    IF p_rol = 'COCINERO' AND p_id_estacion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_STATION_REQUIRED';
    END IF;
    IF p_rol = 'COCINERO' THEN
        SELECT COUNT(*) INTO v_estacion_activa
        FROM ESTACION_COCINA
        WHERE id_estacion = p_id_estacion AND activa = 1;
        IF v_estacion_activa = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_PRODUCT_STATION_INVALID';
        END IF;
    END IF;

    START TRANSACTION;
    SET @sipan_current_user_id = p_actor;

    INSERT INTO PERSONA (
        id_persona, nombres, primer_apellido, segundo_apellido,
        tipo_documento, numero_documento, telefono, email
    ) VALUES (
        p_id_persona, p_nombres, p_primer_apellido, p_segundo_apellido,
        p_tipo_documento, p_numero_documento, p_telefono, p_email
    );

    INSERT INTO USUARIO (id_persona, username, password_hash, activo)
    VALUES (p_id_persona, p_username, p_password_hash, 1);
    SET v_id_usuario = LAST_INSERT_ID();

    IF p_rol = 'ADMINISTRADOR' THEN
        INSERT INTO ADMINISTRADOR (id_persona) VALUES (p_id_persona);
    ELSEIF p_rol = 'CAJERO' THEN
        INSERT INTO CAJERO (id_persona) VALUES (p_id_persona);
    ELSEIF p_rol = 'MESERO' THEN
        INSERT INTO MESERO (id_persona) VALUES (p_id_persona);
    ELSE
        INSERT INTO COCINERO (id_persona, id_estacion) VALUES (p_id_persona, p_id_estacion);
    END IF;

    INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
    VALUES (
        'USUARIO', CAST(v_id_usuario AS CHAR), 'I',
        JSON_OBJECT('username', p_username, 'rol', p_rol, 'activo', 1),
        p_actor
    );

    COMMIT;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_estado_usuario(
    IN p_actor INT UNSIGNED,
    IN p_id_usuario INT UNSIGNED,
    IN p_activo TINYINT
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @sipan_current_user_id = NULL;
        RESIGNAL;
    END;

    SET @sipan_current_user_id = p_actor;
    IF p_id_usuario = p_actor AND p_activo = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_SELF_DEACTIVATION_FORBIDDEN';
    END IF;
    SELECT COUNT(*) INTO v_existe FROM USUARIO WHERE id_usuario = p_id_usuario;
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_USER_NOT_FOUND';
    END IF;
    UPDATE USUARIO SET activo = p_activo WHERE id_usuario = p_id_usuario;
    SET @sipan_current_user_id = NULL;
END$$

CREATE PROCEDURE sp_admin_listar_zonas()
BEGIN
    SELECT id_zona, nombre, activa
    FROM ZONA
    ORDER BY nombre;
END$$

CREATE PROCEDURE sp_admin_listar_mesas()
BEGIN
    SELECT id_mesa, id_zona, zona, numero, capacidad, estado, activa,
           id_pedido, nombre_mesero, minutos_ocupacion
    FROM vw_estado_salon_tiempo_real
    ORDER BY zona, numero;
END$$

CREATE PROCEDURE sp_admin_guardar_zona(
    IN p_actor INT UNSIGNED,
    IN p_id_zona SMALLINT UNSIGNED,
    IN p_nombre VARCHAR(50),
    IN p_activa TINYINT
)
BEGIN
    DECLARE v_ocupadas INT DEFAULT 0;
    DECLARE v_mesas_activas INT DEFAULT 0;
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_id_zona SMALLINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    IF p_id_zona IS NULL THEN
        INSERT INTO ZONA (nombre, activa) VALUES (p_nombre, p_activa);
        SET v_id_zona = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES ('ZONA', CAST(v_id_zona AS CHAR), 'I', JSON_OBJECT('nombre', p_nombre, 'activa', p_activa), p_actor);
    ELSE
        SELECT COUNT(*) INTO v_existe FROM ZONA WHERE id_zona = p_id_zona;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_ZONE_NOT_FOUND';
        END IF;
        IF p_activa = 0 THEN
            SELECT COUNT(*) INTO v_mesas_activas
            FROM MESA
            WHERE id_zona = p_id_zona AND activa = 1;
            IF v_mesas_activas > 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_ZONE_HAS_ACTIVE_TABLES';
            END IF;
        END IF;

        UPDATE ZONA SET nombre = p_nombre, activa = p_activa WHERE id_zona = p_id_zona;
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES ('ZONA', CAST(p_id_zona AS CHAR), 'U', JSON_OBJECT('nombre', p_nombre, 'activa', p_activa), p_actor);
    END IF;
    COMMIT;
END$$

CREATE PROCEDURE sp_admin_guardar_mesa(
    IN p_actor INT UNSIGNED,
    IN p_id_mesa INT UNSIGNED,
    IN p_id_zona SMALLINT UNSIGNED,
    IN p_numero INT UNSIGNED,
    IN p_capacidad SMALLINT UNSIGNED,
    IN p_activa TINYINT
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_pedidos_abiertos INT DEFAULT 0;
    DECLARE v_zona_actual SMALLINT UNSIGNED;
    DECLARE v_numero_actual INT UNSIGNED;
    DECLARE v_capacidad_actual SMALLINT UNSIGNED;
    DECLARE v_id_mesa INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    IF p_id_mesa IS NULL THEN
        INSERT INTO MESA (id_zona, numero, capacidad, estado, activa)
        VALUES (p_id_zona, p_numero, p_capacidad, IF(p_activa = 1, 'LIBRE', 'INACTIVA'), p_activa);
        SET v_id_mesa = LAST_INSERT_ID();
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'MESA', CAST(v_id_mesa AS CHAR), 'I',
            JSON_OBJECT('id_zona', p_id_zona, 'numero', p_numero, 'capacidad', p_capacidad, 'activa', p_activa),
            p_actor
        );
    ELSE
        SELECT COUNT(*) INTO v_existe
        FROM MESA WHERE id_mesa = p_id_mesa;
        IF v_existe = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_TABLE_NOT_FOUND';
        END IF;
        SELECT estado, id_zona, numero, capacidad
        INTO v_estado, v_zona_actual, v_numero_actual, v_capacidad_actual
        FROM MESA WHERE id_mesa = p_id_mesa FOR UPDATE;
        SELECT COUNT(*) INTO v_pedidos_abiertos
        FROM PEDIDO
        WHERE id_mesa = p_id_mesa AND estado IN ('ABIERTO', 'EN_PAGO');
        IF (v_estado = 'OCUPADA' OR v_pedidos_abiertos > 0)
           AND (p_activa = 0 OR p_id_zona <> v_zona_actual
                OR p_numero <> v_numero_actual OR p_capacidad <> v_capacidad_actual) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_TABLE_OCCUPIED';
        END IF;
        UPDATE MESA
        SET id_zona = p_id_zona,
            numero = p_numero,
            capacidad = p_capacidad,
            activa = p_activa,
            estado = CASE
                WHEN p_activa = 0 THEN 'INACTIVA'
                WHEN estado = 'INACTIVA' THEN 'LIBRE'
                ELSE estado
            END
        WHERE id_mesa = p_id_mesa;
        INSERT INTO AUDITORIA (tabla, id_registro, accion, datos_despues, id_usuario)
        VALUES (
            'MESA', CAST(p_id_mesa AS CHAR), 'U',
            JSON_OBJECT('id_zona', p_id_zona, 'numero', p_numero, 'capacidad', p_capacidad, 'activa', p_activa),
            p_actor
        );
    END IF;
    COMMIT;
END$$

CREATE PROCEDURE sp_admin_resumen_financiero(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        (SELECT COUNT(*) FROM COMPROBANTE c
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)) AS comprobantes_emitidos,
        (SELECT COALESCE(SUM(c.subtotal), 0) FROM COMPROBANTE c
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)) AS subtotal,
        (SELECT COALESCE(SUM(c.igv), 0) FROM COMPROBANTE c
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)) AS impuestos,
        (SELECT COALESCE(SUM(c.total), 0) FROM COMPROBANTE c
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)) AS total_ventas,
        (SELECT COALESCE(SUM(p.monto), 0) FROM PAGO p
         INNER JOIN COMPROBANTE c ON c.id_comprobante = p.id_comprobante
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
           AND p.metodo = 'EFECTIVO') AS efectivo,
        (SELECT COALESCE(SUM(p.monto), 0) FROM PAGO p
         INNER JOIN COMPROBANTE c ON c.id_comprobante = p.id_comprobante
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
           AND p.metodo = 'TARJETA') AS tarjeta,
        (SELECT COALESCE(SUM(p.monto), 0) FROM PAGO p
         INNER JOIN COMPROBANTE c ON c.id_comprobante = p.id_comprobante
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
           AND p.metodo = 'YAPE') AS yape,
        (SELECT COALESCE(SUM(p.monto), 0) FROM PAGO p
         INNER JOIN COMPROBANTE c ON c.id_comprobante = p.id_comprobante
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
           AND p.metodo = 'PLIN') AS plin,
        (SELECT COALESCE(SUM(p.monto), 0) FROM PAGO p
         INNER JOIN COMPROBANTE c ON c.id_comprobante = p.id_comprobante
         WHERE c.estado = 'EMITIDO' AND c.created_at >= p_desde
           AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
           AND p.metodo = 'TRANSFERENCIA') AS transferencia;
END$$

CREATE PROCEDURE sp_admin_saldos_pendientes()
BEGIN
    SELECT
        r.id_pedido,
        r.tipo,
        r.id_mesa,
        r.estado,
        r.total,
        r.total_pagado,
        r.saldo_pendiente,
        p.fecha,
        u.username,
        CONCAT(pe.nombres, ' ', pe.primer_apellido) AS mesero
    FROM vw_resumen_cuenta_pedido r
    INNER JOIN PEDIDO p ON p.id_pedido = r.id_pedido
    INNER JOIN USUARIO u ON u.id_usuario = p.id_usuario
    INNER JOIN PERSONA pe ON pe.id_persona = u.id_persona
    WHERE r.estado IN ('ABIERTO', 'EN_PAGO')
      AND fn_admin_saldo_pedido(r.id_pedido) > 0
    ORDER BY p.fecha;
END$$

CREATE PROCEDURE sp_admin_listar_comprobantes(IN p_limite SMALLINT UNSIGNED)
BEGIN
    IF p_limite < 1 OR p_limite > 50 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ADMIN_RECEIPT_LIMIT_INVALID';
    END IF;

    SELECT
        c.id_comprobante,
        c.tipo,
        c.serie,
        c.correlativo,
        CONCAT(COALESCE(c.serie, 'SN'), '-', LPAD(COALESCE(c.correlativo, c.id_comprobante), 8, '0')) AS numero,
        c.estado,
        c.subtotal,
        c.igv,
        c.total,
        c.created_at,
        c.referencia_externa,
        cl.nombre AS cliente,
        p.id_pedido,
        p.tipo AS tipo_pedido,
        m.numero AS numero_mesa,
        CONCAT_WS(' ', per.nombres, per.primer_apellido) AS emitido_por,
        (
            SELECT GROUP_CONCAT(DISTINCT pg.metodo ORDER BY pg.metodo SEPARATOR ', ')
            FROM PAGO pg
            WHERE pg.id_comprobante = c.id_comprobante
        ) AS medios_pago,
        (
            SELECT COALESCE(
                JSON_ARRAYAGG(JSON_OBJECT(
                    'nombre', COALESCE(NULLIF(d.nombre_snapshot, ''), pr.nombre),
                    'cantidad', d.cantidad,
                    'precio_unitario', d.precio_unitario_venta + COALESCE((
                        SELECT SUM(dm.precio_venta)
                        FROM DETALLE_MODIFICADOR dm
                        WHERE dm.id_detalle = d.id_detalle
                    ), 0),
                    'total', d.cantidad * (d.precio_unitario_venta + COALESCE((
                        SELECT SUM(dm.precio_venta)
                        FROM DETALLE_MODIFICADOR dm
                        WHERE dm.id_detalle = d.id_detalle
                    ), 0)),
                    'modificadores', COALESCE((
                        SELECT GROUP_CONCAT(dm.nombre_snapshot ORDER BY dm.id_detalle_mod SEPARATOR ', ')
                        FROM DETALLE_MODIFICADOR dm
                        WHERE dm.id_detalle = d.id_detalle
                    ), '')
                )),
                JSON_ARRAY()
            )
            FROM COMANDA co
            INNER JOIN DETALLE_COMANDA d ON d.id_comanda = co.id_comanda
            INNER JOIN PRODUCTO pr ON pr.id_producto = d.id_producto
            WHERE co.id_pedido = c.id_pedido
              AND d.estado_item <> 'CANCELADO'
        ) AS items
    FROM COMPROBANTE c
    INNER JOIN PEDIDO p ON p.id_pedido = c.id_pedido
    LEFT JOIN MESA m ON m.id_mesa = p.id_mesa
    LEFT JOIN CLIENTE cl ON cl.id_cliente = c.id_cliente
    INNER JOIN USUARIO u ON u.id_usuario = c.id_usuario
    INNER JOIN PERSONA per ON per.id_persona = u.id_persona
    WHERE c.estado IN ('EMITIDO', 'ANULADO')
    ORDER BY c.created_at DESC, c.id_comprobante DESC
    LIMIT p_limite;
END$$

CREATE PROCEDURE sp_admin_reporte_ventas(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        DATE(c.created_at) AS fecha,
        c.tipo,
        COUNT(*) AS comprobantes,
        SUM(c.subtotal) AS subtotal,
        SUM(c.igv) AS impuestos,
        SUM(c.total) AS total
    FROM COMPROBANTE c
    WHERE c.estado = 'EMITIDO'
      AND c.created_at >= p_desde
      AND c.created_at < DATE_ADD(p_hasta, INTERVAL 1 DAY)
    GROUP BY DATE(c.created_at), c.tipo
    ORDER BY fecha DESC, c.tipo;
END$$

CREATE PROCEDURE sp_admin_sesiones_caja(IN p_desde DATE, IN p_hasta DATE)
BEGIN
    SELECT
        a.*,
        u.username,
        CONCAT(pe.nombres, ' ', pe.primer_apellido) AS cajero
    FROM vw_arqueo_sesion_caja a
    INNER JOIN USUARIO u ON u.id_usuario = a.id_usuario
    INNER JOIN PERSONA pe ON pe.id_persona = u.id_persona
    WHERE a.apertura_en >= p_desde
      AND a.apertura_en < DATE_ADD(p_hasta, INTERVAL 1 DAY)
    ORDER BY a.apertura_en DESC;
END$$

CREATE PROCEDURE sp_admin_listar_auditoria(
    IN p_busqueda VARCHAR(120),
    IN p_desde DATE,
    IN p_hasta DATE,
    IN p_limite SMALLINT UNSIGNED,
    IN p_offset INT UNSIGNED
)
BEGIN
    SELECT id_auditoria, tabla, id_registro, accion, datos_antes, datos_despues,
           fecha, id_usuario, username, nombre_completo
    FROM vw_auditoria_legible
    WHERE fecha >= p_desde
      AND fecha < DATE_ADD(p_hasta, INTERVAL 1 DAY)
      AND (p_busqueda IS NULL OR p_busqueda = ''
           OR tabla LIKE CONCAT('%', p_busqueda, '%')
           OR id_registro LIKE CONCAT('%', p_busqueda, '%')
           OR username LIKE CONCAT('%', p_busqueda, '%')
           OR nombre_completo LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY fecha DESC, id_auditoria DESC
    LIMIT p_limite OFFSET p_offset;
END$$

DELIMITER ;
