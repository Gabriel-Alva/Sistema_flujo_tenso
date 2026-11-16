<?php

namespace App\Modules\Catalog\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Plato extends Model
{
    protected $table = 'PLATO';

    protected $primaryKey = 'id_producto';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    public function categoria(): BelongsTo
    {
        return $this->belongsTo(CategoriaPlato::class, 'id_categoria', 'id_categoria');
    }

    public function variantes(): HasMany
    {
        return $this->hasMany(PlatoVariante::class, 'id_plato', 'id_producto');
    }
}
