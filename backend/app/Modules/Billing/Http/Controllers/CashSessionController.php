<?php

namespace App\Modules\Billing\Http\Controllers;

use App\Core\Exceptions\DomainException;
use App\Core\Traits\CallsStoredProcedures;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CashSessionController extends Controller
{
    use CallsStoredProcedures;

    public function actual(Request $request): JsonResponse
    {
        $sesion = DB::table('CAJA_SESION')
            ->where('id_usuario', $request->user()->id_usuario)
            ->where('estado', 'ABIERTA')
            ->first();

        if (! $sesion) {
            return response()->json(['sesion' => null, 'arqueo' => null]);
        }

        $arqueo = DB::table('vw_arqueo_sesion_caja')->where('id_caja_sesion', $sesion->id_caja_sesion)->first();

        return response()->json(['sesion' => $sesion, 'arqueo' => $arqueo]);
    }

    public function abrir(Request $request): JsonResponse
    {
        $data = $request->validate([
            'monto_apertura' => 'required|numeric|min:0|max:9999999999.99',
            'observaciones' => 'nullable|string|max:2000',
        ]);

        $id = DB::transaction(function () use ($request, $data): int {
            DB::table('USUARIO')
                ->where('id_usuario', $request->user()->id_usuario)
                ->lockForUpdate()
                ->first();

            $abierta = DB::table('CAJA_SESION')
                ->where('id_usuario', $request->user()->id_usuario)
                ->where('estado', 'ABIERTA')
                ->exists();
            if ($abierta) {
                throw new DomainException('CASH_SESSION_OPEN', 'Ya existe una sesión de caja abierta.', 409);
            }

            return (int) DB::table('CAJA_SESION')->insertGetId([
                'id_usuario' => $request->user()->id_usuario,
                'estado' => 'ABIERTA',
                'monto_apertura' => $data['monto_apertura'],
                'observaciones' => $data['observaciones'] ?? null,
                'apertura_en' => now(),
            ]);
        });

        return response()->json(['id_caja_sesion' => $id], 201);
    }

    public function movimiento(Request $request): JsonResponse
    {
        $data = $request->validate([
            'tipo' => 'required|in:INGRESO,EGRESO',
            'monto' => 'required|numeric|min:0.01|max:9999999999.99',
            'motivo' => 'required|string|max:180',
        ]);
        $id = DB::transaction(function () use ($request, $data): int {
            $sesion = DB::table('CAJA_SESION')
                ->where('id_usuario', $request->user()->id_usuario)
                ->where('estado', 'ABIERTA')
                ->lockForUpdate()
                ->first();
            if (! $sesion) {
                throw new DomainException('CASH_SESSION_INVALID', 'No hay caja abierta.', 409);
            }

            return (int) DB::table('MOVIMIENTO_CAJA')->insertGetId([
                'id_caja_sesion' => $sesion->id_caja_sesion,
                'id_usuario' => $request->user()->id_usuario,
                'tipo' => $data['tipo'],
                'monto' => $data['monto'],
                'motivo' => $data['motivo'],
                'created_at' => now(),
            ]);
        });

        return response()->json(['id_movimiento' => $id], 201);
    }

    public function cerrar(Request $request, int $id): JsonResponse
    {
        $data = $request->validate([
            'monto_declarado' => 'required|numeric|min:0',
            'observaciones' => 'nullable|string',
        ]);

        $out = $this->callProcedure(
            'sp_cerrar_sesion_caja',
            [$id, $request->user()->id_usuario, $data['monto_declarado'], $data['observaciones'] ?? null],
            ['@p_diferencia']
        );

        return response()->json(['diferencia' => $out['p_diferencia']]);
    }
}
