<?php

namespace Tests\Unit;

use App\Core\Database\AdminProcedureGateway;
use App\Modules\Reporting\Actions\GetAdminDashboardAction;
use Illuminate\Support\ViewErrorBag;
use Tests\TestCase;

class GetAdminDashboardActionTest extends TestCase
{
    public function test_dashboard_builds_scaled_sales_and_order_charts(): void
    {
        $sales = [
            (object) ['tipo' => 'VENTAS', 'etiqueta' => '2026-11-14', 'valor' => '50.00'],
            (object) ['tipo' => 'VENTAS', 'etiqueta' => '2026-11-15', 'valor' => '100.00'],
        ];
        $orders = [
            (object) ['tipo' => 'PEDIDOS', 'etiqueta' => 'ABIERTO', 'valor' => '4'],
            (object) ['tipo' => 'PEDIDOS', 'etiqueta' => 'EN_PAGO', 'valor' => '2'],
        ];
        $procedures = \Mockery::mock(AdminProcedureGateway::class);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_dashboard')->andReturn([(object) ['pedidos_hoy' => 6]]);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_dashboard_graficos')->andReturn([...$sales, ...$orders]);

        $data = (new GetAdminDashboardAction($procedures))->execute();

        $this->assertSame(6, $data['pedidos_hoy']);
        $this->assertSame(150.0, $data['salesChartTotal']);
        $this->assertSame(60.0, $data['salesChart'][0]['height']);
        $this->assertSame(120.0, $data['salesChart'][1]['height']);
        $this->assertSame(300.0, $data['orderStatusChart'][0]['width']);
        $this->assertSame(150.0, $data['orderStatusChart'][1]['width']);
        $this->assertCount(4, $data['orderStatusChart']);
    }

    public function test_charts_stay_at_zero_when_database_has_no_activity(): void
    {
        $procedures = \Mockery::mock(AdminProcedureGateway::class);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_dashboard')->andReturn([]);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_dashboard_graficos')->andReturn([]);

        $data = (new GetAdminDashboardAction($procedures))->execute();

        $this->assertSame([], $data['salesChart']);
        $this->assertSame(0, $data['salesChartTotal']);
        $this->assertSame([0, 0, 0, 0], array_column($data['orderStatusChart'], 'width'));
    }

    public function test_dashboard_view_renders_both_charts(): void
    {
        view()->share('errors', new ViewErrorBag);
        $html = view('pages.home.dashboard', [
            'mesas_ocupadas' => 1,
            'items_cocina' => 2,
            'cajas_abiertas' => 1,
            'pedidos_abiertos' => 3,
            'pedidos_hoy' => 4,
            'venta_hoy' => 50,
            'salesChart' => [['label' => '15/11', 'value' => 50.0, 'height' => 120.0]],
            'salesChartTotal' => 50.0,
            'orderStatusChart' => [
                ['state' => 'ABIERTO', 'label' => 'Abiertos', 'value' => 1, 'width' => 300.0],
                ['state' => 'EN_PAGO', 'label' => 'En pago', 'value' => 0, 'width' => 0.0],
                ['state' => 'PAGADO', 'label' => 'Pagados', 'value' => 2, 'width' => 200.0],
                ['state' => 'ANULADO', 'label' => 'Anulados', 'value' => 1, 'width' => 100.0],
            ],
        ])->render();

        $this->assertSame(2, substr_count($html, '<svg class="dashboard-chart'));
        $this->assertStringContainsString('Ventas emitidas', $html);
        $this->assertStringContainsString('Estado de pedidos', $html);
    }
}
