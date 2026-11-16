<?php

namespace Tests\Unit;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use App\Modules\Kitchen\Actions\CancelKitchenCommandAction;
use Illuminate\Support\Facades\DB;
use Mockery;
use Tests\TestCase;

class CancelKitchenCommandActionTest extends TestCase
{
    public function test_cancellation_uses_the_cooks_assigned_station(): void
    {
        $user = Mockery::mock(Usuario::class)->makePartial();
        $user->id_usuario = 17;
        $user->shouldReceive('rolActivo')->once()->andReturn('COCINERO');
        $user->shouldReceive('idEstacion')->once()->andReturn(5);

        DB::shouldReceive('select')
            ->once()
            ->with('CALL sp_kitchen_cancel_command(?, ?, ?, ?)', [23, 17, 5, 'Falta de insumo'])
            ->andReturn([]);

        $result = (new CancelKitchenCommandAction)->execute(
            23,
            '  Falta de insumo  ',
            $user,
        );

        $this->assertSame(['id_comanda' => 23, 'estado_item' => 'CANCELADO'], $result);
    }

    public function test_cook_without_an_assigned_station_is_rejected(): void
    {
        $user = Mockery::mock(Usuario::class)->makePartial();
        $user->shouldReceive('rolActivo')->once()->andReturn('COCINERO');
        $user->shouldReceive('idEstacion')->once()->andReturn(null);

        DB::shouldReceive('select')->never();
        $this->expectException(DomainException::class);

        (new CancelKitchenCommandAction)->execute(23, 'Falta de insumo', $user);
    }
}
