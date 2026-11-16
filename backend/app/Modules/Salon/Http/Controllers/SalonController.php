<?php

namespace App\Modules\Salon\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class SalonController extends Controller
{
    public function zonas(): JsonResponse
    {
        return response()->json(DB::table('ZONA')->where('activa', 1)->orderBy('nombre')->get());
    }

    public function mesas(): JsonResponse
    {
        return response()->json(DB::table('vw_estado_salon_tiempo_real')->orderBy('zona')->orderBy('numero')->get());
    }
}
