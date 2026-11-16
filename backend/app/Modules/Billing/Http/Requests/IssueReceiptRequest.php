<?php

namespace App\Modules\Billing\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class IssueReceiptRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'id_pedido' => ['required', 'integer', 'min:1'],
            'receipt_request_id' => ['required', 'uuid'],
            'id_cliente' => ['nullable', 'integer', 'exists:CLIENTE,id_cliente', 'required_if:tipo,FACTURA'],
            'tipo' => ['required', Rule::in(['BOLETA', 'FACTURA', 'NOTA_VENTA', 'NOTA_CREDITO'])],
        ];
    }
}
