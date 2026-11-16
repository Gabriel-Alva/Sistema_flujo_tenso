<?php

namespace App\Modules\Billing\Actions;

use App\Core\Database\CashierProcedureGateway;
use Illuminate\Support\Carbon;

class GetCashierDashboardAction
{
    public function __construct(private readonly CashierProcedureGateway $procedures) {}

    /** @return array<string, mixed> */
    public function execute(int $userId): array
    {
        $summary = (array) ($this->procedures->rows('sp_cajero_resumen_dashboard', [$userId])[0] ?? []);
        $trend = $this->procedures->rows('sp_cajero_ventas_ultimos_7_dias', [$userId]);

        return [
            'resumen' => [
                'pedidos_cobrados_hoy' => (int) ($summary['pedidos_cobrados_hoy'] ?? 0),
                'ventas_hoy' => (float) ($summary['ventas_hoy'] ?? 0),
                'ticket_promedio' => (float) ($summary['ticket_promedio'] ?? 0),
                'pedidos_pendientes_cobro' => (int) ($summary['pedidos_pendientes_cobro'] ?? 0),
                'comandas_concluidas' => (int) ($summary['comandas_concluidas'] ?? 0),
                'efectivo_hoy' => (float) ($summary['efectivo_hoy'] ?? 0),
                'tarjeta_hoy' => (float) ($summary['tarjeta_hoy'] ?? 0),
                'yape_hoy' => (float) ($summary['yape_hoy'] ?? 0),
                'plin_hoy' => (float) ($summary['plin_hoy'] ?? 0),
                'transferencia_hoy' => (float) ($summary['transferencia_hoy'] ?? 0),
            ],
            'ventas_7_dias' => array_map(static fn (object $row): array => [
                'fecha' => Carbon::parse((string) $row->fecha)->toDateString(),
                'etiqueta' => Carbon::parse((string) $row->fecha)->format('d/m'),
                'ventas' => (float) $row->ventas,
                'pedidos' => (int) $row->pedidos,
            ], $trend),
            'comandas_concluidas' => array_map(
                static fn (object $row): array => (array) $row,
                $this->procedures->rows('sp_cajero_comandas_concluidas')
            ),
        ];
    }
}
