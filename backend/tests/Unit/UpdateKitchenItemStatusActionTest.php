<?php

namespace Tests\Unit;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use App\Modules\Kitchen\Actions\UpdateKitchenItemStatusAction;
use Illuminate\Support\Facades\DB;
use Mockery;
use Tests\TestCase;

class UpdateKitchenItemStatusActionTest extends TestCase
{
    public function test_cook_cancellation_is_limited_to_the_assigned_station(): void
    {
        $user = Mockery::mock(Usuario::class)->makePartial();
        $user->id_usuario = 17;
        $user->shouldReceive('rolActivo')->once()->andReturn('COCINERO');
        $user->shouldReceive('idEstacion')->once()->andReturn(5);

        DB::shouldReceive('select')
            ->once()
            ->with('CALL sp_kitchen_update_item_status(?, ?, ?, ?, ?)', [8, 'CANCELADO', 17, 5, 'Falta de insumo'])
            ->andReturn([]);

        $result = (new UpdateKitchenItemStatusAction)->execute(
            8,
            'CANCELADO',
            '  Falta de insumo  ',
            $user,
        );

        $this->assertSame(['id_detalle' => 8, 'estado_item' => 'CANCELADO'], $result);
    }

    public function test_cook_without_an_assigned_station_is_rejected(): void
    {
        $user = Mockery::mock(Usuario::class)->makePartial();
        $user->shouldReceive('rolActivo')->once()->andReturn('COCINERO');
        $user->shouldReceive('idEstacion')->once()->andReturn(null);

        DB::shouldReceive('select')->never();
        $this->expectException(DomainException::class);

        (new UpdateKitchenItemStatusAction)->execute(8, 'CANCELADO', 'Sin motivo válido', $user);
    }
}
