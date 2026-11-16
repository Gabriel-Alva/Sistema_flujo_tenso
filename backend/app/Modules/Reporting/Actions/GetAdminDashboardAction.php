<?php

namespace App\Modules\Reporting\Actions;

use App\Core\Database\AdminProcedureGateway;
use Illuminate\Support\Carbon;

class GetAdminDashboardAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /**
     * @return array<string, mixed>
     */
    public function execute(): array
    {
        $summary = (array) ($this->procedures->rows('sp_admin_dashboard')[0] ?? []);
        $sales = [];
        $orders = [];

        foreach ($this->procedures->rows('sp_admin_dashboard_graficos') as $row) {
            if ($row->tipo === 'VENTAS') {
                $sales[] = [
                    'label' => Carbon::parse($row->etiqueta)->format('d/m'),
                    'value' => (float) $row->valor,
                ];

                continue;
            }

            if ($row->tipo === 'PEDIDOS') {
                $orders[$row->etiqueta] = (int) $row->valor;
            }
        }

        $maxSales = max([0, ...array_column($sales, 'value')]);
        foreach ($sales as &$point) {
            $point['height'] = $maxSales > 0 ? round($point['value'] / $maxSales * 120, 1) : 0;
        }
        unset($point);

        $orderLabels = [
            'ABIERTO' => 'Abiertos',
            'EN_PAGO' => 'En pago',
            'PAGADO' => 'Pagados',
            'ANULADO' => 'Anulados',
        ];
        $maxOrders = max([0, ...array_values($orders)]);
        $orderChart = [];
        foreach ($orderLabels as $state => $label) {
            $value = $orders[$state] ?? 0;
            $orderChart[] = [
                'state' => $state,
                'label' => $label,
                'value' => $value,
                'width' => $maxOrders > 0 ? round($value / $maxOrders * 300, 1) : 0,
            ];
        }

        return [
            ...$summary,
            'salesChart' => $sales,
            'salesChartTotal' => array_sum(array_column($sales, 'value')),
            'orderStatusChart' => $orderChart,
        ];
    }
}
