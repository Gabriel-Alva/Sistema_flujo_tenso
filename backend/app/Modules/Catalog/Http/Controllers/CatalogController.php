<?php

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Modules\Catalog\Models\CategoriaPlato;
use App\Modules\Catalog\Models\Modificador;
use App\Modules\Catalog\Models\Producto;
use Illuminate\Http\JsonResponse;

class CatalogController extends Controller
{
    public function categorias(): JsonResponse
    {
        return response()->json(CategoriaPlato::query()->where('activa', 1)->orderBy('nombre')->get());
    }

    public function productos(): JsonResponse
    {
        $productos = Producto::query()
            ->with(['plato.categoria', 'plato.variantes', 'bebida'])
            ->where('activo', 1)
            ->orderBy('nombre')
            ->get()
            ->map(fn (Producto $p) => [
                'id_producto' => $p->id_producto,
                'nombre' => $p->nombre,
                'descripcion' => $p->descripcion,
                'precio_actual' => (float) $p->precio_actual,
                'tiempo_prep_min' => $p->tiempo_prep_min,
                'imagen_url' => $p->imagen_url,
                'requiere_preparacion' => (bool) $p->requiere_preparacion,
                'tipo' => $p->plato ? 'PLATO' : ($p->bebida ? 'BEBIDA' : 'OTRO'),
                'categoria' => $p->plato?->categoria?->nombre,
                'variantes' => $p->plato?->variantes
                    ?->where('activo', 1)
                    ->values() ?? [],
                'bebida' => $p->bebida,
            ]);

        return response()->json($productos);
    }

    public function modificadores(): JsonResponse
    {
        return response()->json(Modificador::query()->where('activo', 1)->orderBy('nombre')->get());
    }
}
