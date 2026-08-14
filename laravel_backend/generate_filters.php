<?php
/**
 * Generate Filter Thumbnail PNGs for LumaBooth Photobooth
 * Creates 400x400px preview thumbnails for each filter effect.
 * 
 * Usage: php generate_filters.php
 */

$dir = __DIR__ . '/storage/app/public/filters';
if (!is_dir($dir)) mkdir($dir, 0755, true);

$size = 400;

/**
 * Create a sample "photo" base image with a pleasant gradient
 * simulating a portrait photo scene.
 */
function createSampleBase(int $size): GdImage
{
    $img = imagecreatetruecolor($size, $size);
    
    // Sky-to-ground gradient (warm portrait scene)
    for ($y = 0; $y < $size; $y++) {
        $ratio = $y / $size;
        // Top: soft blue sky -> Middle: warm skin tone -> Bottom: earthy
        if ($ratio < 0.4) {
            $r = (int)(135 + $ratio * 180);
            $g = (int)(170 + $ratio * 120);
            $b = (int)(220 - $ratio * 80);
        } elseif ($ratio < 0.7) {
            $r = (int)(210 + ($ratio - 0.4) * 100);
            $g = (int)(180 - ($ratio - 0.4) * 60);
            $b = (int)(150 - ($ratio - 0.4) * 80);
        } else {
            $r = (int)(230 - ($ratio - 0.7) * 120);
            $g = (int)(162 - ($ratio - 0.7) * 80);
            $b = (int)(126 - ($ratio - 0.7) * 60);
        }
        $r = max(0, min(255, $r));
        $g = max(0, min(255, $g));
        $b = max(0, min(255, $b));
        $color = imagecolorallocate($img, $r, $g, $b);
        imageline($img, 0, $y, $size - 1, $y, $color);
    }
    
    // Add a circle to simulate a face/subject
    $cx = (int)($size * 0.5);
    $cy = (int)($size * 0.45);
    $radius = (int)($size * 0.18);
    for ($angle = 0; $angle < 360; $angle += 0.5) {
        for ($r2 = 0; $r2 < $radius; $r2++) {
            $x = (int)($cx + $r2 * cos(deg2rad($angle)));
            $y = (int)($cy + $r2 * sin(deg2rad($angle)));
            if ($x >= 0 && $x < $size && $y >= 0 && $y < $size) {
                $blend = $r2 / $radius;
                $pr = (int)(220 - $blend * 30);
                $pg = (int)(185 - $blend * 20);
                $pb = (int)(160 - $blend * 15);
                $c = imagecolorallocate($img, $pr, $pg, $pb);
                imagesetpixel($img, $x, $y, $c);
            }
        }
    }
    
    return $img;
}

/**
 * Add a label text at the bottom of the thumbnail.
 */
function addLabel(GdImage $img, string $label, int $size): void
{
    $labelH = 50;
    $bgColor = imagecolorallocatealpha($img, 0, 0, 0, 70);
    imagefilledrectangle($img, 0, $size - $labelH, $size - 1, $size - 1, $bgColor);
    
    $white = imagecolorallocate($img, 255, 255, 255);
    $fontSize = 4;
    $textWidth = imagefontwidth($fontSize) * strlen($label);
    $x = (int)(($size - $textWidth) / 2);
    $y = (int)($size - $labelH / 2 - imagefontheight($fontSize) / 2);
    imagestring($img, $fontSize, $x, $y, $label, $white);
}

$filters = [
    [
        'name' => 'original',
        'label' => 'Original',
        'apply' => function(GdImage $img, int $size) {
            // No modification
        }
    ],
    [
        'name' => 'bw',
        'label' => 'B&W',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_GRAYSCALE);
        }
    ],
    [
        'name' => 'warm',
        'label' => 'Warm',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_COLORIZE, 25, 10, 0);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 10);
        }
    ],
    [
        'name' => 'cool',
        'label' => 'Cool',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_COLORIZE, -10, 0, 25);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 5);
        }
    ],
    [
        'name' => 'vintage',
        'label' => 'Vintage',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_GRAYSCALE);
            imagefilter($img, IMG_FILTER_COLORIZE, 40, 20, -10);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, -10);
            imagefilter($img, IMG_FILTER_CONTRAST, -20);
        }
    ],
    [
        'name' => 'high_contrast',
        'label' => 'High Contrast',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_CONTRAST, -40);
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 10);
        }
    ],
    [
        'name' => 'soft_glow',
        'label' => 'Soft Glow',
        'apply' => function(GdImage $img, int $size) {
            imagefilter($img, IMG_FILTER_BRIGHTNESS, 20);
            imagefilter($img, IMG_FILTER_SMOOTH, 6);
            imagefilter($img, IMG_FILTER_COLORIZE, 10, 5, 0);
        }
    ],
];

foreach ($filters as $f) {
    $img = createSampleBase($size);
    ($f['apply'])($img, $size);
    addLabel($img, $f['label'], $size);
    
    $path = $dir . '/filter_' . $f['name'] . '.png';
    imagepng($img, $path);
    imagedestroy($img);
    echo "Created: $path\n";
}

echo "\nDone! " . count($filters) . " filter thumbnails generated.\n";
