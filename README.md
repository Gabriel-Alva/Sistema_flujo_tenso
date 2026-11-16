# Chifa Sipán — ERP/POS

Monorepo con backend Laravel, MySQL 8 y clientes Flutter, Vue y React. La estructura y los contratos de dominio se describen en el [plan maestro](./plan_maestro_de_arquitectura_e_ingenier_a_chifa_sipan_v3_1.md).

## Requisitos

- PHP 8.3+, Composer
- MySQL 8.0.16+ (InnoDB; `CHECK` debe estar habilitado)
- Cliente `mysql.exe` disponible en `PATH` o configurado mediante `MYSQL_CLIENT`
- Node.js 20+ para las interfaces web
- Flutter estable compatible con Dart SDK 3.13
- HTTPS, DNS y certificados válidos para producción

## Base de datos y backend

1. Crea `backend\.env` desde `backend\.env.example`; define `DB_ADMIN_USERNAME` y `DB_ADMIN_PASSWORD` para el instalador, y credenciales distintas de aplicación en `DB_USERNAME` y `DB_PASSWORD`. Mantén `APP_DEBUG=false` y `APP_ENV=production` en producción.
2. Ejecuta el instalador con una cuenta administrativa MySQL:

   ```powershell
   Set-Location backend
   php artisan sipan:install-schema
   ```

3. El instalador crea los roles `sipan_app_role` y `sipan_reporting_role`. Crea usuarios con contraseñas aleatorias fuera del repositorio y asigna los roles:

   ```sql
   CREATE USER 'sipan_app_rw'@'10.%' IDENTIFIED BY '<secreto-aleatorio>';
   GRANT sipan_app_role TO 'sipan_app_rw'@'10.%';
   SET DEFAULT ROLE sipan_app_role TO 'sipan_app_rw'@'10.%';

   CREATE USER 'sipan_reporting_ro'@'10.%' IDENTIFIED BY '<secreto-aleatorio>';
   GRANT sipan_reporting_role TO 'sipan_reporting_ro'@'10.%';
   SET DEFAULT ROLE sipan_reporting_role TO 'sipan_reporting_ro'@'10.%';
   ```

   Sustituye `10.%` por el origen de red real y guarda las contraseñas en un gestor de secretos. No uses `root` como cuenta de la aplicación.
4. Completa `DB_PASSWORD`, `CORS_ALLOWED_ORIGINS` y `MYSQL_ATTR_SSL_CA` según tu entorno. Activa HTTPS y `SESSION_SECURE_COOKIE=true`; no publiques MySQL ni Redis a Internet.
5. Para sembrar datos de referencia en producción, ejecuta `php artisan db:seed --database=mysql_admin --force`. El seeder no crea usuarios de demostración en producción. Crea cada persona y cuenta administrativa con `php artisan sipan:user-create <usuario> ADMINISTRADOR`; las contraseñas se solicitan ocultas en la terminal.
6. Inicia el servidor detrás de un proxy HTTPS administrado y limita el acceso a la red interna. `php artisan serve` es solo para desarrollo.

Para datos de demostración en desarrollo, define `SIPAN_SEED_PASSWORD` fuera del repositorio con al menos 16 caracteres y ejecuta `php artisan sipan:install-schema --seed`. No reutilices esa contraseña en producción.

## Interfaces

React y Vue usan `http://localhost:8000/api/v1` por defecto. Si defines `VITE_API_BASE`, usa también `localhost` (no `127.0.0.1`) para mantener el mismo origen de cookies de sesión. Para probar Flutter en un emulador Android, inicia el backend del equipo anfitrión con `php artisan serve --host=0.0.0.0 --port=8000`; la app usa `http://10.0.2.2:8000/api/v1` por defecto en Android. En un teléfono físico configura `API_BASE` con la IP LAN del equipo y habilita el acceso al puerto 8000 en el firewall de la red privada. HTTP solo debe utilizarse en desarrollo local.

Para ejecutar Meseros como aplicación Windows, usa `flutter run -d windows --dart-define=API_BASE=http://127.0.0.1:8000/api/v1`. Para Android Emulator, abre primero un emulador (`flutter emulators --launch Medium_Phone_API_37.0`), confirma el identificador con `flutter devices` y ejecuta `flutter run -d <id-android> --dart-define=API_BASE=http://10.0.2.2:8000/api/v1`.

Para ejecutar Meseros en Edge, usa `flutter run -d edge --web-port=5174 --dart-define=API_BASE=http://127.0.0.1:8000/api/v1`. En desarrollo (`APP_ENV=local`), CORS también acepta el puerto local elegido por Flutter Web.

El panel Admin incluye dashboard con gráficas reales de ventas de los últimos siete días y estados de pedidos, gestión del catálogo, personal, zonas y mesas, finanzas, reportes, auditoría y parámetros protegidos por revalidación de contraseña. El catálogo permite previsualizar las imágenes al escribir su URL o ruta pública; los productos y comprobantes tienen vistas previas responsive. Las escrituras administrativas pasan por procedimientos transaccionales y los cambios de configuración quedan auditados. Para desplegar el esquema administrativo se aplica `backend/database/schema/070_admin_operations.sql` junto con las rutinas existentes. En una instalación nueva, `php artisan sipan:install-schema` lo ejecuta en el orden requerido; en una base existente, realiza respaldo y aplica el instalador con una cuenta administrativa antes de iniciar la app.

En Mesero, el botón **Pedidos activos** permite consultar el estado de cada pedido, registrar una nueva ronda mientras siga abierto y marcar como entregados los platos listos. Estas operaciones requieren los procedimientos de `backend/database/schema/030_procedures.sql`.

```powershell
Set-Location apps\cashier_react
npm ci
npm run build

Set-Location ..\kitchen_vue
npm ci
npm run build

Set-Location ..\waiter_flutter
flutter pub get
flutter analyze
flutter test
```

La app móvil no habilita certificate pinning sin el certificado/clave pública de producción y un proceso de rotación definido; no inventes un pin.
