<?php

namespace App\Modules\Catalog\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SaveAdminProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'id_producto' => ['required', 'string', 'max:15'],
            'nombre' => ['required', 'string', 'max:120'],
            'descripcion' => ['nullable', 'string', 'max:1000'],
            'tipo' => ['required', Rule::in(['PLATO', 'BEBIDA', 'OTRO'])],
            'precio_actual' => ['required', 'numeric', 'min:0', 'max:99999999.99'],
            'requiere_preparacion' => ['required', 'boolean'],
            'tiempo_prep_min' => ['required', 'integer', 'min:0', 'max:65535'],
            'imagen_url' => ['nullable', 'string', 'max:255', 'regex:/^(https?:\/\/|\/|[A-Za-z0-9_-]+\/)[^\s]*$/i'],
            'id_categoria' => ['required_if:tipo,PLATO', 'nullable', 'integer', 'min:1'],
            'id_estacion' => ['required_if:requiere_preparacion,1', 'nullable', 'integer', 'min:1'],
            'volumen_ml' => ['nullable', 'integer', 'min:1', 'max:2147483647'],
            'es_alcoholica' => ['nullable', 'boolean'],
            'temperatura' => ['nullable', Rule::in(['HELADA', 'TEMPERATURA_AMBIENTE', 'CALIENTE'])],
        ];
    }
}
