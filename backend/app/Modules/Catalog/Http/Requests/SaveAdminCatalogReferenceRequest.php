<?php

namespace App\Modules\Catalog\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SaveAdminCatalogReferenceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return in_array($this->route('entity'), ['category', 'station', 'modifier', 'priority'], true);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return match ($this->route('entity')) {
            'category' => [
                'id_categoria' => ['nullable', 'integer', 'min:1'],
                'nombre' => ['required', 'string', 'max:60'],
                'activa' => ['required', 'boolean'],
            ],
            'station' => [
                'id_estacion' => ['nullable', 'integer', 'min:1'],
                'nombre' => ['required', 'string', 'max:50'],
                'activa' => ['required', 'boolean'],
            ],
            'modifier' => [
                'id_modificador' => ['nullable', 'integer', 'min:1'],
                'nombre' => ['required', 'string', 'max:80'],
                'precio_extra' => ['required', 'numeric', 'min:0', 'max:99999999.99'],
                'activo' => ['required', 'boolean'],
            ],
            'priority' => [
                'id_prioridad' => ['required', 'string', 'max:12'],
                'prioridad' => ['required', 'string', 'max:10'],
                'color_hex' => ['required', 'regex:/^#[0-9A-Fa-f]{6}$/'],
                'activa' => ['required', 'boolean'],
            ],
        };
    }
}
