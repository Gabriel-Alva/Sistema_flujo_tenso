<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Producto extends Model
{
    protected $table = 'PRODUCTO';

    protected $primaryKey = 'id_producto';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    public function plato(): HasOne
    {
        return $this->hasOne(Plato::class, 'id_producto', 'id_producto');
    }

    public function bebida(): HasOne
    {
        return $this->hasOne(Bebida::class, 'id_producto', 'id_producto');
    }
}
