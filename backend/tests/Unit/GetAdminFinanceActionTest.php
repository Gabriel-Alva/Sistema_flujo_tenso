<?php

namespace Tests\Unit;

use App\Core\Database\AdminProcedureGateway;
use App\Modules\Billing\Actions\GetAdminFinanceAction;
use Tests\TestCase;

class GetAdminFinanceActionTest extends TestCase
{
    public function test_receipt_items_are_decoded_for_the_preview(): void
    {
        $receipt = (object) [
            'items' => '[{"nombre":"Arroz chaufa","cantidad":2,"total":30.00,"modificadores":"Sin cebolla"}]',
        ];
        $procedures = \Mockery::mock(AdminProcedureGateway::class);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_listar_comprobantes', [20])->andReturn([$receipt]);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_resumen_financiero', ['2026-11-01', '2026-11-15'])->andReturn([]);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_sesiones_caja', ['2026-11-01', '2026-11-15'])->andReturn([]);
        $procedures->shouldReceive('rows')->once()->with('sp_admin_saldos_pendientes')->andReturn([]);

        $data = (new GetAdminFinanceAction($procedures))->execute('2026-11-01', '2026-11-15');

        $this->assertSame('Arroz chaufa', $data['receipts'][0]->items[0]['nombre']);
        $this->assertSame(2, $data['receipts'][0]->items[0]['cantidad']);
    }
}
