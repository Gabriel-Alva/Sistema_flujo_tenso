<?php

namespace App\Modules\Catalog\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SaveAdminVariantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'id_variante' => ['nullable', 'integer', 'min:1'],
            'nombre' => ['required', 'string', 'max:40'],
            'precio' => ['required', 'numeric', 'min:0', 'max:99999999.99'],
            'activo' => ['required', 'boolean'],
        ];
    }
}
