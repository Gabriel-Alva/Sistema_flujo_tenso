# CHIFA SIPÁN — Plan Maestro de Arquitectura, Construcción e Integración (v3.1)

**Sistema Integral de Gestión Operativa (ERP/POS Restaurante) con Blindaje de Base de Datos y Seguridad Anti-Phishing**

*Stack: MySQL 8.0+ (SPs, Views, Triggers, Constraints) • Laravel 11+ (Monolito Modular + Blade + Reverb) • Flutter (Clean Architecture) • Vue 3 (Pinia + Composition API) • React 18+ (TypeScript + TanStack Query)*

---

## 1. Resumen Ejecutivo y Gobierno Técnico

| Parámetro | Definición Técnica |
| :--- | :--- |
| **Proyecto** | Ecosistema operativo interno para **Chifa Sipán** (Salón, Para Llevar, Delivery, Cocina, Caja y Administración). |
| **Topología** | Monolito Modular en Backend con 4 clientes desacoplados comunicados vía API REST versionada (`/api/v1`) y WebSockets. |
| **Base de Datos** | MySQL 8.0+ (`InnoDB`, `utf8mb4`, `utf8mb4_0900_ai_ci`). Línea base de 29 tablas + migraciones correctivas + **Capa Lógica SQL (SPs, Vistas y Triggers)**. |
| **Fuente de Verdad** | **Laravel + MySQL** actúan como doble anillo de autoridad: Laravel orquesta contratos HTTP/eventos y MySQL garantiza invariantes contables e integridad medianteTriggers y Procedimientos Almacenados. |
| **Blindaje Anti-Phishing** | Autenticación vinculada a origen criptográfico (**Passkeys/WebAuthn**, cookies `__Host-` `HttpOnly` `SameSite=Strict`, Pinning en móvil y CSP estricto). |
| **Contratos** | OpenAPI 3.1 (`contracts/openapi.yaml`) y Design Tokens (`packages/design_tokens/tokens.json`) como artefactos compartidos. |

---

## 2. Arquitectura del Repositorio (Monorepo)

```text
chifa-sipan/
├── backend/                        # Núcleo Laravel (API REST, WebSockets, Panel Admin Blade)
├── apps/
│   ├── waiter_flutter/             # App Móvil Meseros (Android/iOS)
│   ├── kitchen_vue/                # KDS - Kitchen Display System (Pantallas táctiles/monitores)
│   └── cashier_react/              # POS Caja (Desktop/Tablet)
├── packages/
│   └── design_tokens/              # Fuente única de verdad visual (tokens.json -> CSS / Dart)
├── contracts/
│   └── openapi.yaml                # Especificación formal de endpoints, DTOs y códigos de error
├── docs/                           # DER, Diccionario de Datos, ADRs y Guías de Despliegue
└── docker-compose.yml              # Orquestación local (MySQL 8, Redis, PHP-FPM, Nginx, Reverb)
```

---

## 3. Ingeniería y Blindaje de Base de Datos (MySQL 8.0+)

Para evitar lógica dispersa, garantizar velocidad en consultas pesadas y blindar la integridad financiera incluso si ocurriera un error en la capa de aplicación, MySQL implementará una **arquitectura defensiva en cuatro niveles**:

