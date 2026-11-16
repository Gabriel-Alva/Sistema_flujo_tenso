<?php

namespace App\Modules\Identity\Actions;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RefreshApiSessionAction
{
    /**
     * @return array{token: string, refresh_token: string, user: Usuario, role: string|null, station_id: int|null}
     */
    public function execute(string $refreshToken, Request $request): array
    {
        $result = DB::transaction(function () use ($refreshToken, $request): array {
            $stored = DB::table('REFRESH_TOKEN')
                ->where('token_hash', hash('sha256', $refreshToken))
                ->lockForUpdate()
                ->first();

            if (! $stored) {
                return ['error' => 'AUTH_REFRESH_INVALID'];
            }

            if ($stored->revocado) {
                DB::table('REFRESH_TOKEN')->where('family_id', $stored->family_id)->update(['revocado' => 1]);
                DB::table('personal_access_tokens')
                    ->where('tokenable_type', Usuario::class)
                    ->where('tokenable_id', $stored->id_usuario)
                    ->where('name', 'family:'.$stored->family_id)
                    ->delete();
                DB::table('AUDITORIA')->insert([
                    'tabla' => 'REFRESH_TOKEN',
                    'id_registro' => $stored->id_token,
                    'accion' => 'S',
                    'datos_despues' => json_encode(['evento' => 'REFRESH_REUSE_DETECTED', 'family_id' => $stored->family_id]),
                    'id_usuario' => $stored->id_usuario,
                    'fecha' => now(),
                ]);

                return ['error' => 'AUTH_REFRESH_REUSE'];
            }

            if (now()->greaterThanOrEqualTo($stored->expira_en)) {
                DB::table('REFRESH_TOKEN')->where('family_id', $stored->family_id)->update(['revocado' => 1]);

                return ['error' => 'AUTH_REFRESH_INVALID'];
            }

            $user = Usuario::query()->where('id_usuario', $stored->id_usuario)->first();
            if (! $user || ! $user->activo) {
                DB::table('REFRESH_TOKEN')->where('family_id', $stored->family_id)->update(['revocado' => 1]);

                return ['error' => 'AUTH_REFRESH_INVALID'];
            }

            DB::table('REFRESH_TOKEN')->where('id_token', $stored->id_token)->update(['revocado' => 1]);
            DB::table('personal_access_tokens')
                ->where('tokenable_type', Usuario::class)
                ->where('tokenable_id', $stored->id_usuario)
                ->where('name', 'family:'.$stored->family_id)
                ->delete();

            $newRefresh = Str::uuid().'.'.Str::random(48);
            DB::table('REFRESH_TOKEN')->insert([
                'id_token' => (string) Str::uuid(),
                'id_usuario' => $stored->id_usuario,
                'family_id' => $stored->family_id,
                'token_hash' => hash('sha256', $newRefresh),
                'dispositivo' => $stored->dispositivo,
                'ip' => $request->ip(),
                'expira_en' => now()->addDays(7),
                'revocado' => 0,
                'created_at' => now(),
            ]);

            return [
                'token' => $user->createToken('family:'.$stored->family_id, ['*'], now()->addMinutes(20))->plainTextToken,
                'refresh_token' => $newRefresh,
                'user' => $user->load('persona'),
                'role' => $user->rolActivo(),
                'station_id' => $user->idEstacion(),
            ];
        }, 3);

        if (isset($result['error'])) {
            throw new DomainException(
                $result['error'],
                $result['error'] === 'AUTH_REFRESH_REUSE' ? 'Se detectó la reutilización de una sesión.' : 'La sesión ya no es válida.',
                401
            );
        }

        return $result;
    }
}
