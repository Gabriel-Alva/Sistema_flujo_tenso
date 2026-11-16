<?php

namespace App\Modules\Catalog\Actions;

use App\Core\Database\AdminProcedureGateway;

class ManageAdminCatalogAction
{
    public function __construct(private readonly AdminProcedureGateway $procedures) {}

    /** @return array<string, array<int, object>> */
    public function index(string $search, string $state): array
    {
        $variantsByProduct = [];
        foreach ($this->procedures->rows('sp_admin_listar_variantes') as $variant) {
            $variantsByProduct[$variant->id_plato][] = $variant;
        }

        return [
            'products' => $this->procedures->rows('sp_admin_listar_catalogo', [$search, $state]),
            'categories' => $this->procedures->rows('sp_admin_listar_categorias'),
            'stations' => $this->procedures->rows('sp_admin_listar_estaciones'),
            'modifiers' => $this->procedures->rows('sp_admin_listar_modificadores'),
            'priorities' => $this->procedures->rows('sp_admin_listar_prioridades'),
            'variantsByProduct' => $variantsByProduct,
        ];
    }

    /** @param array<string, mixed> $data */
    public function save(array $data): void
    {
        $this->procedures->execute('sp_admin_guardar_producto', [
            (int) auth()->id(),
            $data['id_producto'],
            $data['nombre'],
            ($data['descripcion'] ?? '') ?: null,
            $data['tipo'],
            $data['precio_actual'],
            (int) $data['requiere_preparacion'],
            $data['tiempo_prep_min'],
            ($data['imagen_url'] ?? '') ?: null,
            ($data['id_categoria'] ?? '') ?: null,
            ($data['id_estacion'] ?? '') ?: null,
            ($data['volumen_ml'] ?? '') ?: null,
            isset($data['es_alcoholica']) ? (int) $data['es_alcoholica'] : null,
            ($data['temperatura'] ?? '') ?: null,
        ]);
    }

    public function setActive(string $productId, bool $active): void
    {
        $this->procedures->execute('sp_admin_estado_producto', [
            (int) auth()->id(),
            $productId,
            (int) $active,
        ]);
    }

    /** @param array<string, mixed> $data */
    public function saveVariant(string $productId, array $data): void
    {
        $this->procedures->execute('sp_admin_guardar_variante', [
            (int) auth()->id(),
            $data['id_variante'] ?? null,
            $productId,
            $data['nombre'],
            $data['precio'],
            (int) $data['activo'],
        ]);
    }

    /** @param array<string, mixed> $data */
    public function saveReference(string $entity, array $data): void
    {
        $actor = (int) auth()->id();
        $procedure = match ($entity) {
            'category' => ['sp_admin_guardar_categoria', [
                $actor, $data['id_categoria'] ?? null, $data['nombre'], (int) $data['activa'],
            ]],
            'station' => ['sp_admin_guardar_estacion', [
                $actor, $data['id_estacion'] ?? null, $data['nombre'], (int) $data['activa'],
            ]],
            'modifier' => ['sp_admin_guardar_modificador', [
                $actor, $data['id_modificador'] ?? null, $data['nombre'],
                $data['precio_extra'], (int) $data['activo'],
            ]],
            'priority' => ['sp_admin_guardar_prioridad', [
                $actor, $data['id_prioridad'], $data['prioridad'],
                $data['color_hex'], (int) $data['activa'],
            ]],
            default => throw new \InvalidArgumentException('Tipo de catálogo no permitido.'),
        };

        $this->procedures->execute($procedure[0], $procedure[1]);
    }
}
