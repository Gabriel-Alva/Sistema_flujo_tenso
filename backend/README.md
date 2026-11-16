# Chifa Sipán API

Este directorio contiene el backend Laravel. Para instalación MySQL, roles de mínimo privilegio, configuración HTTPS y comandos de aprovisionamiento, sigue las instrucciones de [README.md](../README.md).

## Desarrollo local

Requiere PHP 8.3+, Composer y MySQL 8.0.16+. Crea `.env` desde `.env.example`, configura `DB_ADMIN_*` para el instalador y credenciales `sipan_app_rw` para la ejecución normal.

```powershell
composer install
php artisan key:generate
php artisan sipan:install-schema --seed
php artisan serve
```

`--seed` solo crea usuarios de demostración fuera de producción y requiere `SIPAN_SEED_PASSWORD` (mínimo 16 caracteres). Las migraciones de esquema deben ejecutarse con la cuenta administrativa, no con la cuenta de ejecución.

El panel administrativo usa las rutinas de `database/schema/070_admin_operations.sql` para el dashboard, catálogo, personal, salón, finanzas, reportes, auditoría y parámetros protegidos por contraseña. El dashboard muestra ventas emitidas de los últimos siete días y estados de pedidos del día. El catálogo permite previsualizar URLs HTTPS o rutas públicas de imágenes antes de guardar; el catálogo y el salón editan en modales, y finanzas ofrece previsualización de comprobantes. Caja usa `database/schema/080_cashier_dashboard.sql` para consultar comandas cuyos ítems ya están listos o entregados y mostrar sus propias ventas, medios de pago y pedidos de los últimos siete días. El instalador aplica ambos archivos después de las vistas y triggers. Para una base existente, respalda primero y ejecuta `php artisan sipan:install-schema` con una cuenta administrativa; una contraseña vacía se admite solo en `APP_ENV=local` para instalaciones WAMP locales, nunca en producción. No ejecutes las escrituras con el usuario de aplicación.

El monitor KDS agrupa los ítems por comanda/ronda y muestra su avance por estación mediante `vw_cola_cocina_activa`; los ítems listos permanecen visibles hasta que salón los entrega. El endpoint ordena las prioridades urgentes primero y la vista incluye miniaturas. Los procedimientos `sp_kitchen_update_item_status` y `sp_kitchen_cancel_command` validan, registran y cambian estados transaccionalmente. Los cocineros solo pueden modificar productos de su estación; una comanda completa solo se cancela antes de iniciar la preparación, afecta únicamente los ítems pendientes de esa estación y exige motivo. En una base existente, aplica `database/schema/021_kitchen_queue_view.sql` y `database/schema/031_kitchen_item_status.sql` con una cuenta administrativa.
