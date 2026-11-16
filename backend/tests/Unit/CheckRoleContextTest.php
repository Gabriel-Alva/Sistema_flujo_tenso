<?php

namespace Tests\Unit;

use App\Core\Exceptions\DomainException;
use App\Core\Http\Middleware\CheckRoleContext;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Http\Request;
use Tests\TestCase;

class CheckRoleContextTest extends TestCase
{
    public function test_a_user_with_a_secondary_allowed_role_can_pass_the_middleware(): void
    {
        $user = \Mockery::mock(Usuario::class)->makePartial();
        $user->activo = true;
        $user->shouldReceive('rolActivo')->once()->andReturn('CAJERO');

        $request = Request::create('/');
        $request->setUserResolver(fn () => $user);
        $response = (new CheckRoleContext)->handle(
            $request,
            fn () => response('ok'),
            'MESERO',
            'CAJERO',
        );

        $this->assertSame(200, $response->getStatusCode());
    }

    public function test_inactive_user_cannot_pass_even_with_an_allowed_role(): void
    {
        $user = \Mockery::mock(Usuario::class)->makePartial();
        $user->activo = false;
        $request = Request::create('/');
        $request->setUserResolver(fn () => $user);

        $this->expectException(DomainException::class);
        (new CheckRoleContext)->handle(
            $request,
            fn () => response('ok'),
            'ADMINISTRADOR',
        );
    }
}