### 3.1. Migraciones de Remediación Previa
1. **Snapshot Financiero y de Catálogo (`DETALLE_COMANDA` y `DETALLE_MODIFICADOR`):** Añadir `id_variante` (nullable), `nombre_snapshot`, `precio_unitario_venta` e `id_estacion_cocina` en `DETALLE_COMANDA`; añadir `nombre_snapshot` y `precio_venta` en `DETALLE_MODIFICADOR`.
2. **Máquina de Estados y Concurrencia (`PEDIDO`, `COMANDA`, `DETALLE_COMANDA`):** Añadir `estado` (`ENUM`), `version` (`INT UNSIGNED DEFAULT 1`), `updated_at` (`TIMESTAMP`) en `PEDIDO`. Migrar horas a `DATETIME` en rondas e ítems.
3. **Contexto de Entrega y Clientes (`PEDIDO`, `CLIENTE`):** Hacer nullable `id_direccion` en `CLIENTE`. Añadir `id_cliente`, `id_direccion_entrega` y `direccion_snapshot` (`JSON`) en `PEDIDO`.
4. **Enrutamiento a Estaciones (`PRODUCTO_ESTACION`):** Crear tabla pivote `PRODUCTO_ESTACION` (`id_producto`, `id_estacion`, `es_principal`).
5. **Idempotencia y Libro de Caja (`PEDIDO`, `PAGO`, `MOVIMIENTO_CAJA`, `COMPROBANTE`):** Añadir `client_request_id` (`CHAR(36) UNIQUE`) en `PEDIDO` y `COMANDA`; `payment_request_id` (`CHAR(36) UNIQUE`) en `PAGO`. Crear `MOVIMIENTO_CAJA` y ampliar `COMPROBANTE` con serie, correlativo, subtotal, IGV, total, estado y referencia externa.

### 3.2. Vistas (Views) para Lectura Optimizada y Desacoplamiento
Las vistas encapsulan los `JOIN` complejos de las 29+ tablas para que los módulos de Cocina, Caja y Reportes consulten estructuras planas y pre-calculadas:

* **`vw_cola_cocina_activa`:** Une `DETALLE_COMANDA`, `COMANDA`, `PEDIDO`, `MESA`, `ZONA`, `PRIORIDAD` y agrupa `DETALLE_MODIFICADOR` (`GROUP_CONCAT`). Filtra únicamente ítems en estado `PENDIENTE` o `EN_PREPARACION` y calcula en tiempo real los minutos transcurridos (`TIMESTAMPDIFF(MINUTE, fecha_envio, NOW())`).
* **`vw_resumen_cuenta_pedido`:** Calcula de forma autoritativa el subtotal de ítems no cancelados, suma de modificadores, base imponible, impuestos y saldo pendiente descontando pagos confirmados en `PAGO`.
* **`vw_estado_salon_tiempo_real`:** Muestra cada `MESA` con su `ZONA`, estado actual, ID de pedido activo (si existe), nombre del mesero asignado, cantidad de comensales y tiempo de ocupación.
* **`vw_arqueo_sesion_caja`:** Consolida por cada `CAJA_SESION` el monto inicial, ingresos por método de pago (`EFECTIVO`, `TARJETA`, `YAPE`, `PLIN`, `TRANSFERENCIA`), movimientos manuales de `MOVIMIENTO_CAJA` y el saldo teórico esperado en gaveta.
* **`vw_auditoria_legible`:** Cruza `AUDITORIA` y `HISTORIAL_ESTADO` con `USUARIO` y `PERSONA` para mostrar quién ejecutó cada acción crítica sin exponer hashes ni tokens.

### 3.3. Procedimientos Almacenados (Stored Procedures) para Operaciones Críticas
Se utilizarán procedimientos almacenados transaccionales con manejo de errores (`DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK`) para operaciones donde la atomicidad e idempotencia deben residir junto al dato:

* **`sp_registrar_ronda_pedido(...)`:**
  * Verifica idempotencia mediante `client_request_id`.
  * Bloquea la fila de `PEDIDO` (o `MESA` si es pedido nuevo de salón) con `SELECT ... FOR UPDATE` para evitar condiciones de carrera entre dos meseros.
  * Crea la `COMANDA` (ronda $N+1$), inserta los `DETALLE_COMANDA` leyendo los precios vigentes desde `PRODUCTO`/`PLATO_VARIANTE` y congelándolos en el snapshot, asigna automáticamente la `id_estacion_cocina` desde `PRODUCTO_ESTACION` y registra el hito en `HISTORIAL_ESTADO`.
