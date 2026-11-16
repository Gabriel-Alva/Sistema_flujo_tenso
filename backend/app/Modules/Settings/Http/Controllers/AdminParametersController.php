<?php

namespace App\Modules\Settings\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Identity\Models\Usuario;
use App\Modules\Settings\Actions\GetAdminParametersAction;
use App\Modules\Settings\Actions\UpdateAdminParameterAction;
use App\Modules\Settings\Http\Requests\UnlockAdminParametersRequest;
use App\Modules\Settings\Http\Requests\UpdateAdminParameterRequest;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\View\View;

class AdminParametersController extends Controller
{
    private const UNLOCK_MINUTES = 10;

    public function index(GetAdminParametersAction $action): View
    {
        if (! $this->isUnlocked()) {
            session()->forget('admin_parameters_unlocked_until');

            return view('pages.parameters.locked');
        }

        return view('pages.parameters.index', [
            'parameters' => $action->execute(),
            'unlockMinutes' => self::UNLOCK_MINUTES,
        ]);
    }

    public function unlock(UnlockAdminParametersRequest $request): RedirectResponse
    {
        $user = $request->user();
        if (! $user instanceof Usuario || ! Hash::check($request->validated('password'), $user->password_hash)) {
            return back()->withErrors([
                'password' => 'La contraseña del administrador no es correcta.',
            ]);
        }

        $request->session()->regenerate();
        $request->session()->put(
            'admin_parameters_unlocked_until',
            now()->addMinutes(self::UNLOCK_MINUTES)->timestamp,
        );

        return redirect()->route('admin.parameters')->with('status', 'Acceso confirmado por 10 minutos.');
    }

    public function lock(): RedirectResponse
    {
        session()->forget('admin_parameters_unlocked_until');

        return redirect()->route('admin.parameters')->with('status', 'Parámetros bloqueados.');
    }

    public function update(
        UpdateAdminParameterRequest $request,
        string $key,
        UpdateAdminParameterAction $action,
    ): RedirectResponse {
        if (! $this->isUnlocked()) {
            session()->forget('admin_parameters_unlocked_until');

            return redirect()->route('admin.parameters')
                ->withErrors(['password' => 'La autorización venció. Confirma tu contraseña para continuar.']);
        }

        $action->execute($key, $request->validated('valor'));
        $request->session()->put(
            'admin_parameters_unlocked_until',
            now()->addMinutes(self::UNLOCK_MINUTES)->timestamp,
        );

        return redirect()->route('admin.parameters')->with('status', 'Parámetro actualizado y auditado.');
    }

    private function isUnlocked(): bool
    {
        return (int) session()->get('admin_parameters_unlocked_until', 0) > now()->timestamp;
    }
}
