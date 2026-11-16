<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

class RestaurantSeeder extends Seeder
{
    public function run(): void
    {
        $production = app()->environment('production');
        $hash = null;
        if (! $production) {
            $seedPassword = env('SIPAN_SEED_PASSWORD');
            if (! is_string($seedPassword) || strlen($seedPassword) < 16) {
                throw new RuntimeException('Defina SIPAN_SEED_PASSWORD con al menos 16 caracteres antes de sembrar usuarios de demostración.');
            }
            $hash = Hash::make($seedPassword);
        }

        DB::table('PARAMETRO_SISTEMA')->upsert([
            ['clave' => 'IGV', 'valor' => '18', 'descripcion' => 'Tasa IGV %'],
            ['clave' => 'razon_social', 'valor' => 'Chifa Sipan S.A.C.', 'descripcion' => 'Razon social'],
            ['clave' => 'ruc', 'valor' => '20123456789', 'descripcion' => 'RUC emisor'],
            ['clave' => 'serie_boleta', 'valor' => 'B001', 'descripcion' => 'Serie boleta'],
            ['clave' => 'serie_factura', 'valor' => 'F001', 'descripcion' => 'Serie factura'],
            ['clave' => 'serie_nota_venta', 'valor' => 'NV01', 'descripcion' => 'Serie nota de venta'],
        ], ['clave']);

        DB::table('PRIORIDAD')->upsert([
            ['id_prioridad' => 'NORMAL', 'prioridad' => 'Normal', 'color_hex' => '#2563EB', 'activa' => 1],
            ['id_prioridad' => 'URGENTE', 'prioridad' => 'Urgente', 'color_hex' => '#DC2626', 'activa' => 1],
        ], ['id_prioridad']);

        if (DB::table('ESTACION_COCINA')->count() === 0) {
            DB::table('ESTACION_COCINA')->insert([
                ['nombre' => 'Wok', 'activa' => 1],
                ['nombre' => 'Frituras', 'activa' => 1],
                ['nombre' => 'Barra', 'activa' => 1],
            ]);
        }
        $wok = DB::table('ESTACION_COCINA')->where('nombre', 'Wok')->value('id_estacion');
        $barra = DB::table('ESTACION_COCINA')->where('nombre', 'Barra')->value('id_estacion');

        if (DB::table('ZONA')->count() === 0) {
            DB::table('ZONA')->insert([
                ['nombre' => 'Salon', 'activa' => 1],
                ['nombre' => 'Terraza', 'activa' => 1],
            ]);
            $salon = DB::table('ZONA')->where('nombre', 'Salon')->value('id_zona');
            $terraza = DB::table('ZONA')->where('nombre', 'Terraza')->value('id_zona');
            foreach ([1, 2, 3, 4] as $n) {
                DB::table('MESA')->insert(['id_zona' => $salon, 'numero' => $n, 'capacidad' => 4, 'estado' => 'LIBRE', 'activa' => 1]);
            }
            foreach ([5, 6] as $n) {
                DB::table('MESA')->insert(['id_zona' => $terraza, 'numero' => $n, 'capacidad' => 6, 'estado' => 'LIBRE', 'activa' => 1]);
            }
        }

        if (! $production) {
            $personas = [
            ['id_persona' => 'PER-ADMIN', 'nombres' => 'Ana', 'primer_apellido' => 'Sipan', 'segundo_apellido' => 'Li', 'tipo_documento' => 'DNI', 'numero_documento' => '10000001', 'telefono' => '999111001', 'email' => 'admin@chifasipan.pe'],
            ['id_persona' => 'PER-CAJA', 'nombres' => 'Carlos', 'primer_apellido' => 'Caja', 'segundo_apellido' => 'Wong', 'tipo_documento' => 'DNI', 'numero_documento' => '10000002', 'telefono' => '999111002', 'email' => 'cajero@chifasipan.pe'],
            ['id_persona' => 'PER-MESA', 'nombres' => 'Maria', 'primer_apellido' => 'Mesa', 'segundo_apellido' => 'Chan', 'tipo_documento' => 'DNI', 'numero_documento' => '10000003', 'telefono' => '999111003', 'email' => 'mesero@chifasipan.pe'],
            ['id_persona' => 'PER-COC1', 'nombres' => 'Luis', 'primer_apellido' => 'Wok', 'segundo_apellido' => 'Chen', 'tipo_documento' => 'DNI', 'numero_documento' => '10000004', 'telefono' => '999111004', 'email' => 'wok@chifasipan.pe'],
            ['id_persona' => 'PER-COC2', 'nombres' => 'Rosa', 'primer_apellido' => 'Barra', 'segundo_apellido' => 'Hu', 'tipo_documento' => 'DNI', 'numero_documento' => '10000005', 'telefono' => '999111005', 'email' => 'barra@chifasipan.pe'],
            ];
            foreach ($personas as $p) {
                DB::table('PERSONA')->updateOrInsert(['id_persona' => $p['id_persona']], $p);
            }

            $usuarios = [
            ['id_persona' => 'PER-ADMIN', 'username' => 'admin'],
            ['id_persona' => 'PER-CAJA', 'username' => 'cajero'],
            ['id_persona' => 'PER-MESA', 'username' => 'mesero'],
            ['id_persona' => 'PER-COC1', 'username' => 'cocina.wok'],
            ['id_persona' => 'PER-COC2', 'username' => 'cocina.barra'],
            ];
            foreach ($usuarios as $u) {
                DB::table('USUARIO')->updateOrInsert(
                    ['username' => $u['username']],
                    [
                        'id_persona' => $u['id_persona'],
                        'password_hash' => $hash,
                        'activo' => 1,
                        'intentos_fallidos' => 0,
                    ]
                );
            }

            DB::table('ADMINISTRADOR')->updateOrInsert(['id_persona' => 'PER-ADMIN']);
            DB::table('CAJERO')->updateOrInsert(['id_persona' => 'PER-CAJA']);
            DB::table('MESERO')->updateOrInsert(['id_persona' => 'PER-MESA']);
            DB::table('COCINERO')->updateOrInsert(['id_persona' => 'PER-COC1'], ['id_estacion' => $wok]);
            DB::table('COCINERO')->updateOrInsert(['id_persona' => 'PER-COC2'], ['id_estacion' => $barra]);
        }

        if (DB::table('CATEGORIA_PLATO')->count() === 0) {
            DB::table('CATEGORIA_PLATO')->insert([
                ['nombre' => 'Arroces', 'activa' => 1],
                ['nombre' => 'Entradas', 'activa' => 1],
                ['nombre' => 'Sopas', 'activa' => 1],
            ]);
        }
        $arroces = DB::table('CATEGORIA_PLATO')->where('nombre', 'Arroces')->value('id_categoria');
        $entradas = DB::table('CATEGORIA_PLATO')->where('nombre', 'Entradas')->value('id_categoria');
        $sopas = DB::table('CATEGORIA_PLATO')->where('nombre', 'Sopas')->value('id_categoria');

        $productos = [
            ['id_producto' => 'PLT-CHAUFA', 'nombre' => 'Chaufa especial', 'descripcion' => 'Arroz frito clasico', 'requiere_preparacion' => 1, 'precio_actual' => 22.00, 'tiempo_prep_min' => 12, 'imagen_url' => null, 'activo' => 1],
            ['id_producto' => 'PLT-TALLARIN', 'nombre' => 'Tallarin saltado', 'descripcion' => 'Tallarin al wok', 'requiere_preparacion' => 1, 'precio_actual' => 24.00, 'tiempo_prep_min' => 14, 'imagen_url' => null, 'activo' => 1],
            ['id_producto' => 'PLT-WANTAN', 'nombre' => 'Wantan frito', 'descripcion' => 'Porcion de 8 unidades', 'requiere_preparacion' => 1, 'precio_actual' => 12.00, 'tiempo_prep_min' => 8, 'imagen_url' => null, 'activo' => 1],
            ['id_producto' => 'PLT-SOPA', 'nombre' => 'Sopa wantan', 'descripcion' => 'Caldo con wantan', 'requiere_preparacion' => 1, 'precio_actual' => 14.00, 'tiempo_prep_min' => 10, 'imagen_url' => null, 'activo' => 1],
            ['id_producto' => 'BEB-INKA', 'nombre' => 'Inka Kola 500ml', 'descripcion' => 'Gaseosa', 'requiere_preparacion' => 0, 'precio_actual' => 5.00, 'tiempo_prep_min' => 0, 'imagen_url' => null, 'activo' => 1],
        ];
        foreach ($productos as $pr) {
            DB::table('PRODUCTO')->updateOrInsert(['id_producto' => $pr['id_producto']], $pr);
        }

        DB::table('PLATO')->updateOrInsert(['id_producto' => 'PLT-CHAUFA'], ['porcion' => 'PERSONAL', 'id_categoria' => $arroces]);
        DB::table('PLATO')->updateOrInsert(['id_producto' => 'PLT-TALLARIN'], ['porcion' => 'PERSONAL', 'id_categoria' => $arroces]);
        DB::table('PLATO')->updateOrInsert(['id_producto' => 'PLT-WANTAN'], ['porcion' => 'PERSONAL', 'id_categoria' => $entradas]);
        DB::table('PLATO')->updateOrInsert(['id_producto' => 'PLT-SOPA'], ['porcion' => 'PERSONAL', 'id_categoria' => $sopas]);
        DB::table('BEBIDAS')->updateOrInsert(['id_producto' => 'BEB-INKA'], ['volumen_ml' => 500, 'es_alcoholica' => 0, 'temperatura' => 'HELADA']);

        if (DB::table('PLATO_VARIANTE')->where('id_plato', 'PLT-CHAUFA')->count() === 0) {
            DB::table('PLATO_VARIANTE')->insert([
                ['id_plato' => 'PLT-CHAUFA', 'nombre' => 'Pollo', 'precio' => 22.00, 'activo' => 1],
                ['id_plato' => 'PLT-CHAUFA', 'nombre' => 'Especial', 'precio' => 26.00, 'activo' => 1],
            ]);
        }

        DB::table('MODIFICADOR')->updateOrInsert(['nombre' => 'Sin cebolla'], ['precio_extra' => 0]);
        DB::table('MODIFICADOR')->updateOrInsert(['nombre' => 'Extra aji'], ['precio_extra' => 1.50]);

        $frituras = DB::table('ESTACION_COCINA')->where('nombre', 'Frituras')->value('id_estacion');
        $map = [
            'PLT-CHAUFA' => $wok,
            'PLT-TALLARIN' => $wok,
            'PLT-WANTAN' => $frituras,
            'PLT-SOPA' => $wok,
            'BEB-INKA' => $barra,
        ];
        foreach ($map as $prod => $est) {
            DB::table('PRODUCTO_ESTACION')->updateOrInsert(
                ['id_producto' => $prod, 'id_estacion' => $est],
                ['es_principal' => 1]
            );
        }
    }
}