* **`sp_registrar_pago_y_cerrar_cuenta(...)`:**
  * Verifica `payment_request_id` único y comprueba que la `CAJA_SESION` esté `ABIERTA` y pertenezca al cajero autenticado.
  * Valida que el monto abonado no exceda el saldo pendiente (salvo efectivo, donde calcula y devuelve el vuelto exacto).
  * Inserta en `PAGO`, actualiza el estado del `PEDIDO` a `PAGADO` si el saldo llega a `0.00`, libera la `MESA` asociada y registra el evento en `HISTORIAL_ESTADO`.
* **`sp_cerrar_sesion_caja(...)`:**
  * Bloquea la sesión de caja, invoca los totales de `vw_arqueo_sesion_caja`, registra el monto declarado por el cajero, calcula la diferencia (sobrante/faltante), cierra la sesión y graba el registro inmutable en `AUDITORIA`.

### 3.4. Triggers, Restricciones `CHECK` y Eventos Programados
Los triggers actúan como **última línea de defensa** (ningún usuario de aplicación puede saltárselos, ni siquiera mediante una consulta directa):

* **Triggers de Inmutabilidad Financiera (`trg_detalle_comanda_before_update` / `before_delete`):** Impiden modificar precios o eliminar registros de `DETALLE_COMANDA` una vez que la comanda fue enviada a cocina; cualquier anulación debe pasar por cambio de estado a `CANCELADO` con motivo obligatorio.
* **Triggers de Auditoría Automática (`trg_producto_after_update`, `trg_usuario_after_update`, `trg_parametro_after_update`):** Detectan cambios en `precio`, `activo`, `bloqueado_hasta` o tasas de impuesto e insertan automáticamente el valor anterior y el nuevo en `AUDITORIA` en formato JSON.
* **Triggers de Sincronización de Mesa (`trg_pedido_after_insert` / `after_update`):** Garantizan que al abrir un pedido `SALON`, la `MESA` pase automáticamente a `OCUPADA`, y al pasar el pedido a `PAGADO` o `ANULADO`, la mesa regrese a `DISPONIBLE` solo si no tiene otro pedido activo.
* **Triggers de Protección de Logs (`trg_auditoria_no_delete`, `trg_historial_no_delete`):** Bloquean mediante `SIGNAL SQLSTATE '45000'` cualquier intento de `UPDATE` o `DELETE` sobre `AUDITORIA` e `HISTORIAL_ESTADO`, convirtiéndolas en tablas estrictamente *append-only*.
* **Restricciones `CHECK` en MySQL 8.0+:**
  * `CHK_PEDIDO_MESA_COHERENCIA`: `(tipo_pedido = 'SALON' AND id_mesa IS NOT NULL) OR (tipo_pedido IN ('LLEVAR', 'DELIVERY') AND id_mesa IS NULL)`.
  * `CHK_MONTOS_POSITIVOS`: `cantidad > 0 AND precio_unitario_venta >= 0`.
* **MySQL Event Scheduler (`evt_limpiar_tokens_expirados`):** Evento nocturno automático que purga registros vencidos de `REFRESH_TOKEN` para mantener el índice compacto.

### 3.5. Principio de Mínimo Privilegio en Usuarios de BD
La aplicación Laravel **no se conectará como `root`**. Se crearán cuentas segregadas en MySQL:
* `sipan_app_rw`: Permisos `SELECT`, `INSERT`, `UPDATE` sobre tablas operativas y `EXECUTE` sobre los `sp_*`. **Sin permiso `DELETE`** en tablas transaccionales ni de auditoría, y sin `DROP`/`ALTER`.
* `sipan_reporting_ro`: Permisos únicamente de `SELECT` sobre las vistas `vw_*` para exportación de reportes pesados.

---

## 4. Arquitectura de Seguridad y Defensa Anti-Phishing

Dado que el sistema opera múltiples interfaces (Web Admin, Web Caja, Web Cocina y App Móvil Meseros) donde los atacantes podrían intentar clonar pantallas de login (*phishing de credenciales*) o secuestrar sesiones, se implementan controles criptográficos y de origen estricto:

