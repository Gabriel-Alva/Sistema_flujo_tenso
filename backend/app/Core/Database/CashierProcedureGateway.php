<?php

namespace App\Core\Database;

use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class CashierProcedureGateway
{
    private const READ_PROCEDURES = [
        'sp_cajero_resumen_dashboard' => 1,
        'sp_cajero_ventas_ultimos_7_dias' => 1,
        'sp_cajero_comandas_concluidas' => 0,
    ];

    /**
     * @param  array<int, mixed>  $bindings
     * @return array<int, object>
     */
    public function rows(string $name, array $bindings = []): array
    {
        if (! isset(self::READ_PROCEDURES[$name]) || self::READ_PROCEDURES[$name] !== count($bindings)) {
            throw new InvalidArgumentException('Procedimiento de caja no permitido o parámetros inválidos.');
        }

        $placeholders = implode(', ', array_fill(0, count($bindings), '?'));

        return DB::select("CALL {$name}({$placeholders})", $bindings);
    }
}
