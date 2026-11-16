<?php

namespace App\Modules\Kitchen\Actions;

use App\Core\Exceptions\DomainException;
use App\Modules\Identity\Models\Usuario;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

class CancelKitchenCommandAction
{
    public function execute(int $idComanda, string $motivo, Usuario $user): array
    {
        if ($user->rolActivo() !== 'COCINERO') {
            throw new DomainException('FORBIDDEN', 'Solo un cocinero puede cancelar comandas desde su estación.', 403);
        }

        $stationId = $user->idEstacion();
        if (! $stationId) {
            throw new DomainException('FORBIDDEN_STATION', 'El cocinero no tiene una estación asignada.', 403);
        }

        try {
            DB::select('CALL sp_kitchen_cancel_command(?, ?, ?, ?)', [
                $idComanda,
                (int) $user->id_usuario,
                $stationId,
                trim($motivo),
            ]);
        } catch (QueryException $exception) {
            $message = (string) ($exception->errorInfo[2] ?? $exception->getMessage());
            $errors = [
                'COMMAND_NOT_FOUND' => ['Comanda no encontrada.', 404],
                'FORBIDDEN_STATION' => ['La comanda no contiene ítems de su estación.', 403],
                'COMMAND_CANCEL_NOT_ALLOWED' => ['No se puede cancelar la comanda porque la preparación ya comenzó.', 409],
                'COMMAND_NO_PENDING_ITEMS' => ['La comanda no tiene ítems pendientes para cancelar.', 409],
                'COMMAND_CANCEL_REASON_REQUIRED' => ['Escribe un motivo de al menos 3 caracteres.', 422],
            ];

            foreach ($errors as $signal => [$description, $status]) {
                if (str_contains($message, $signal)) {
                    throw new DomainException($signal, $description, $status);
                }
            }

            throw $exception;
        }

        return ['id_comanda' => $idComanda, 'estado_item' => 'CANCELADO'];
    }
}
