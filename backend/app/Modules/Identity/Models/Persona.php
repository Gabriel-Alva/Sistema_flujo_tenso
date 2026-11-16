<?php

namespace App\Modules\Identity\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Persona extends Model
{
    protected $table = 'PERSONA';

    protected $primaryKey = 'id_persona';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id_persona', 'nombres', 'primer_apellido', 'segundo_apellido',
        'tipo_documento', 'numero_documento', 'telefono', 'email',
    ];

    public function usuario(): HasOne
    {
        return $this->hasOne(Usuario::class, 'id_persona', 'id_persona');
    }
}
