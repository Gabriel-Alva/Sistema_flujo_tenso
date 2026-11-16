<?php

namespace App\Modules\Identity\Http\Controllers;

use App\Core\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Modules\Identity\Actions\CreateApiSessionAction;
use App\Modules\Identity\Actions\LoginAction;
use App\Modules\Identity\Actions\RefreshApiSessionAction;
use App\Modules\Identity\Http\Requests\LoginRequest;
use App\Modules\Identity\Http\Resources\UsuarioResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    public function login(
        LoginRequest $request,
        LoginAction $action,
        CreateApiSessionAction $sessionAction
    ): JsonResponse {
        $result = $action->execute(
            $request->string('username')->toString(),
            $request->string('password')->toString(),
            $request->string('context')->toString(),
        );
        $session = $sessionAction->execute($result['user'], $request);

        $payload = [
            'access_token' => $session['token'],
            'token_type' => 'Bearer',
            'expires_in' => 1200,
            'role' => $result['role'],
            'station_id' => $result['station_id'],
            'user' => (new UsuarioResource($result['user']))->resolve(),
        ];
        if ($request->header('X-Client-Type') === 'mobile') {
            $payload['refresh_token'] = $session['refresh_token'];
        }
        $response = response()->json($payload);

        $secure = app()->environment('production') || $request->secure();
        $cookieName = $secure ? '__Host-sipan_refresh' : 'sipan_refresh';
        $response->cookie(
            cookie($cookieName, $session['refresh_token'], 60 * 24 * 7, '/', null, $secure, true, false, 'strict')
        );

        return $response;
    }

    public function refresh(Request $request, RefreshApiSessionAction $action): JsonResponse
    {
        $request->validate(['refresh_token' => ['nullable', 'string', 'max:120']]);
        $refreshToken = $request->input('refresh_token')
            ?? $request->cookie('__Host-sipan_refresh')
            ?? $request->cookie('sipan_refresh');
        if (! is_string($refreshToken) || $refreshToken === '') {
            throw new DomainException('AUTH_REFRESH_INVALID', 'La sesión ya no es válida.', 401);
        }

        $session = $action->execute($refreshToken, $request);
        $payload = [
            'access_token' => $session['token'],
            'token_type' => 'Bearer',
            'expires_in' => 1200,
            'role' => $session['role'],
            'station_id' => $session['station_id'],
            'user' => (new UsuarioResource($session['user']))->resolve(),
        ];
        if ($request->header('X-Client-Type') === 'mobile') {
            $payload['refresh_token'] = $session['refresh_token'];
        }
        $response = response()->json($payload);
        $secure = app()->environment('production') || $request->secure();
        $cookieName = $secure ? '__Host-sipan_refresh' : 'sipan_refresh';

        return $response->cookie(
            cookie($cookieName, $session['refresh_token'], 60 * 24 * 7, '/', null, $secure, true, false, 'strict')
        );
    }

    public function me(Request $request): UsuarioResource
    {
        return new UsuarioResource($request->user()->load('persona'));
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        $accessToken = $user?->currentAccessToken();
        $tokenName = $accessToken?->name;
        $family = is_string($tokenName) && str_starts_with($tokenName, 'family:')
            ? substr($tokenName, strlen('family:'))
            : null;

        DB::transaction(function () use ($accessToken, $family): void {
            $accessToken?->delete();
            if ($family !== null) {
                DB::table('REFRESH_TOKEN')->where('family_id', $family)->update(['revocado' => 1]);
            }
        });

        $secure = app()->environment('production') || $request->secure();
        $cookieName = $secure ? '__Host-sipan_refresh' : 'sipan_refresh';

        return response()
            ->json(['code' => 'LOGGED_OUT', 'message' => 'Sesión cerrada.'])
            ->withCookie(cookie($cookieName, '', -1, '/', null, $secure, true, false, 'strict'));
    }
}
