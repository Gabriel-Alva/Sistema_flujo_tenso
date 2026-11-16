<?php

namespace App\Modules\Kitchen\Http\Controllers;

use App\Core\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Modules\Identity\Models\Usuario;
use App\Modules\Kitchen\Actions\CancelKitchenCommandAction;
use App\Modules\Kitchen\Actions\UpdateKitchenItemStatusAction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class KitchenController extends Controller
{
    public function cola(Request $request): JsonResponse
    {
        $request->validate(['id_estacion' => ['nullable', 'integer', 'min:1']]);
        $q = DB::table('vw_cola_cocina_activa');
        $user = $request->user();
        $role = $user->rolActivo();
        $estacionUsuario = $role === 'COCINERO' ? $user->idEstacion() : null;
        $estacionSolicitada = $request->integer('id_estacion');

        if ($role === 'COCINERO') {
            if (! $estacionUsuario || ($estacionSolicitada && $estacionSolicitada !== $estacionUsuario)) {
                throw new DomainException('FORBIDDEN_STATION', 'No puede consultar otra estación.', 403);
            }
            $q->where('id_estacion_cocina', $estacionUsuario);
        } elseif ($estacionSolicitada) {
            $q->where('id_estacion_cocina', $estacionSolicitada);
        }

        return response()->json(
            $q->orderByRaw(
                "CASE UPPER(prioridad)
                    WHEN 'URGENTE' THEN 1
                    WHEN 'ALTA' THEN 2
                    WHEN 'NORMAL' THEN 3
                    WHEN 'MEDIA' THEN 3
                    WHEN 'BAJA' THEN 4
                    ELSE 5
                END",
            )->orderBy('fecha_envio')->get(),
        );
    }

    public function cambiarEstado(
        Request $request,
        int $id,
        UpdateKitchenItemStatusAction $updateKitchenItemStatus,
    ): JsonResponse {
        $data = $request->validate([
            'estado_item' => 'required|in:EN_PREPARACION,LISTO,CANCELADO',
            'motivo_cancelacion' => 'required_if:estado_item,CANCELADO|nullable|string|min:3|max:250',
        ]);

        $user = $request->user();
        if (! $user instanceof Usuario) {
            throw new DomainException('UNAUTHENTICATED', 'La sesión ya no es válida.', 401);
        }

        return response()->json($updateKitchenItemStatus->execute(
            $id,
            $data['estado_item'],
            $data['motivo_cancelacion'] ?? null,
            $user,
        ));
    }

    public function cancelarComanda(
        Request $request,
        int $id,
        CancelKitchenCommandAction $cancelKitchenCommand,
    ): JsonResponse {
        $data = $request->validate([
            'motivo_cancelacion' => 'required|string|min:3|max:250',
        ]);

        $user = $request->user();
        if (! $user instanceof Usuario) {
            throw new DomainException('UNAUTHENTICATED', 'La sesión ya no es válida.', 401);
        }

        return response()->json($cancelKitchenCommand->execute(
            $id,
            $data['motivo_cancelacion'],
            $user,
        ));
    }
}
