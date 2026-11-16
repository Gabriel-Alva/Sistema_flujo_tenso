<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;

class PlatoVariante extends Model
{
    protected $table = 'PLATO_VARIANTE';

    protected $primaryKey = 'id_variante';

    public $timestamps = false;
}
