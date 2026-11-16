<?php

namespace App\Modules\Identity\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'username' => ['required', 'string', 'max:80'],
            'password' => ['required', 'string'],
            'context' => ['required', Rule::in(['ADMINISTRADOR', 'CAJERO', 'MESERO', 'COCINERO'])],
        ];
    }
}
