<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;

class Modificador extends Model
{
    protected $table = 'MODIFICADOR';

    protected $primaryKey = 'id_modificador';

    public $timestamps = false;
}
