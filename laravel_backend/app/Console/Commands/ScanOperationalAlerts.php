<?php

namespace App\Console\Commands;

use App\Services\OperationalAlertService;
use Illuminate\Console\Command;

class ScanOperationalAlerts extends Command
{
    protected $signature = 'operations:scan-alerts';

    protected $description = 'Mendeteksi masalah operasional dan mengirim notifikasi yang tidak duplikatif';

    public function handle(OperationalAlertService $service): int
    {
        $result = $service->scan();
        $this->info("Pemindaian selesai: {$result['active']} alert aktif, {$result['created_or_refreshed']} kondisi terdeteksi.");

        return self::SUCCESS;
    }
}
