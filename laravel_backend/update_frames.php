<?php
/**
 * Update Frame & Filter records in database after generating PNG assets.
 * 
 * This script:
 * 1. Updates existing frames or creates new ones with asset_url, pose_count, and layout_config.
 * 2. Updates existing filters or creates new ones with thumbnail_url and parameters.
 *
 * Prerequisites:
 *   - Run `php generate_frames.php` first (generates frame PNGs)
 *   - Run `php generate_filters.php` first (generates filter thumbnails)
 *   - Run `php artisan migrate` to add pose_count & layout_config columns
 *
 * Usage: php update_frames.php
 */

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\Event;
use App\Models\Frame;
use App\Models\Filter;

// Get or create the demo event
$event = Event::where('name', 'SnapTech Demo Event')->orWhere('name', 'LumaBooth Demo Event')->first();
if (!$event) {
    echo "WARNING: No 'SnapTech Demo Event' found. Creating one...\n";
    $event = Event::create([
        'name'        => 'SnapTech Demo Event',
        'description' => 'Demo event untuk SnapTech Photobooth',
        'starts_at'   => now(),
        'ends_at'     => now()->addMonths(6),
        'active'      => true,
    ]);
}

echo "Event: {$event->name} (ID: {$event->id})\n\n";

// ============================================================
// Update Frames
// ============================================================

echo "=== Updating Frames ===\n";

$frames = [
    [
        'name'       => 'Strip Klasik',
        'asset_url'  => 'frames/strip_klasik.png',
        'pose_count' => 4,
        'layout_config' => [
            'slots' => [
                ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 367],
                ['x' => 50, 'y' => 447, 'w' => 1100, 'h' => 367],
                ['x' => 50, 'y' => 844, 'w' => 1100, 'h' => 367],
                ['x' => 50, 'y' => 1241, 'w' => 1100, 'h' => 367],
            ],
        ],
    ],
    [
        'name'       => 'Strip Modern',
        'asset_url'  => 'frames/strip_modern.png',
        'pose_count' => 4,
        'layout_config' => [
            'slots' => [
                ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 380],
                ['x' => 50, 'y' => 450, 'w' => 1100, 'h' => 380],
                ['x' => 50, 'y' => 850, 'w' => 1100, 'h' => 380],
                ['x' => 50, 'y' => 1250, 'w' => 1100, 'h' => 380],
            ],
        ],
    ],
    [
        'name'       => 'Strip Vintage',
        'asset_url'  => 'frames/strip_vintage.png',
        'pose_count' => 3,
        'layout_config' => [
            'slots' => [
                ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
            ],
        ],
    ],
    [
        'name'       => 'Strip Coffee',
        'asset_url'  => 'frames/strip_coffee.png',
        'pose_count' => 4,
        'layout_config' => [
            'slots' => [
                ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 368],
                ['x' => 50, 'y' => 443, 'w' => 1100, 'h' => 368],
                ['x' => 50, 'y' => 836, 'w' => 1100, 'h' => 368],
                ['x' => 50, 'y' => 1229, 'w' => 1100, 'h' => 368],
            ],
        ],
    ],
    [
        'name'       => 'Strip Elegant',
        'asset_url'  => 'frames/strip_elegant.png',
        'pose_count' => 3,
        'layout_config' => [
            'slots' => [
                ['x' => 60, 'y' => 60, 'w' => 1080, 'h' => 473],
                ['x' => 60, 'y' => 573, 'w' => 1080, 'h' => 473],
                ['x' => 60, 'y' => 1086, 'w' => 1080, 'h' => 473],
            ],
        ],
    ],
    [
        'name'       => 'Strip Minimalis',
        'asset_url'  => 'frames/strip_minimalis.png',
        'pose_count' => 4,
        'layout_config' => [
            'slots' => [
                ['x' => 50, 'y' => 50, 'w' => 1100, 'h' => 377],
                ['x' => 50, 'y' => 451, 'w' => 1100, 'h' => 377],
                ['x' => 50, 'y' => 852, 'w' => 1100, 'h' => 377],
                ['x' => 50, 'y' => 1253, 'w' => 1100, 'h' => 377],
            ],
        ],
    ],
];

foreach ($frames as $f) {
    $frame = Frame::updateOrCreate(
        ['name' => $f['name'], 'event_id' => $event->id],
        [
            'asset_url'     => $f['asset_url'],
            'pose_count'    => $f['pose_count'],
            'layout_config' => $f['layout_config'],
            'active'        => true,
        ]
    );
    $status = $frame->wasRecentlyCreated ? 'CREATED' : 'UPDATED';
    echo "  [{$status}] ID:{$frame->id} | {$frame->name} | {$frame->pose_count} poses | {$frame->asset_url}\n";
}

// Clean up old frames that are no longer in the list
$validNames = array_column($frames, 'name');
$removed = Frame::where('event_id', $event->id)
    ->whereNotIn('name', $validNames)
    ->get();
foreach ($removed as $old) {
    echo "  [REMOVED] ID:{$old->id} | {$old->name} (old frame)\n";
    $old->delete();
}

// ============================================================
// Update Filters
// ============================================================

echo "\n=== Updating Filters ===\n";

$filters = [
    [
        'name'          => 'Original',
        'thumbnail_url' => 'filters/filter_original.png',
        'parameters'    => json_encode(['type' => 'none']),
        'sort_order'    => 1,
    ],
    [
        'name'          => 'B&W',
        'thumbnail_url' => 'filters/filter_bw.png',
        'parameters'    => json_encode(['type' => 'grayscale']),
        'sort_order'    => 2,
    ],
    [
        'name'          => 'Warm',
        'thumbnail_url' => 'filters/filter_warm.png',
        'parameters'    => json_encode(['type' => 'colorize', 'r' => 25, 'g' => 10, 'b' => 0, 'brightness' => 10]),
        'sort_order'    => 3,
    ],
    [
        'name'          => 'Cool',
        'thumbnail_url' => 'filters/filter_cool.png',
        'parameters'    => json_encode(['type' => 'colorize', 'r' => -10, 'g' => 0, 'b' => 25, 'brightness' => 5]),
        'sort_order'    => 4,
    ],
    [
        'name'          => 'Vintage',
        'thumbnail_url' => 'filters/filter_vintage.png',
        'parameters'    => json_encode(['type' => 'sepia', 'intensity' => 80]),
        'sort_order'    => 5,
    ],
    [
        'name'          => 'High Contrast',
        'thumbnail_url' => 'filters/filter_high_contrast.png',
        'parameters'    => json_encode(['type' => 'contrast', 'level' => 30]),
        'sort_order'    => 6,
    ],
    [
        'name'          => 'Soft Glow',
        'thumbnail_url' => 'filters/filter_soft_glow.png',
        'parameters'    => json_encode(['type' => 'soft', 'blur' => 1, 'brightness' => 15]),
        'sort_order'    => 7,
    ],
];

foreach ($filters as $f) {
    $filter = Filter::updateOrCreate(
        ['name' => $f['name'], 'event_id' => $event->id],
        [
            'thumbnail_url' => $f['thumbnail_url'],
            'parameters'    => $f['parameters'],
            'sort_order'    => $f['sort_order'],
            'active'        => true,
        ]
    );
    $status = $filter->wasRecentlyCreated ? 'CREATED' : 'UPDATED';
    echo "  [{$status}] ID:{$filter->id} | {$filter->name} | sort:{$filter->sort_order}\n";
}

echo "\nDone! " . count($frames) . " frames + " . count($filters) . " filters updated.\n";
