-- CHIFA SIPÁN v3.1 — remediación incremental sobre BD.sql
-- Idempotente: cada ALTER se aplica solo si la columna/tabla no existe.

SET @db := DATABASE();

-- Laravel persistent sessions without storing passwords in the browser app.
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='usuario' AND COLUMN_NAME='remember_token');
SET @sql := IF(@exists=0, 'ALTER TABLE USUARIO ADD COLUMN remember_token VARCHAR(100) NULL AFTER password_hash', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 1) Snapshots en DETALLE_COMANDA
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='id_variante');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_COMANDA ADD COLUMN id_variante INT UNSIGNED NULL AFTER id_producto', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='nombre_snapshot');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_COMANDA ADD COLUMN nombre_snapshot VARCHAR(160) NOT NULL DEFAULT '''' AFTER id_variante', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='precio_unitario_venta');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_COMANDA ADD COLUMN precio_unitario_venta DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER nombre_snapshot', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='id_estacion_cocina');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_COMANDA ADD COLUMN id_estacion_cocina SMALLINT UNSIGNED NULL AFTER precio_unitario_venta', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Convertir hitos TIME -> DATETIME (recrear columnas)
SET @coltype := (SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='iniciado_en' LIMIT 1);
SET @sql := IF(@coltype='time', 'ALTER TABLE DETALLE_COMANDA DROP COLUMN iniciado_en, DROP COLUMN listo_en, DROP COLUMN entregado_en', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND COLUMN_NAME='iniciado_en');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_COMANDA ADD COLUMN iniciado_en DATETIME NULL, ADD COLUMN listo_en DATETIME NULL, ADD COLUMN entregado_en DATETIME NULL, ADD COLUMN motivo_cancelacion VARCHAR(250) NULL', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND CONSTRAINT_NAME='fk_detalle_variante');
SET @sql := IF(@fk=0, 'ALTER TABLE DETALLE_COMANDA ADD CONSTRAINT fk_detalle_variante FOREIGN KEY (id_variante) REFERENCES PLATO_VARIANTE(id_variante)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND CONSTRAINT_NAME='fk_detalle_estacion');
SET @sql := IF(@fk=0, 'ALTER TABLE DETALLE_COMANDA ADD CONSTRAINT fk_detalle_estacion FOREIGN KEY (id_estacion_cocina) REFERENCES ESTACION_COCINA(id_estacion)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 2) Snapshots en DETALLE_MODIFICADOR
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_modificador' AND COLUMN_NAME='nombre_snapshot');
SET @sql := IF(@exists=0, 'ALTER TABLE DETALLE_MODIFICADOR ADD COLUMN nombre_snapshot VARCHAR(80) NOT NULL DEFAULT '''' AFTER id_modificador, ADD COLUMN precio_venta DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER nombre_snapshot', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 3) Máquina de estados PEDIDO + contexto de entrega + idempotencia
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pedido' AND COLUMN_NAME='estado');
SET @sql := IF(@exists=0, 'ALTER TABLE PEDIDO ADD COLUMN estado ENUM(''ABIERTO'',''EN_PAGO'',''PAGADO'',''ANULADO'') NOT NULL DEFAULT ''ABIERTO'' AFTER notas_generales, ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1 AFTER estado, ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER version, ADD COLUMN id_cliente INT UNSIGNED NULL AFTER id_usuario, ADD COLUMN id_direccion_entrega INT UNSIGNED NULL AFTER id_cliente, ADD COLUMN direccion_snapshot JSON NULL AFTER id_direccion_entrega, ADD COLUMN client_request_id CHAR(36) NULL AFTER direccion_snapshot', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @idx := (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pedido' AND INDEX_NAME='uq_pedido_client_request');
SET @sql := IF(@idx=0, 'ALTER TABLE PEDIDO ADD UNIQUE KEY uq_pedido_client_request (client_request_id)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pedido' AND CONSTRAINT_NAME='fk_pedido_cliente');
SET @sql := IF(@fk=0, 'ALTER TABLE PEDIDO ADD CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente), ADD CONSTRAINT fk_pedido_direccion FOREIGN KEY (id_direccion_entrega) REFERENCES DIRECCION_CLIENTE(id_direccion)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @chk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pedido' AND CONSTRAINT_NAME='CHK_PEDIDO_MESA_COHERENCIA');
SET @sql := IF(@chk=0, 'ALTER TABLE PEDIDO ADD CONSTRAINT CHK_PEDIDO_MESA_COHERENCIA CHECK ((tipo = ''SALON'' AND id_mesa IS NOT NULL) OR (tipo IN (''LLEVAR'',''DELIVERY'') AND id_mesa IS NULL))', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 4) COMANDA idempotencia + enviado_en
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comanda' AND COLUMN_NAME='client_request_id');
SET @sql := IF(@exists=0, 'ALTER TABLE COMANDA ADD COLUMN client_request_id CHAR(36) NULL AFTER numero_ronda, ADD COLUMN enviado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER client_request_id, ADD UNIQUE KEY uq_comanda_client_request (client_request_id)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comanda' AND COLUMN_NAME='request_hash');
SET @sql := IF(@exists=0, 'ALTER TABLE COMANDA ADD COLUMN request_hash CHAR(64) NULL AFTER client_request_id', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 5) CLIENTE.id_direccion nullable
SET @nullable := (SELECT IS_NULLABLE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='cliente' AND COLUMN_NAME='id_direccion' LIMIT 1);
SET @fk := (SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='cliente' AND CONSTRAINT_NAME='fk_cliente_direccion' LIMIT 1);
SET @sql := IF(@nullable='NO' AND @fk IS NOT NULL, 'ALTER TABLE CLIENTE DROP FOREIGN KEY fk_cliente_direccion', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @sql := IF(@nullable='NO', 'ALTER TABLE CLIENTE MODIFY id_direccion INT UNSIGNED NULL', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='cliente' AND CONSTRAINT_NAME='fk_cliente_direccion');
SET @sql := IF(@fk=0, 'ALTER TABLE CLIENTE ADD CONSTRAINT fk_cliente_direccion FOREIGN KEY (id_direccion) REFERENCES DIRECCION_CLIENTE(id_direccion)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 6) PRODUCTO.activo (auditoría de catálogo)
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='producto' AND COLUMN_NAME='activo');
SET @sql := IF(@exists=0, 'ALTER TABLE PRODUCTO ADD COLUMN activo TINYINT(1) NOT NULL DEFAULT 1 AFTER imagen_url, ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER activo', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 7) PRODUCTO_ESTACION
CREATE TABLE IF NOT EXISTS PRODUCTO_ESTACION (
    id_producto VARCHAR(15) NOT NULL,
    id_estacion SMALLINT UNSIGNED NOT NULL,
    es_principal TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_producto, id_estacion),
    CONSTRAINT fk_pe_producto FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto),
    CONSTRAINT fk_pe_estacion FOREIGN KEY (id_estacion) REFERENCES ESTACION_COCINA(id_estacion)
) ENGINE=InnoDB;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='modificador' AND COLUMN_NAME='activo');
SET @sql := IF(@exists=0, 'ALTER TABLE MODIFICADOR ADD COLUMN activo TINYINT(1) NOT NULL DEFAULT 1', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 8) MOVIMIENTO_CAJA
CREATE TABLE IF NOT EXISTS MOVIMIENTO_CAJA (
    id_movimiento INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_caja_sesion INT UNSIGNED NOT NULL,
    id_usuario INT UNSIGNED NOT NULL,
    tipo ENUM('INGRESO','EGRESO') NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    motivo VARCHAR(180) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_movimiento),
    CONSTRAINT fk_mov_caja_sesion FOREIGN KEY (id_caja_sesion) REFERENCES CAJA_SESION(id_caja_sesion),
    CONSTRAINT fk_mov_caja_usuario FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario),
    CONSTRAINT CHK_MOV_CAJA_MONTO CHECK (monto > 0)
) ENGINE=InnoDB;

