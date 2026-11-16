<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;

class CategoriaPlato extends Model
{
    protected $table = 'CATEGORIA_PLATO';

    protected $primaryKey = 'id_categoria';

    public $timestamps = false;
}
