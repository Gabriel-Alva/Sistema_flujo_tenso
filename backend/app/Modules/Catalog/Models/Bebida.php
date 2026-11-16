<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;

class Bebida extends Model
{
    protected $table = 'BEBIDAS';

    protected $primaryKey = 'id_producto';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;
}