-- 9) COMPROBANTE y PAGO
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comprobante' AND COLUMN_NAME='serie');
SET @sql := IF(@exists=0, 'ALTER TABLE COMPROBANTE ADD COLUMN serie VARCHAR(10) NULL AFTER tipo, ADD COLUMN correlativo INT UNSIGNED NULL AFTER serie, ADD COLUMN subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER correlativo, ADD COLUMN igv DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER subtotal, ADD COLUMN total DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER igv, ADD COLUMN estado ENUM(''EMITIDO'',''ANULADO'') NOT NULL DEFAULT ''EMITIDO'' AFTER total, ADD COLUMN referencia_externa VARCHAR(80) NULL AFTER estado, ADD UNIQUE KEY uq_comprobante_serie (tipo, serie, correlativo)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comprobante' AND COLUMN_NAME='receipt_request_id');
SET @sql := IF(@exists=0, 'ALTER TABLE COMPROBANTE ADD COLUMN receipt_request_id CHAR(36) NULL AFTER referencia_externa, ADD UNIQUE KEY uq_comprobante_request (receipt_request_id)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comprobante' AND COLUMN_NAME='created_at');
SET @sql := IF(@exists=0, 'ALTER TABLE COMPROBANTE ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @idx := (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='comprobante' AND INDEX_NAME='idx_comprobante_estado_fecha');
SET @sql := IF(@idx=0, 'ALTER TABLE COMPROBANTE ADD INDEX idx_comprobante_estado_fecha (estado, created_at)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pago' AND COLUMN_NAME='payment_request_id');
SET @sql := IF(@exists=0, 'ALTER TABLE PAGO ADD COLUMN payment_request_id CHAR(36) NULL AFTER id_pago, ADD UNIQUE KEY uq_pago_request (payment_request_id)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pago' AND COLUMN_NAME='created_at');
SET @sql := IF(@exists=0, 'ALTER TABLE PAGO ADD COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER vuelto', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
SET @idx := (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pago' AND INDEX_NAME='idx_pago_caja_fecha');
SET @sql := IF(@idx=0, 'ALTER TABLE PAGO ADD INDEX idx_pago_caja_fecha (id_caja_sesion, created_at)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @idx := (SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='auditoria' AND INDEX_NAME='idx_auditoria_fecha');
SET @sql := IF(@idx=0, 'ALTER TABLE AUDITORIA ADD INDEX idx_auditoria_fecha (fecha, id_auditoria)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 10) REFRESH_TOKEN.family_id
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='refresh_token' AND COLUMN_NAME='family_id');
SET @sql := IF(@exists=0, 'ALTER TABLE REFRESH_TOKEN ADD COLUMN family_id CHAR(36) NOT NULL AFTER id_usuario, ADD INDEX idx_refresh_family (family_id)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @length := (SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='refresh_token' AND COLUMN_NAME='dispositivo' LIMIT 1);
SET @sql := IF(@length < 255, 'ALTER TABLE REFRESH_TOKEN MODIFY dispositivo VARCHAR(255) NULL', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 11) WebAuthn (reservado F8)
CREATE TABLE IF NOT EXISTS WEBAUTHN_CREDENTIAL (
    id_credential VARCHAR(255) NOT NULL,
    id_usuario INT UNSIGNED NOT NULL,
    public_key TEXT NOT NULL,
    sign_count INT UNSIGNED NOT NULL DEFAULT 0,
    transports VARCHAR(120) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_credential),
    CONSTRAINT fk_webauthn_usuario FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

-- 12) CHECK montos en detalle (después de tener precio_unitario_venta)
SET @chk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_comanda' AND CONSTRAINT_NAME='CHK_MONTOS_POSITIVOS');
SET @sql := IF(@chk=0, 'ALTER TABLE DETALLE_COMANDA ADD CONSTRAINT CHK_MONTOS_POSITIVOS CHECK (cantidad > 0 AND precio_unitario_venta >= 0)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @chk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='detalle_modificador' AND CONSTRAINT_NAME='CHK_MODIFICADOR_PRECIO');
SET @sql := IF(@chk=0, 'ALTER TABLE DETALLE_MODIFICADOR ADD CONSTRAINT CHK_MODIFICADOR_PRECIO CHECK (precio_venta >= 0)', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @chk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=@db AND LOWER(TABLE_NAME)='pago' AND CONSTRAINT_NAME='CHK_PAGO_MONTOS');
SET @sql := IF(@chk=0, 'ALTER TABLE PAGO ADD CONSTRAINT CHK_PAGO_MONTOS CHECK (monto > 0 AND (monto_recibido IS NULL OR monto_recibido >= monto) AND (metodo = ''EFECTIVO'' OR monto_recibido IS NULL))', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
