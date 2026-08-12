<?php

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

App\Models\Frame::where('name', 'Frame Klasik')->update(['asset_url' => 'frames/frame_klasik.png']);
App\Models\Frame::where('name', 'Frame Modern')->update(['asset_url' => 'frames/frame_modern.png']);
App\Models\Frame::where('name', 'Frame Vintage')->update(['asset_url' => 'frames/frame_vintage.png']);

$frames = App\Models\Frame::all(['id', 'name', 'asset_url']);
foreach ($frames as $f) {
    echo "ID:{$f->id} | {$f->name} | {$f->asset_url}\n";
}
echo "Done!\n";
