<?php

namespace App\Modules\Orders\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_request_id' => ['required', 'uuid'],
            'tipo' => ['required', 'in:SALON,LLEVAR,DELIVERY'],
            'id_pedido' => ['nullable', 'integer', 'min:1', 'exists:PEDIDO,id_pedido'],
            'id_mesa' => ['required_if:tipo,SALON', 'exclude_unless:tipo,SALON', 'integer', 'min:1', 'exists:MESA,id_mesa'],
            'num_comensales' => ['nullable', 'integer', 'min:1'],
            'notas_generales' => ['nullable', 'string', 'max:2000'],
            'id_cliente' => ['nullable', 'integer', 'exists:CLIENTE,id_cliente', 'required_if:tipo,DELIVERY'],
            'id_direccion_entrega' => ['nullable', 'integer', 'exists:DIRECCION_CLIENTE,id_direccion', 'required_if:tipo,DELIVERY'],
            'direccion_snapshot' => ['nullable', 'array'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.id_producto' => ['required', 'string', 'exists:PRODUCTO,id_producto'],
            'items.*.id_variante' => ['nullable', 'integer', 'min:1', 'exists:PLATO_VARIANTE,id_variante'],
            'items.*.cantidad' => ['required', 'integer', 'min:1'],
            'items.*.prioridad' => ['required', 'string', 'max:12', 'exists:PRIORIDAD,id_prioridad'],
            'items.*.nota' => ['nullable', 'string', 'max:250'],
            'items.*.modificadores' => ['nullable', 'array'],
            'items.*.modificadores.*' => ['integer', 'min:1', 'exists:MODIFICADOR,id_modificador'],
        ];
    }
}
