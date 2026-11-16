<?php

namespace App\Modules\Identity\Actions;

use App\Modules\Identity\Models\Usuario;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CreateApiSessionAction
{
    /**
     * @return array{token: string, refresh_token: string}
     */
    public function execute(Usuario $user, Request $request): array
    {
        return DB::transaction(function () use ($user, $request): array {
            $family = (string) Str::uuid();
            $refresh = Str::uuid().'.'.Str::random(48);

            DB::table('REFRESH_TOKEN')->insert([
                'id_token' => (string) Str::uuid(),
                'id_usuario' => $user->id_usuario,
                'family_id' => $family,
                'token_hash' => hash('sha256', $refresh),
                'dispositivo' => Str::limit((string) $request->userAgent(), 255, ''),
                'ip' => $request->ip(),
                'expira_en' => now()->addDays(7),
                'revocado' => 0,
                'created_at' => now(),
            ]);

            $token = $user->createToken('family:'.$family, ['*'], now()->addMinutes(20))->plainTextToken;

            return ['token' => $token, 'refresh_token' => $refresh];
        });
    }
}
