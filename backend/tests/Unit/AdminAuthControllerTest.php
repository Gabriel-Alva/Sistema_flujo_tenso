<?php

namespace Tests\Unit;

use App\Modules\Identity\Actions\LoginAction;
use App\Modules\Identity\Http\Controllers\AdminAuthController;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AdminAuthControllerTest extends TestCase
{
    #[DataProvider('rememberOptions')]
    public function test_login_uses_the_requested_remember_option(
        array $credentials,
        bool $shouldRemember,
    ): void {
        $user = \Mockery::mock(Usuario::class);
        $action = \Mockery::mock(LoginAction::class);
        $action->shouldReceive('execute')
            ->once()
            ->with('admin', 'secret', 'ADMINISTRADOR')
            ->andReturn(['user' => $user]);
        Auth::shouldReceive('login')->once()->with($user, $shouldRemember);

        $request = Request::create('/login', 'POST', [
            'username' => 'admin',
            'password' => 'secret',
            ...$credentials,
        ]);
        $request->setLaravelSession($this->app['session']->driver());

        $response = (new AdminAuthController)->login($request, $action);

        $this->assertSame(route('admin.dashboard'), $response->getTargetUrl());
    }

    /** @return array<string, array{array<string, string>, bool}> */
    public static function rememberOptions(): array
    {
        return [
            'remember enabled' => [['remember' => '1'], true],
            'remember disabled by default' => [[], false],
        ];
    }
}
