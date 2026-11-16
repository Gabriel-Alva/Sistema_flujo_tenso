<?php

namespace App\Modules\Identity\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UsuarioResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id_usuario' => $this->id_usuario,
            'username' => $this->username,
            'rol' => $this->rolActivo(),
            'id_estacion' => $this->idEstacion(),
            'persona' => [
                'id_persona' => $this->persona?->id_persona,
                'nombres' => $this->persona?->nombres,
                'primer_apellido' => $this->persona?->primer_apellido,
            ],
        ];
    }
}
