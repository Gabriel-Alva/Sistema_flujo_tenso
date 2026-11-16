<?php

namespace App\Modules\Billing\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'payment_request_id' => ['required', 'uuid'],
            'id_comprobante' => ['required', 'integer', 'min:1'],
            'id_caja_sesion' => ['required', 'integer', 'min:1'],
            'metodo' => ['required', Rule::in(['EFECTIVO', 'TARJETA', 'YAPE', 'PLIN', 'TRANSFERENCIA'])],
            'monto' => ['required', 'numeric', 'gt:0', 'max:9999999999.99'],
            'monto_recibido' => ['required_if:metodo,EFECTIVO', 'nullable', 'numeric', 'gte:monto', 'max:9999999999.99'],
        ];
    }
}
