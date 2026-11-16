<?php

namespace App\Modules\Kitchen\Actions;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

class UpdateKitchenItemStatusAction
{
    public function execute(
        int $idDetalle,
        string $estado,
        ?string $motivo,
        Usuario $user,
    ): array {
        $role = $user->rolActivo();
        $stationId = null;

        if ($role === 'COCINERO') {
            $stationId = $user->idEstacion();
            if (! $stationId) {
                throw new DomainException('FORBIDDEN_STATION', 'El cocinero no tiene una estación asignada.', 403);
            }
        } elseif ($role !== 'ADMINISTRADOR') {
            throw new DomainException('FORBIDDEN', 'No tiene permiso para actualizar ítems de cocina.', 403);
        }

        try {
            DB::select('CALL sp_kitchen_update_item_status(?, ?, ?, ?, ?)', [
                $idDetalle,
                $estado,
                (int) $user->id_usuario,
                $stationId,
                $motivo !== null ? trim($motivo) : null,
            ]);
        } catch (QueryException $exception) {
            $message = (string) ($exception->errorInfo[2] ?? $exception->getMessage());
            $errors = [
                'ITEM_NOT_FOUND' => ['Ítem no encontrado.', 404],
                'FORBIDDEN_STATION' => ['El ítem pertenece a otra estación.', 403],
                'INVALID_ITEM_TRANSITION' => ['La transición de estado no está permitida.', 409],
                'ITEM_CANCEL_REASON_REQUIRED' => ['Escribe un motivo de al menos 3 caracteres.', 422],
            ];

            foreach ($errors as $signal => [$description, $status]) {
                if (str_contains($message, $signal)) {
                    throw new DomainException($signal, $description, $status);
                }
            }

            throw $exception;
        }

        return ['id_detalle' => $idDetalle, 'estado_item' => $estado];
    }
}
