<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        match (DB::getDriverName()) {
            'pgsql' => DB::statement(
                'ALTER TABLE notifications ALTER COLUMN data TYPE json USING data::json'
            ),
            'mysql', 'mariadb' => DB::statement(
                'ALTER TABLE notifications MODIFY data JSON NOT NULL'
            ),
            // SQLite menerima JSON sebagai text affinity dan menyediakan
            // operator JSON yang dibutuhkan Filament.
            default => null,
        };
    }

    public function down(): void
    {
        match (DB::getDriverName()) {
            'pgsql' => DB::statement(
                'ALTER TABLE notifications ALTER COLUMN data TYPE text USING data::text'
            ),
            'mysql', 'mariadb' => DB::statement(
                'ALTER TABLE notifications MODIFY data TEXT NOT NULL'
            ),
            default => null,
        };
    }
};