### 4.1. Mitigación Técnica de Phishing y Suplantación de Identidad
1. **Autenticación Vinculada al Origen (WebAuthn / Passkeys) para Roles Críticos:**
   * Los perfiles `ADMINISTRADOR` y `CAJERO` soportarán inicio de sesión con **Passkeys / llaves de seguridad FIDO2** (además de contraseña robusta). Dado que WebAuthn firma criptográficamente el dominio exacto (`rpId`, ej. `pos.chifasipan.pe`), **un sitio clonado o dominio falso jamás recibirá una firma válida**, neutralizando el phishing de credenciales al 100%.
2. **Cookies Blindadas con Prefijo `__Host-`:**
   * Para las aplicaciones web (Admin Blade, Cocina Vue, Caja React), los tokens de renovación se envían exclusivamente en cookies con prefijo `__Host-sipan_refresh`, exigiendo por estándar del navegador: `Secure` (solo HTTPS), `HttpOnly` (inaccesible vía JavaScript/XSS), `Path=/` y `SameSite=Strict` (inmune a CSRF).
3. **Aislamiento de Subdominios y Políticas de Navegador:**
   * Cada frente web vive en un subdominio explícito bajo HSTS (`Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`):
     * `admin.chifasipan.pe` (Panel Laravel Blade)
     * `caja.chifasipan.pe` (POS React)
     * `cocina.chifasipan.pe` (KDS Vue)
   * **Content Security Policy (CSP) y `frame-ancestors 'none'`:** Impide que las pantallas reales del sistema sean incrustadas dentro de un `<iframe>` en páginas trampa (*Clickjacking*) y bloquea la ejecución de scripts externos no firmados mediante *nonces*.
4. **Certificate Pinning y Almacenamiento Hardware en Flutter:**
   * La app móvil `waiter_flutter` implementa **TLS Certificate Pinning** contra la clave pública del servidor API (evitando ataques *Man-in-the-Middle* en redes Wi-Fi comprometidas del restaurante) y almacena credenciales en *Android Keystore / iOS Keychain* con desbloqueo biométrico local.
5. **Detección de Reutilización de Refresh Tokens (*Token Theft Detection*):**
   * Cada `REFRESH_TOKEN` tiene un `family_id`. Si un token ya rotado vuelve a ser presentado (señal de robo de sesión o phishing), Laravel revoca inmediatamente **toda la familia de tokens** del usuario, cierra sus sesiones activas y dispara una alerta de seguridad en `AUDITORIA`.
6. **Bloqueo de Enlaces Externos y Sanitización de Entradas:**
   * Ningún campo de notas de pedido, dirección de delivery o nombre de cliente renderiza HTML crudo; las notificaciones internas carecen de enlaces externos clicables para evitar vectores de ingeniería social hacia cajeros o administradores.

---

## 5. Arquitectura del Backend (Laravel)

Se adopta una **Arquitectura Modular Orientada al Dominio (Modular Monolith)** con separación estricta de responsabilidades: los Controladores **no contienen lógica de negocio**; delegan en *Actions/Services* (los cuales invocan los Procedimientos Almacenados cuando corresponde), validan con *FormRequests*, transforman con *API Resources* y disparan *Events* tras el `DB::commit()`.

### 5.1. Estructura de Archivos del Backend

