CREATE DATABASE IF NOT EXISTS bd_chifa_sipan
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE bd_chifa_sipan;

SET FOREIGN_KEY_CHECKS = 0;


CREATE TABLE IF NOT EXISTS PERSONA (
    id_persona VARCHAR(20) NOT NULL,
    nombres VARCHAR(80) NOT NULL,
    primer_apellido VARCHAR(80) NOT NULL,
    segundo_apellido VARCHAR(80),
    tipo_documento ENUM('DNI','CE','PASAPORTE'),
    numero_documento VARCHAR(20),
    telefono VARCHAR(20),
    email VARCHAR(150),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_persona),
    UNIQUE KEY uq_persona_documento (tipo_documento, numero_documento),
    UNIQUE KEY uq_persona_email (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS USUARIO (
    id_usuario INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_persona VARCHAR(20) NOT NULL,
    username VARCHAR(80) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    remember_token VARCHAR(100) NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    intentos_fallidos SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_hasta DATETIME,
    ultimo_login DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_usuario),
    UNIQUE KEY uq_usuario_persona (id_persona),
    UNIQUE KEY uq_usuario_username (username),
    CONSTRAINT fk_usuario_persona
        FOREIGN KEY (id_persona) REFERENCES PERSONA(id_persona)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS CAJERO (
    id_persona VARCHAR(20) NOT NULL,
    PRIMARY KEY (id_persona),
    CONSTRAINT fk_cajero_persona
        FOREIGN KEY (id_persona) REFERENCES PERSONA(id_persona)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS MESERO (
    id_persona VARCHAR(20) NOT NULL,
    PRIMARY KEY (id_persona),
    CONSTRAINT fk_mesero_persona
        FOREIGN KEY (id_persona) REFERENCES PERSONA(id_persona)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ADMINISTRADOR (
    id_persona VARCHAR(20) NOT NULL,
    PRIMARY KEY (id_persona),
    CONSTRAINT fk_admin_persona
        FOREIGN KEY (id_persona) REFERENCES PERSONA(id_persona)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ESTACION_COCINA (
    id_estacion SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id_estacion),
    UNIQUE KEY uq_estacion_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS COCINERO (
    id_persona VARCHAR(20) NOT NULL,
    id_estacion SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id_persona),
    CONSTRAINT fk_cocinero_persona
        FOREIGN KEY (id_persona) REFERENCES PERSONA(id_persona),
    CONSTRAINT fk_cocinero_estacion
        FOREIGN KEY (id_estacion) REFERENCES ESTACION_COCINA(id_estacion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS ZONA (
    id_zona SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(50) NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id_zona),
    UNIQUE KEY uq_zona_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS MESA (
    id_mesa INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_zona SMALLINT UNSIGNED,
    numero INT UNSIGNED NOT NULL,
    capacidad SMALLINT UNSIGNED NOT NULL,
    estado ENUM('LIBRE','OCUPADA','RESERVADA','LIMPIEZA','INACTIVA') NOT NULL DEFAULT 'LIBRE',
    activa TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_mesa),
    UNIQUE KEY uq_mesa_zona_numero (id_zona, numero),
    CONSTRAINT fk_mesa_zona
        FOREIGN KEY (id_zona) REFERENCES ZONA(id_zona)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS DIRECCION_CLIENTE (
    id_direccion INT UNSIGNED NOT NULL AUTO_INCREMENT,
    linea_direccion VARCHAR(180) NOT NULL,
    distrito VARCHAR(80) NOT NULL,
    PRIMARY KEY (id_direccion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS CLIENTE (
    id_cliente INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tipo_documento ENUM('SIN_DOC','DNI','RUC','CE','PASAPORTE') NOT NULL,
    numero_documento VARCHAR(15),
    nombre VARCHAR(200) NOT NULL,
    email VARCHAR(120),
    telefono VARCHAR(20),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    id_direccion INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_cliente),
    UNIQUE KEY uq_cliente_documento (tipo_documento, numero_documento),
    CONSTRAINT fk_cliente_direccion
        FOREIGN KEY (id_direccion) REFERENCES DIRECCION_CLIENTE(id_direccion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PRODUCTO (
    id_producto VARCHAR(15) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion TEXT,
    requiere_preparacion TINYINT(1) NOT NULL DEFAULT 0,
    precio_actual DECIMAL(10,2) NOT NULL,
    tiempo_prep_min SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    imagen_url VARCHAR(255),
    PRIMARY KEY (id_producto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS CATEGORIA_PLATO (
    id_categoria SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(60) NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id_categoria),
    UNIQUE KEY uq_categoria_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PLATO (
    id_producto VARCHAR(15) NOT NULL,
    porcion ENUM('PERSONAL','FAMILIAR','MEDIO'),
    id_categoria SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id_producto),
    CONSTRAINT fk_plato_producto
        FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto),
    CONSTRAINT fk_plato_categoria
        FOREIGN KEY (id_categoria) REFERENCES CATEGORIA_PLATO(id_categoria)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PLATO_VARIANTE (
    id_variante INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_plato VARCHAR(15) NOT NULL,
    nombre VARCHAR(40) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id_variante),
    CONSTRAINT fk_variante_plato
        FOREIGN KEY (id_plato) REFERENCES PLATO(id_producto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS BEBIDAS (
    id_producto VARCHAR(15) NOT NULL,
    volumen_ml INT,
    es_alcoholica TINYINT(1),
    temperatura ENUM('HELADA','TEMPERATURA_AMBIENTE','CALIENTE'),
    PRIMARY KEY (id_producto),
    CONSTRAINT fk_bebida_producto
        FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PRIORIDAD (
    id_prioridad VARCHAR(12) NOT NULL,
    prioridad VARCHAR(10) NOT NULL,
    color_hex CHAR(7) NOT NULL,
    activa TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id_prioridad)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS CAJA_SESION (
    id_caja_sesion INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_usuario INT UNSIGNED NOT NULL,
    estado ENUM('ABIERTA','CERRADA') NOT NULL,
    monto_apertura DECIMAL(12,2) NOT NULL,
    monto_cierre_sistema DECIMAL(12,2),
    monto_cierre_declarado DECIMAL(12,2),
    apertura_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cierre_en DATETIME,
    observaciones TEXT,
    PRIMARY KEY (id_caja_sesion),
    CONSTRAINT fk_caja_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PEDIDO (
    id_pedido INT UNSIGNED NOT NULL AUTO_INCREMENT,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo ENUM('SALON','LLEVAR','DELIVERY') NOT NULL,
    id_mesa INT UNSIGNED,
    id_usuario INT UNSIGNED NOT NULL,
    num_comensales SMALLINT UNSIGNED,
    notas_generales TEXT,
    PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_mesa
        FOREIGN KEY (id_mesa) REFERENCES MESA(id_mesa),
    CONSTRAINT fk_pedido_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS COMANDA (
    id_comanda INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_pedido INT UNSIGNED NOT NULL,
    numero_ronda SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id_comanda),
    UNIQUE KEY uq_comanda_ronda (id_pedido, numero_ronda),
    CONSTRAINT fk_comanda_pedido
        FOREIGN KEY (id_pedido) REFERENCES PEDIDO(id_pedido)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS DETALLE_COMANDA (
    id_detalle INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_comanda INT UNSIGNED NOT NULL,
    id_producto VARCHAR(15) NOT NULL,
    cantidad SMALLINT UNSIGNED NOT NULL,
    estado_item ENUM('PENDIENTE','EN_PREPARACION','LISTO','ENTREGADO','CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
    prioridad VARCHAR(12) NOT NULL,
    nota VARCHAR(250),
    iniciado_en TIME,
    listo_en TIME,
    entregado_en TIME,
    PRIMARY KEY (id_detalle),
    CONSTRAINT fk_detalle_comanda
        FOREIGN KEY (id_comanda) REFERENCES COMANDA(id_comanda),
    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto),
    CONSTRAINT fk_detalle_prioridad
        FOREIGN KEY (prioridad) REFERENCES PRIORIDAD(id_prioridad)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS MODIFICADOR (
    id_modificador INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(80) NOT NULL,
    precio_extra DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (id_modificador)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS DETALLE_MODIFICADOR (
    id_detalle_mod INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_detalle INT UNSIGNED NOT NULL,
    id_modificador INT UNSIGNED,
    PRIMARY KEY (id_detalle_mod),
    UNIQUE KEY uq_detalle_modificador (id_detalle, id_modificador),
    CONSTRAINT fk_detmod_detalle
        FOREIGN KEY (id_detalle) REFERENCES DETALLE_COMANDA(id_detalle),
    CONSTRAINT fk_detmod_modificador
        FOREIGN KEY (id_modificador) REFERENCES MODIFICADOR(id_modificador)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS COMPROBANTE (
    id_comprobante INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_pedido INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED,
    id_usuario INT UNSIGNED NOT NULL,
    tipo ENUM('BOLETA','FACTURA','NOTA_VENTA','NOTA_CREDITO') NOT NULL,
    impuestos DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (id_comprobante),
    CONSTRAINT fk_comprobante_pedido
        FOREIGN KEY (id_pedido) REFERENCES PEDIDO(id_pedido),
    CONSTRAINT fk_comprobante_cliente
        FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente),
    CONSTRAINT fk_comprobante_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PAGO (
    id_pago INT UNSIGNED NOT NULL AUTO_INCREMENT,
    id_comprobante INT UNSIGNED NOT NULL,
    id_caja_sesion INT UNSIGNED NOT NULL,
    metodo ENUM('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFERENCIA') NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    monto_recibido DECIMAL(12,2),
    vuelto DECIMAL(12,2),
    PRIMARY KEY (id_pago),
    CONSTRAINT fk_pago_comprobante
        FOREIGN KEY (id_comprobante) REFERENCES COMPROBANTE(id_comprobante),
    CONSTRAINT fk_pago_caja
        FOREIGN KEY (id_caja_sesion) REFERENCES CAJA_SESION(id_caja_sesion)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS REFRESH_TOKEN (
    id_token CHAR(36) NOT NULL,
    id_usuario INT UNSIGNED NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    dispositivo VARCHAR(255),
    ip VARCHAR(45),
    expira_en DATETIME NOT NULL,
    revocado TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_token),
    UNIQUE KEY uq_refresh_token_hash (token_hash),
    CONSTRAINT fk_refresh_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS AUDITORIA (
    id_auditoria INT UNSIGNED NOT NULL AUTO_INCREMENT,
    tabla VARCHAR(60) NOT NULL,
    id_registro VARCHAR(40),
    accion CHAR(1) NOT NULL,
    datos_antes JSON,
    datos_despues JSON,
    id_usuario INT UNSIGNED,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_auditoria),
    CONSTRAINT fk_auditoria_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS HISTORIAL_ESTADO (
    id_historial INT UNSIGNED NOT NULL AUTO_INCREMENT,
    entidad VARCHAR(30) NOT NULL,
    id_entidad INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(30),
    estado_nuevo VARCHAR(30) NOT NULL,
    id_usuario INT UNSIGNED,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_historial),
    CONSTRAINT fk_historial_usuario
        FOREIGN KEY (id_usuario) REFERENCES USUARIO(id_usuario)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS PARAMETRO_SISTEMA (
    clave VARCHAR(60) NOT NULL,
    valor VARCHAR(255) NOT NULL,
    descripcion VARCHAR(255),
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (clave)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
