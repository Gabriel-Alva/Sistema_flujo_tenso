<?php

namespace App\Modules\Identity\Http\Controllers;

use App\Core\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Modules\Identity\Actions\LoginAction;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class AdminAuthController extends Controller
{
    public function showLogin(): View
    {
        return view('auth.login');
    }

    public function login(Request $request, LoginAction $action): RedirectResponse
    {
        $data = $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
            'remember' => 'sometimes|boolean',
        ]);

        try {
            $result = $action->execute($data['username'], $data['password'], 'ADMINISTRADOR');
        } catch (DomainException $e) {
            return back()->withErrors(['username' => $e->getMessage()])->onlyInput('username');
        }

        Auth::login($result['user'], $request->boolean('remember'));
        $request->session()->regenerate();

        return redirect()->route('admin.dashboard');
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
