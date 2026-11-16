<?php

namespace App\Modules\Identity\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class Usuario extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'USUARIO';

    protected $primaryKey = 'id_usuario';

    protected $fillable = [
        'id_persona', 'username', 'password_hash', 'activo',
        'intentos_fallidos', 'bloqueado_hasta', 'ultimo_login',
    ];

    protected $hidden = ['password_hash'];

    protected function casts(): array
    {
        return [
            'activo' => 'boolean',
            'bloqueado_hasta' => 'datetime',
            'ultimo_login' => 'datetime',
        ];
    }

    public function getAuthPassword(): string
    {
        return $this->password_hash;
    }

    public function persona(): BelongsTo
    {
        return $this->belongsTo(Persona::class, 'id_persona', 'id_persona');
    }

    public function rolActivo(): ?string
    {
        $id = $this->id_persona;
        if (\Illuminate\Support\Facades\DB::table('ADMINISTRADOR')->where('id_persona', $id)->exists()) {
            return 'ADMINISTRADOR';
        }
        if (\Illuminate\Support\Facades\DB::table('CAJERO')->where('id_persona', $id)->exists()) {
            return 'CAJERO';
        }
        if (\Illuminate\Support\Facades\DB::table('MESERO')->where('id_persona', $id)->exists()) {
            return 'MESERO';
        }
        if (\Illuminate\Support\Facades\DB::table('COCINERO')->where('id_persona', $id)->exists()) {
            return 'COCINERO';
        }

        return null;
    }

    public function idEstacion(): ?int
    {
        $row = \Illuminate\Support\Facades\DB::table('COCINERO')->where('id_persona', $this->id_persona)->first();

        return $row->id_estacion ?? null;
    }
}
