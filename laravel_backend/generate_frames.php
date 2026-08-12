<?php

$frames = [
    ['name' => 'frame_klasik',  'r' => 200, 'g' => 155, 'b' => 91],
    ['name' => 'frame_modern',  'r' => 30,  'g' => 30,  'b' => 50],
    ['name' => 'frame_vintage', 'r' => 120, 'g' => 60,  'b' => 30],
];

$dir = __DIR__ . '/storage/app/public/frames';
if (!is_dir($dir)) mkdir($dir, 0755, true);

foreach ($frames as $f) {
    $w = 800;
    $h = 1200;
    $img = imagecreatetruecolor($w, $h);
    imagesavealpha($img, true);

    // Background transparan
    $transparent = imagecolorallocatealpha($img, 0, 0, 0, 127);
    imagefill($img, 0, 0, $transparent);

    // Border tebal
    $border = imagecolorallocate($img, $f['r'], $f['g'], $f['b']);
    $thick = 50;
    imagefilledrectangle($img, 0, 0, $w-1, $h-1, $border);

    // Area tengah transparan (area foto customer)
    $clear = imagecolorallocatealpha($img, 0, 0, 0, 127);
    imagefilledrectangle($img, $thick, $thick, $w-$thick-1, $h-$thick-1, $clear);

    // Ornamen sudut emas
    $gold = imagecolorallocate($img, 212, 175, 55);
    $c = 70; // panjang ornamen
    $t = $thick;

    // Top-left
    imagesetthickness($img, 3);
    imageline($img, $t, $t, $t+$c, $t, $gold);
    imageline($img, $t, $t, $t, $t+$c, $gold);
    // Top-right
    imageline($img, $w-$t, $t, $w-$t-$c, $t, $gold);
    imageline($img, $w-$t, $t, $w-$t, $t+$c, $gold);
    // Bottom-left
    imageline($img, $t, $h-$t, $t+$c, $h-$t, $gold);
    imageline($img, $t, $h-$t, $t, $h-$t-$c, $gold);
    // Bottom-right
    imageline($img, $w-$t, $h-$t, $w-$t-$c, $h-$t, $gold);
    imageline($img, $w-$t, $h-$t, $w-$t, $h-$t-$c, $gold);

    $path = $dir . '/' . $f['name'] . '.png';
    imagepng($img, $path);
    imagedestroy($img);
    echo "Created: $path\n";
}
echo "Done!\n";
