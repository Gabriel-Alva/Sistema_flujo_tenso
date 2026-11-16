<?php

namespace App\Modules\Salon\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SaveAdminTableRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'id_mesa' => ['nullable', 'integer', 'min:1'],
            'id_zona' => ['required', 'integer', 'min:1'],
            'numero' => ['required', 'integer', 'min:1', 'max:4294967295'],
            'capacidad' => ['required', 'integer', 'min:1', 'max:65535'],
            'activa' => ['required', 'boolean'],
        ];
    }
}