```text
backend/
├── app/
│   ├── Console/Commands/           # Tareas programadas y monitoreo de salud
│   ├── Core/                       # Infraestructura transversal
│   │   ├── Auth/                   # Custom UserProvider (USUARIO.password_hash), WebAuthn y JWT
│   │   ├── Exceptions/             # DomainException, ConcurrencyException, StateTransitionException
│   │   ├── Http/Middleware/        # ForceJsonResponse, SecurityHeadersCsp, CheckRoleContext, AuditRequest
│   │   └── Traits/                 # HasAuditLog, HasOptimisticLock, CallsStoredProcedures
│   ├── Modules/
│   │   ├── Identity/               # PERSONA, USUARIO, Roles, Passkeys y REFRESH_TOKEN
│   │   ├── Catalog/                # PRODUCTO, PLATO, BEBIDAS, VARIANTE, MODIFICADOR, PRIORIDAD
│   │   ├── Salon/                  # ZONA, MESA y lectura de vw_estado_salon_tiempo_real
│   │   ├── Orders/                 # PEDIDO, COMANDA, DETALLE_COMANDA e invocación a sp_registrar_ronda_pedido
│   │   ├── Kitchen/                # Lectura de vw_cola_cocina_activa, transiciones KDS y alertas SLA
│   │   ├── Billing/                # CAJA_SESION, COMPROBANTE, PAGO e invocación a sp_registrar_pago_y_cerrar_cuenta
│   │   └── Reporting/              # Consultas sobre vistas vw_* y exportación Excel/PDF
│   └── Providers/
│       ├── AppServiceProvider.php
│       └── BroadcastServiceProvider.php
├── bootstrap/
│   └── app.php                     # Registro global de excepciones JSON estandarizadas (RFC 7807)
├── database/
│   ├── migrations/                 # Migraciones incrementales, Vistas (vw_*), SPs (sp_*) y Triggers (trg_*)
│   └── seeders/                    # Roles base, parámetros de sistema, prioridades y admin inicial
├── resources/
│   ├── css/                        # Importa packages/design_tokens/dist/tokens.css
│   └── views/                      # Panel Administrativo Blade (Layout, Componentes, Vistas por módulo)
└── routes/
    ├── api_v1.php                  # Endpoints REST versionados
    ├── channels.php                # Autorización de canales privados WebSocket (ej. kitchen.station.{id})
    └── web.php                     # Rutas del panel administrativo Blade
```

### 5.2. Anatomía Interna de un Módulo (Ejemplo: `app/Modules/Orders/`)

```text
app/Modules/Orders/
├── Actions/
│   ├── CreateOrderWithRoundAction.php  # Invoca sp_registrar_ronda_pedido y despacha eventos post-commit
│   ├── AddOrderRoundAction.php         # Añade nueva COMANDA vía SP sin mutar rondas previas
│   └── CancelOrderItemAction.php       # Valida permisos, registra motivo y audita anulación
├── DTOs/
│   ├── CreateOrderData.php             # Objeto inmutable tipado (readonly properties PHP 8.2+)
│   └── OrderItemData.php
├── Enums/
│   ├── OrderType.php                   # SALON, LLEVAR, DELIVERY
│   ├── OrderStatus.php                 # ABIERTO, EN_PAGO, PAGADO, ANULADO
│   └── ItemKitchenStatus.php           # PENDIENTE, EN_PREPARACION, LISTO, ENTREGADO, CANCELADO
├── Events/
│   ├── OrderRoundSent.php              # Implementa ShouldBroadcastAfterCommit -> canal cocina
│   └── OrderItemStateChanged.php       # Notifica a meseros cuando un ítem pasa a LISTO
├── Http/
│   ├── Controllers/
│   │   └── OrderController.php         # Máximo 10-15 líneas por método. Solo Request -> Action -> Resource
│   ├── Requests/
│   │   ├── StoreOrderRequest.php       # Validación de estructura, tipos, mesa vs delivery, client_request_id
│   │   └── StoreRoundRequest.php
│   └── Resources/
│       ├── OrderResource.php           # Contrato JSON exacto expuesto al frontend
│       └── OrderRoundResource.php
├── Models/
│   ├── Pedido.php                      # $table = 'PEDIDO'; $primaryKey = 'id_pedido'; relaciones Eloquent
│   ├── Comanda.php                     # $table = 'COMANDA'; $primaryKey = 'id_comanda';
│   └── DetalleComanda.php              # $table = 'DETALLE_COMANDA'; $primaryKey = 'id_detalle_comanda';
└── Policies/
    └── OrderPolicy.php                 # Autorización granular por rol y propiedad del pedido
```

---

## 6. Arquitectura de las Interfaces (Frontends)

