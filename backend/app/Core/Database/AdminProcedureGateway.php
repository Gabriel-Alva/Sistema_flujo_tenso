<?php

namespace App\Core\Database;

use App\Core\Exceptions\DomainException;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class AdminProcedureGateway
{
    private const READ_PROCEDURES = [
        'sp_admin_dashboard' => 0,
        'sp_admin_dashboard_graficos' => 0,
        'sp_admin_listar_parametros' => 0,
        'sp_admin_listar_categorias' => 0,
        'sp_admin_listar_estaciones' => 0,
        'sp_admin_listar_modificadores' => 0,
        'sp_admin_listar_prioridades' => 0,
        'sp_admin_listar_catalogo' => 2,
        'sp_admin_listar_variantes' => 0,
        'sp_admin_listar_personal' => 1,
        'sp_admin_listar_zonas' => 0,
        'sp_admin_listar_mesas' => 0,
        'sp_admin_resumen_financiero' => 2,
        'sp_admin_listar_comprobantes' => 1,
        'sp_admin_saldos_pendientes' => 0,
        'sp_admin_sesiones_caja' => 2,
        'sp_admin_reporte_ventas' => 2,
        'sp_admin_listar_auditoria' => 5,
    ];

    private const WRITE_PROCEDURES = [
        'sp_admin_guardar_producto' => 14,
        'sp_admin_guardar_variante' => 6,
        'sp_admin_guardar_categoria' => 4,
        'sp_admin_guardar_estacion' => 4,
        'sp_admin_guardar_modificador' => 5,
        'sp_admin_guardar_prioridad' => 5,
        'sp_admin_estado_producto' => 3,
        'sp_admin_crear_usuario' => 13,
        'sp_admin_estado_usuario' => 3,
        'sp_admin_guardar_zona' => 4,
        'sp_admin_guardar_mesa' => 6,
        'sp_admin_actualizar_parametro' => 3,
    ];

    /**
     * @param  array<int, mixed>  $bindings
     * @return array<int, object>
     */
    public function rows(string $name, array $bindings = []): array
    {
        $this->assertProcedure($name, $bindings, self::READ_PROCEDURES);

        try {
            return DB::select($this->callSql($name, count($bindings)), $bindings);
        } catch (QueryException $exception) {
            $this->throwDomainException($exception);
        }
    }

    /**
     * @param  array<int, mixed>  $bindings
     */
    public function execute(string $name, array $bindings): void
    {
        $this->assertProcedure($name, $bindings, self::WRITE_PROCEDURES);
        $connection = DB::connection();
        $connection->statement('SET @sipan_current_user_id = ?', [(int) $bindings[0]]);

        try {
            $connection->select($this->callSql($name, count($bindings)), $bindings);
        } catch (QueryException $exception) {
            $this->throwDomainException($exception);
        } finally {
            $connection->statement('SET @sipan_current_user_id = NULL');
        }
    }

    /**
     * @param  array<int, mixed>  $bindings
     * @param  array<string, int>  $allowlist
     */
    private function assertProcedure(string $name, array $bindings, array $allowlist): void
    {
        if (! isset($allowlist[$name]) || $allowlist[$name] !== count($bindings)) {
            throw new InvalidArgumentException('Procedimiento administrativo no permitido o parámetros inválidos.');
        }
    }

    private function callSql(string $name, int $parameterCount): string
    {
        return 'CALL '.$name.'('.implode(', ', array_fill(0, $parameterCount, '?')).')';
    }

    private function throwDomainException(QueryException $exception): never
    {
        $message = (string) ($exception->errorInfo[2] ?? $exception->getMessage());
        $driverCode = (int) ($exception->errorInfo[1] ?? 0);
        if ($driverCode === 1062) {
            throw new DomainException(
                'ADMIN_DUPLICATE_DATA',
                'El identificador, nombre de usuario o dato único ya está registrado.',
                409,
            );
        }
        if ($driverCode === 1452) {
            throw new DomainException(
                'ADMIN_REFERENCE_INVALID',
                'La referencia seleccionada ya no existe o no está disponible.',
                422,
            );
        }
        $errors = [
            'ADMIN_PRODUCT_TYPE_INVALID' => ['Tipo de producto inválido.', 422],
            'ADMIN_PRODUCT_VALUE_INVALID' => ['El precio y el tiempo de preparación deben ser válidos.', 422],
            'ADMIN_PRODUCT_CATEGORY_REQUIRED' => ['Selecciona una categoría para el plato.', 422],
            'ADMIN_PRODUCT_STATION_REQUIRED' => ['Asigna una estación de cocina a los productos que requieren preparación.', 422],
            'ADMIN_PRODUCT_STATION_INVALID' => ['La estación seleccionada no está activa.', 422],
            'ADMIN_VARIANT_REQUIRES_DISH' => ['Solo se pueden registrar variantes en platos.', 422],
            'ADMIN_VARIANT_NOT_FOUND' => ['La variante no pertenece a este plato o ya no existe.', 404],
            'ADMIN_CATEGORY_NOT_FOUND' => ['Categoría no encontrada.', 404],
            'ADMIN_CATEGORY_HAS_ACTIVE_PRODUCTS' => ['Desactiva primero los productos de esta categoría.', 409],
            'ADMIN_STATION_NOT_FOUND' => ['Estación de cocina no encontrada.', 404],
            'ADMIN_STATION_IN_USE' => ['La estación está asignada a productos o cocineros activos.', 409],
            'ADMIN_MODIFIER_NOT_FOUND' => ['Modificador no encontrado.', 404],
            'ADMIN_PRIORITY_COLOR_INVALID' => ['El color debe tener formato hexadecimal #RRGGBB.', 422],
            'ADMIN_PRODUCT_TYPE_IMMUTABLE' => ['El tipo de un producto existente no se puede cambiar.', 409],
            'ADMIN_PRODUCT_NOT_FOUND' => ['Producto no encontrado.', 404],
            'ADMIN_ROLE_INVALID' => ['El rol seleccionado no es válido.', 422],
            'ADMIN_STATION_REQUIRED' => ['Selecciona una estación para el cocinero.', 422],
            'ADMIN_SELF_DEACTIVATION_FORBIDDEN' => ['No puedes desactivar tu propio usuario.', 409],
            'ADMIN_USER_NOT_FOUND' => ['Usuario no encontrado.', 404],
            'ADMIN_ZONE_HAS_ACTIVE_TABLES' => ['Desactiva primero las mesas de la zona.', 409],
            'ADMIN_ZONE_NOT_FOUND' => ['Zona no encontrada.', 404],
            'ADMIN_TABLE_OCCUPIED' => ['No se puede desactivar una mesa ocupada.', 409],
            'ADMIN_TABLE_NOT_FOUND' => ['Mesa no encontrada.', 404],
            'ADMIN_PARAMETER_VALUE_INVALID' => ['El valor del parámetro no puede estar vacío.', 422],
            'ADMIN_PARAMETER_NOT_FOUND' => ['El parámetro ya no existe.', 404],
            'ADMIN_RECEIPT_LIMIT_INVALID' => ['El límite de comprobantes debe estar entre 1 y 50.', 422],
        ];

        foreach ($errors as $signal => [$description, $status]) {
            if (str_contains($message, $signal)) {
                throw new DomainException($signal, $description, $status);
            }
        }

        throw $exception;
    }
}
