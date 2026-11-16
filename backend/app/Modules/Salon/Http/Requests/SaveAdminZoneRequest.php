<?php

namespace App\Modules\Salon\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SaveAdminZoneRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'id_zona' => ['nullable', 'integer', 'min:1'],
            'nombre' => ['required', 'string', 'max:50'],
            'activa' => ['required', 'boolean'],
        ];
    }
}
