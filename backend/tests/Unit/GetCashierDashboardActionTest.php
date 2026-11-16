<?php

namespace Tests\Unit;

use App\Core\Database\CashierProcedureGateway;
use App\Modules\Billing\Actions\GetCashierDashboardAction;
use Tests\TestCase;

class GetCashierDashboardActionTest extends TestCase
{
    public function test_dashboard_normalizes_summary_chart_and_completed_orders(): void
    {
        $procedures = \Mockery::mock(CashierProcedureGateway::class);
        $procedures->shouldReceive('rows')
            ->once()
            ->with('sp_cajero_resumen_dashboard', [7])
            ->andReturn([(object) [
                'pedidos_cobrados_hoy' => '3',
                'ventas_hoy' => '125.50',
                'ticket_promedio' => '41.83',
                'pedidos_pendientes_cobro' => '5',
                'comandas_concluidas' => '2',
                'efectivo_hoy' => '50.00',
                'tarjeta_hoy' => '75.50',
                'yape_hoy' => '0.00',
                'plin_hoy' => '0.00',
                'transferencia_hoy' => '0.00',
            ]]);
        $procedures->shouldReceive('rows')
            ->once()
            ->with('sp_cajero_ventas_ultimos_7_dias', [7])
            ->andReturn([(object) ['fecha' => '2026-11-15', 'ventas' => '125.50', 'pedidos' => '3']]);
        $procedures->shouldReceive('rows')
            ->once()
            ->with('sp_cajero_comandas_concluidas')
            ->andReturn([(object) [
                'id_pedido' => 12,
                'tipo' => 'SALON',
                'saldo_pendiente' => '25.00',
                'items_concluidos' => 4,
            ]]);

        $data = (new GetCashierDashboardAction($procedures))->execute(7);

        $this->assertSame(3, $data['resumen']['pedidos_cobrados_hoy']);
        $this->assertSame(125.5, $data['resumen']['ventas_hoy']);
        $this->assertSame('15/11', $data['ventas_7_dias'][0]['etiqueta']);
        $this->assertSame(3, $data['ventas_7_dias'][0]['pedidos']);
        $this->assertSame(12, $data['comandas_concluidas'][0]['id_pedido']);
    }

    public function test_cashier_gateway_rejects_procedures_outside_its_read_allowlist(): void
    {
        $this->expectException(\InvalidArgumentException::class);

        (new CashierProcedureGateway)->rows('sp_admin_dashboard');
    }
}
