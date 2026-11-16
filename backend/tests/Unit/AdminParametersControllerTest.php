<?php

namespace Tests\Unit;

use App\Modules\Identity\Models\Usuario;
use App\Modules\Settings\Actions\GetAdminParametersAction;
use App\Modules\Settings\Http\Controllers\AdminParametersController;
use App\Modules\Settings\Http\Requests\UnlockAdminParametersRequest;
use Illuminate\Session\Store;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

class AdminParametersControllerTest extends TestCase
{
    public function test_parameter_values_are_not_loaded_before_password_confirmation(): void
    {
        $session = $this->app['session']->driver();
        $session->forget('admin_parameters_unlocked_until');
        $action = \Mockery::mock(GetAdminParametersAction::class);
        $action->shouldNotReceive('execute');

        $view = (new AdminParametersController)->index($action);

        $this->assertSame('pages.parameters.locked', $view->name());
    }

    public function test_current_admin_password_unlocks_parameters_temporarily(): void
    {
        $user = new Usuario;
        $user->password_hash = Hash::make('current-admin-password');
        $session = $this->app['session']->driver();
        $session->start();

        $request = $this->unlockRequest('current-admin-password', $user, $session);
        $response = (new AdminParametersController)->unlock($request);

        $this->assertSame(route('admin.parameters'), $response->getTargetUrl());
        $this->assertGreaterThan(now()->timestamp, $session->get('admin_parameters_unlocked_until'));
    }

    public function test_incorrect_password_does_not_unlock_parameters(): void
    {
        $user = new Usuario;
        $user->password_hash = Hash::make('current-admin-password');
        $session = $this->app['session']->driver();
        $session->start();

        $request = $this->unlockRequest('incorrect-password', $user, $session);
        (new AdminParametersController)->unlock($request);

        $this->assertNull($session->get('admin_parameters_unlocked_until'));
    }

    private function unlockRequest(string $password, Usuario $user, Store $session): UnlockAdminParametersRequest
    {
        $request = UnlockAdminParametersRequest::create('/admin/parametros/acceso', 'POST', [
            'password' => $password,
        ]);
        $request->setContainer($this->app);
        $request->setRedirector($this->app['redirect']);
        $request->setUserResolver(fn () => $user);
        $request->setLaravelSession($session);
        $request->setValidator(Validator::make($request->all(), $request->rules()));

        return $request;
    }
}