### 6.1. Panel Administrativo (`backend/resources/views` — Laravel Blade + Alpine.js)
* **Estructura de Vistas:** `layouts/admin.blade.php` (Sidebar, topbar, notificaciones toast), `components/ui/` (`button`, `table`, `badge`, `modal`, `stat-card`) y `pages/{catalog,staff,salon,finance,audit,reports}/`.
* **Construcción:** SSR con protección CSRF nativa, autenticación reforzada con Passkeys/WebAuthn para administradores y consumo directo de las vistas `vw_auditoria_legible` y `vw_arqueo_sesion_caja` para reportes gerenciales ultrarrápidos.

### 6.2. App Meseros (`apps/waiter_flutter` — Flutter / Dart)
Diseñada bajo **Clean Architecture + MVVM (Riverpod)**, optimizada para operación táctil rápida y resiliencia offline.

```text
apps/waiter_flutter/lib/
├── main.dart                       # Inicialización de almacenamiento seguro, Hive/Isar y ProviderScope
├── core/
│   ├── config/                     # EnvConfig (URLs base, hashes SSL Pinning)
│   ├── network/                    # DioClient, CertificatePinningInterceptor, AuthInterceptor, RetryInterceptor
│   ├── storage/                    # FlutterSecureStorage (tokens) + LocalDraftStorage (borradores)
│   ├── theme/                      # AppTheme generado desde packages/design_tokens/dist/tokens.dart
│   └── widgets/                    # Botones táctiles (min 48x48dp), badges de estado, banner offline
├── features/
│   ├── auth/                       # Login, biometría local, selección de perfil activo
│   ├── salon/                      # Mapa visual de zonas y mesas (consumiendo vw_estado_salon_tiempo_real)
│   ├── menu/                       # Catálogo cacheado localmente, búsqueda rápida, modal variantes/modificadores
│   ├── order_cart/                 # Carrito por ronda, cola de envío offline con UUID v4 idempotente
│   └── active_orders/              # Seguimiento en vivo de ítems, notificaciones de "LISTO" y "ENTREGADO"
└── shared/
    └── domain/                     # Entidades compartidas (User, Product, OrderStatusEnum)
```

### 6.3. Monitor de Cocina — KDS (`apps/kitchen_vue` — Vue 3 + TypeScript + Pinia)
Diseñado para lectura a distancia (2 a 3 metros), alto contraste y actualización en tiempo real por estación.

```text
apps/kitchen_vue/src/
├── main.ts                         # Arranque Vue 3, Pinia y suscripción global a tokens.css
├── core/
│   ├── api/                        # Cliente Axios tipado + manejo de cookies __Host-
│   ├── realtime/                   # Laravel Echo + Reverb client con reconexión exponencial
│   └── audio/                      # Gestor de alertas sonoras (nueva comanda / pedido urgente)
├── stores/
│   ├── auth.store.ts               # Sesión del cocinero y estación asignada (station_id)
│   └── queue.store.ts              # Estado reactivo alimentado por vw_cola_cocina_activa
├── components/
│   ├── layout/
│   │   └── KdsHeader.vue           # Nombre de estación, reloj en vivo, indicador de conexión WS y filtros
│   └── tickets/
│       ├── OrderTicketCard.vue     # Tarjeta de comanda: N° pedido, tipo, mesa, timer SLA
│       ├── TicketItemRow.vue       # Ítem, variante, modificadores resaltados, notas
│       └── CancelItemModal.vue     # Solicitud de motivo y autorización de supervisor para cancelar
├── views/
│   ├── LoginView.vue               # Acceso rápido por usuario/estación
│   └── StationBoardView.vue        # Grid de tickets ordenados por prioridad y antigüedad
└── composables/
    └── useTicketTimer.ts           # Hook reactivo de tiempo transcurrido y alertas visuales SLA
```

### 6.4. Terminal de Caja — POS (`apps/cashier_react` — React 18 + TypeScript + TanStack Query)
Diseñado para precisión contable absoluta, emisión de comprobantes y arqueo estricto.

