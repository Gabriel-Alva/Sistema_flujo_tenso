<?php

namespace App\Modules\Settings\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAdminParameterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        $key = (string) $this->route('key');
        $value = match ($key) {
            'IGV' => ['required', 'numeric', 'min:0', 'max:100'],
            'ruc' => ['required', 'regex:/^\d{11}$/'],
            default => ['required', 'string', 'max:255'],
        };

        if (str_starts_with($key, 'serie_')) {
            $value = ['required', 'alpha_num', 'size:4'];
        }

        return ['valor' => $value];
    }
}
