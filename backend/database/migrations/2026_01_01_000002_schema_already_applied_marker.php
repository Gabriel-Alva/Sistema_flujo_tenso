<?php

use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        // El esquema de dominio vive en database/schema/*.sql (sipan:install-schema).
        // Esta migración solo marca que el entorno Laravel ya fue alineado.
    }

    public function down(): void
    {
        //
    }
};