```text
apps/cashier_react/src/
├── main.tsx                        # QueryClientProvider, AuthProvider, ErrorBoundary global
├── core/
│   ├── api/                        # Fetch/Axios wrapper con manejo de errores RFC 7807 y cookies __Host-
│   └── utils/                      # Formateadores de moneda (PEN S/), validadores RUC/DNI
├── features/
│   ├── auth/                       # Login de cajero con soporte WebAuthn/Passkeys y verificación de turno
│   ├── cash-session/               # Apertura de Caja, Movimientos (Ingresos/Egresos) y Cierre (vw_arqueo_sesion_caja)
│   ├── orders-board/               # Listado de cuentas abiertas (Salón, Llevar, Delivery)
│   └── checkout/                   # Pantalla dividida: Detalle de consumo (izq) + Emisión y Pagos (der)
│       ├── components/
│       │   ├── OrderSummaryPanel.tsx   # Muestra subtotales, IGV y total desde vw_resumen_cuenta_pedido
│       │   ├── CustomerBillingForm.tsx # Búsqueda/creación de cliente para Boleta/Factura/Nota
│       │   ├── PaymentMethodsGrid.tsx  # Selector Efectivo, Tarjeta, Yape, Plin, Transferencia + Ref.
│       │   └── SplitPaymentList.tsx    # Gestión de pagos mixtos con payment_request_id único por abono
│       └── hooks/
│           └── useProcessPayment.ts    # Mutación TanStack Query invocando sp_registrar_pago_y_cerrar_cuenta
└── shared/
    └── components/                 # Componentes UI alineados a tokens.css (Modal, DataTable, CurrencyInput)
```

---

## 7. Sistema de Diseño Compartido (`packages/design_tokens`)

```text
packages/design_tokens/
├── tokens.json                     # Definición agnóstica: colores semánticos, tipografía, espaciados, radios
├── build.js                        # Script Node.js (Style Dictionary) que compila los tokens
└── dist/
    ├── tokens.css                  # Variables CSS (:root { --color-status-ready: #16A34A; ... })
    └── tokens.dart                 # Clase Dart (class SipanTokens { static const statusReady = Color(0xFF16A34A); })
```

* **Semántica Unificada de Estados:**
  * `PENDIENTE`: Ámbar (`#D97706`)
  * `EN_PREPARACION`: Azul (`#2563EB`)
  * `LISTO`: Verde Esmeralda (`#16A34A`)
  * `ENTREGADO`: Gris Neutro (`#4B5563`)
  * `CANCELADO / ANULADO`: Rojo Carmesí (`#DC2626`)

---

## 8. Estándares Transversales de Calidad, Contratos y Pruebas

1. **Contrato OpenAPI Primero (*Contract-First*):** Todo endpoint se define primero en `contracts/openapi.yaml`. Códigos HTTP estrictos: `200` (OK), `201` (Creado), `401` (No autenticado), `403` (Sin rol/permiso), `404` (No encontrado), `409` (Conflicto de estado o bloqueo optimista), `422` (Error de validación).
2. **Estructura Única de Errores (RFC 7807):**
   ```json
   {
     "code": "ORDER_TABLE_OCCUPIED",
     "message": "La mesa seleccionada ya tiene un pedido activo.",
     "field_errors": { "id_mesa": ["Mesa ocupada por el pedido #1042."] },
     "request_id": "req_9f8a7b6c5d4e"
   }
   ```
3. **Estrategia de Pruebas Automatizadas:**
   * **Base de Datos (MySQL Test Suite):** Pruebas directas contra `sp_registrar_ronda_pedido`, `sp_registrar_pago_y_cerrar_cuenta` y verificación de que los triggers `trg_*` rechacen modificaciones indebidas o borrados en `AUDITORIA`.
   * **Backend (Pest / PHPUnit):** Tests de integración para concurrencia (dos meseros tomando la misma mesa simultáneamente), detección de robo de *Refresh Token* y preservación de precios históricos.
   * **Frontends:** Tests unitarios en Stores/Hooks críticos (cálculo de carrito offline, timers KDS, bloqueo de doble cobro en Caja).