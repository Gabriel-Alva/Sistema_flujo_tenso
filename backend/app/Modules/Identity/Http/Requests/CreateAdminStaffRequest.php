<?php

namespace App\Modules\Identity\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreateAdminStaffRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'id_persona' => ['required', 'string', 'max:20'],
            'nombres' => ['required', 'string', 'max:80'],
            'primer_apellido' => ['required', 'string', 'max:80'],
            'segundo_apellido' => ['nullable', 'string', 'max:80'],
            'tipo_documento' => ['nullable', Rule::in(['DNI', 'CE', 'PASAPORTE'])],
            'numero_documento' => ['nullable', 'string', 'max:20'],
            'telefono' => ['nullable', 'string', 'max:20'],
            'email' => ['nullable', 'email', 'max:150'],
            'username' => ['required', 'string', 'max:80', 'alpha_dash'],
            'password' => ['required', 'string', 'min:12', 'max:255'],
            'rol' => ['required', Rule::in(['ADMINISTRADOR', 'CAJERO', 'MESERO', 'COCINERO'])],
            'id_estacion' => ['required_if:rol,COCINERO', 'nullable', 'integer', 'min:1'],
        ];
    }
}
