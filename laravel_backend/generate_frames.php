<?php
/**
 * Generate Photo Strip Frame PNGs for SnapTechBooth / Fakultas Kopi Photobooth
 * 
 * Creates 6 frame overlay designs as transparent PNGs (1200×1800 px).
 * Each frame has decorative borders and transparent cutout slots for photos.
 * Designed for 4R (4×6 inch) print at 300 DPI on Epson L8050.
 *
 * Usage: php generate_frames.php
 */

$dir = __DIR__ . '/storage/app/public/frames';
if (!is_dir($dir)) mkdir($dir, 0755, true);

// Canvas dimensions (4R at 300 DPI)
$W = 1200;
$H = 1800;

// ============================================================
// Helper functions
// ============================================================

/**
 * Create a blank canvas with transparency.
 */
function createCanvas(int $w, int $h): GdImage
{
    $img = imagecreatetruecolor($w, $h);
    imagesavealpha($img, true);
    imagealphablending($img, false);
    $transparent = imagecolorallocatealpha($img, 0, 0, 0, 127);
    imagefill($img, 0, 0, $transparent);
    imagealphablending($img, true);
    return $img;
}

/**
 * Draw a filled rectangle with the given color.
 */
function drawRect(GdImage $img, int $x1, int $y1, int $x2, int $y2, int $color): void
{
    imagefilledrectangle($img, $x1, $y1, $x2, $y2, $color);
}

/**
 * Clear a rectangle to transparent (photo slot cutout).
 */
function cutoutSlot(GdImage $img, int $x1, int $y1, int $x2, int $y2): void
{
    imagealphablending($img, false);
    $transparent = imagecolorallocatealpha($img, 0, 0, 0, 127);
    imagefilledrectangle($img, $x1, $y1, $x2, $y2, $transparent);
    imagealphablending($img, true);
}

/**
 * Draw L-shaped corner ornaments at 4 corners of a rectangle.
 */
function drawCornerOrnaments(GdImage $img, int $x1, int $y1, int $x2, int $y2, int $color, int $length = 60, int $thickness = 3): void
{
    imagesetthickness($img, $thickness);
    // Top-left
    imageline($img, $x1, $y1, $x1 + $length, $y1, $color);
    imageline($img, $x1, $y1, $x1, $y1 + $length, $color);
    // Top-right
    imageline($img, $x2, $y1, $x2 - $length, $y1, $color);
    imageline($img, $x2, $y1, $x2, $y1 + $length, $color);
    // Bottom-left
    imageline($img, $x1, $y2, $x1 + $length, $y2, $color);
    imageline($img, $x1, $y2, $x1, $y2 - $length, $color);
    // Bottom-right
    imageline($img, $x2, $y2, $x2 - $length, $y2, $color);
    imageline($img, $x2, $y2, $x2, $y2 - $length, $color);
    imagesetthickness($img, 1);
}

/**
 * Draw a thin decorative line (divider) between photo slots.
 */
function drawDivider(GdImage $img, int $x1, int $y, int $x2, int $color, int $thickness = 1, string $style = 'solid'): void
{
    imagesetthickness($img, $thickness);
    if ($style === 'dashed') {
        $dashLen = 15;
        $gapLen = 10;
        $x = $x1;
        while ($x < $x2) {
            $endX = min($x + $dashLen, $x2);
            imageline($img, $x, $y, $endX, $y, $color);
            $x += $dashLen + $gapLen;
        }
    } else {
        imageline($img, $x1, $y, $x2, $y, $color);
    }
    imagesetthickness($img, 1);
}

/**
 * Draw centered text using GD built-in fonts.
 * Font sizes: 1-5 (built-in), larger = bigger.
 */
function drawCenteredText(GdImage $img, string $text, int $y, int $color, int $fontSize = 4): void
{
    $fontWidth = imagefontwidth($fontSize);
    $textWidth = $fontWidth * strlen($text);
    $imgWidth = imagesx($img);
    $x = (int)(($imgWidth - $textWidth) / 2);
    imagestring($img, $fontSize, $x, $y, $text, $color);
}

/**
 * Draw text with letter-spacing for a more elegant look.
 */
function drawSpacedText(GdImage $img, string $text, int $centerX, int $y, int $color, int $fontSize = 4, int $spacing = 2): void
{
    $fontWidth = imagefontwidth($fontSize) + $spacing;
    $totalWidth = $fontWidth * strlen($text);
    $x = $centerX - (int)($totalWidth / 2);
    for ($i = 0; $i < strlen($text); $i++) {
        imagechar($img, $fontSize, $x + ($i * $fontWidth), $y, $text[$i], $color);
    }
}

/**
 * Draw a thin border rectangle (outline only).
 */
function drawBorderRect(GdImage $img, int $x1, int $y1, int $x2, int $y2, int $color, int $thickness = 1): void
{
    imagesetthickness($img, $thickness);
    imagerectangle($img, $x1, $y1, $x2, $y2, $color);
    imagesetthickness($img, 1);
}

/**
 * Draw a double-line border (inner + outer rectangle).
 */
function drawDoubleBorder(GdImage $img, int $x1, int $y1, int $x2, int $y2, int $color, int $gap = 6): void
{
    drawBorderRect($img, $x1, $y1, $x2, $y2, $color, 2);
    drawBorderRect($img, $x1 + $gap, $y1 + $gap, $x2 - $gap, $y2 - $gap, $color, 1);
}

/**
 * Draw small diamond decorations.
 */
function drawDiamond(GdImage $img, int $cx, int $cy, int $size, int $color): void
{
    $points = [
        $cx, $cy - $size,   // top
        $cx + $size, $cy,   // right
        $cx, $cy + $size,   // bottom
        $cx - $size, $cy,   // left
    ];
    imagefilledpolygon($img, $points, $color);
}

/**
 * Calculate photo slot positions for a given number of poses.
 * Returns array of ['x' => ..., 'y' => ..., 'w' => ..., 'h' => ...].
 */
function calculateSlots(int $poseCount, int $canvasW, int $canvasH, int $margin, int $gap, int $footerH): array
{
    $usableW = $canvasW - (2 * $margin);
    $usableH = $canvasH - (2 * $margin) - $footerH;
    $slotW = $usableW;
    $slotH = (int)(($usableH - ($poseCount - 1) * $gap) / $poseCount);
    
    $slots = [];
    for ($i = 0; $i < $poseCount; $i++) {
        $slots[] = [
            'x' => $margin,
            'y' => $margin + $i * ($slotH + $gap),
            'w' => $slotW,
            'h' => $slotH,
        ];
    }
    return $slots;
}

// ============================================================
// Frame Definitions
// ============================================================

$frames = [

    // --------------------------------------------------------
    // 1. Strip Klasik — Classic gold border, 4 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_klasik',
        'pose_count' => 4,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 50;
            $gap = 30;
            $footerH = 140;

            // Main border (gold/warm beige)
            $borderColor = imagecolorallocate($img, 200, 165, 100);
            $goldAccent  = imagecolorallocate($img, 212, 175, 55);
            $darkGold    = imagecolorallocate($img, 160, 130, 60);
            $textColor   = imagecolorallocate($img, 90, 70, 30);

            // Fill entire canvas with border color
            drawRect($img, 0, 0, $W - 1, $H - 1, $borderColor);

            // Inner decorative double border
            drawDoubleBorder($img, 15, 15, $W - 16, $H - 16, $goldAccent, 8);

            // Cut out photo slots
            $slots = calculateSlots(4, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Gold corner ornaments on each slot
                drawCornerOrnaments($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1, $goldAccent, 40, 2);
            }

            // Footer branding
            $footerY = $H - $footerH + 15;
            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY, $darkGold, 5, 6);
            drawSpacedText($img, 'P H O T O B O O T H', (int)($W / 2), $footerY + 35, $textColor, 4, 3);

            // Small diamond ornaments flanking text
            drawDiamond($img, 200, $footerY + 22, 5, $goldAccent);
            drawDiamond($img, $W - 200, $footerY + 22, 5, $goldAccent);

            // Decorative line under text
            drawDivider($img, 250, $footerY + 65, $W - 250, $darkGold, 1, 'solid');
            
            // Date placeholder text
            drawCenteredText($img, date('d . m . Y'), $footerY + 80, $textColor, 3);

            return $img;
        },
    ],

    // --------------------------------------------------------
    // 2. Strip Modern — Dark navy, 4 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_modern',
        'pose_count' => 4,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 40;
            $gap = 20;
            $footerH = 120;

            // Main border (dark navy)
            $navyColor  = imagecolorallocate($img, 25, 25, 45);
            $accentLine = imagecolorallocate($img, 80, 80, 120);
            $lightGray  = imagecolorallocate($img, 180, 180, 195);
            $white      = imagecolorallocate($img, 240, 240, 245);

            // Fill with navy
            drawRect($img, 0, 0, $W - 1, $H - 1, $navyColor);

            // Single thin accent border
            drawBorderRect($img, 12, 12, $W - 13, $H - 13, $accentLine, 1);

            // Cut out photo slots
            $slots = calculateSlots(4, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Thin white border around each slot
                drawBorderRect($img, $s['x'] - 2, $s['y'] - 2, $s['x'] + $s['w'] + 1, $s['y'] + $s['h'] + 1, $accentLine, 1);
            }

            // Footer
            $footerY = $H - $footerH + 10;
            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY, $white, 5, 5);
            drawCenteredText($img, 'PHOTOBOOTH', $footerY + 35, $lightGray, 3);

            // Minimal accent lines
            drawDivider($img, $margin, $footerY + 60, (int)($W / 2) - 80, $accentLine, 1, 'solid');
            drawDivider($img, (int)($W / 2) + 80, $footerY + 60, $W - $margin, $accentLine, 1, 'solid');

            drawCenteredText($img, date('d/m/Y'), $footerY + 55, $lightGray, 2);

            return $img;
        },
    ],

    // --------------------------------------------------------
    // 3. Strip Vintage — Brown/sepia, 3 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_vintage',
        'pose_count' => 3,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 60;
            $gap = 40;
            $footerH = 180;

            // Brown/sepia tones
            $brownBorder = imagecolorallocate($img, 120, 70, 35);
            $warmTan     = imagecolorallocate($img, 180, 140, 95);
            $darkBrown   = imagecolorallocate($img, 80, 45, 20);
            $cream       = imagecolorallocate($img, 235, 220, 195);

            // Fill with brown border
            drawRect($img, 0, 0, $W - 1, $H - 1, $brownBorder);

            // Inner warm tan layer
            drawRect($img, 10, 10, $W - 11, $H - 11, $warmTan);

            // Double decorative border
            drawDoubleBorder($img, 22, 22, $W - 23, $H - 23, $darkBrown, 10);

            // Cut out 3 photo slots (larger since fewer poses)
            $slots = calculateSlots(3, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $i => $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Vintage double-line border on slots
                drawBorderRect($img, $s['x'] - 3, $s['y'] - 3, $s['x'] + $s['w'] + 2, $s['y'] + $s['h'] + 2, $darkBrown, 2);
                drawBorderRect($img, $s['x'] - 7, $s['y'] - 7, $s['x'] + $s['w'] + 6, $s['y'] + $s['h'] + 6, $darkBrown, 1);
            }

            // Dividers between slots (dashed lines)
            for ($i = 0; $i < count($slots) - 1; $i++) {
                $divY = $slots[$i]['y'] + $slots[$i]['h'] + (int)($gap / 2);
                drawDivider($img, $margin + 30, $divY, $W - $margin - 30, $darkBrown, 1, 'dashed');
            }

            // Footer area
            $footerY = $H - $footerH + 15;
            
            // Decorative line above text
            drawDivider($img, 150, $footerY, $W - 150, $darkBrown, 1, 'solid');
            drawDiamond($img, (int)($W / 2), $footerY, 6, $darkBrown);

            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY + 20, $darkBrown, 5, 5);
            drawSpacedText($img, 'P H O T O B O O T H', (int)($W / 2), $footerY + 55, $brownBorder, 3, 2);
            
            // Vintage ornamental line
            drawDivider($img, 200, $footerY + 85, $W - 200, $darkBrown, 1, 'solid');
            drawDiamond($img, 200, $footerY + 85, 4, $darkBrown);
            drawDiamond($img, $W - 200, $footerY + 85, 4, $darkBrown);
            
            drawCenteredText($img, 'est. ' . date('Y'), $footerY + 100, $brownBorder, 3);

            return $img;
        },
    ],

    // --------------------------------------------------------
    // 4. Strip Coffee — Coffee brown themed, 4 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_coffee',
        'pose_count' => 4,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 45;
            $gap = 25;
            $footerH = 150;

            // Coffee palette
            $espresso  = imagecolorallocate($img, 60, 40, 25);
            $latte     = imagecolorallocate($img, 180, 145, 105);
            $caramel   = imagecolorallocate($img, 200, 155, 90);
            $cream     = imagecolorallocate($img, 240, 230, 210);
            $darkRoast = imagecolorallocate($img, 45, 28, 15);

            // Fill with espresso
            drawRect($img, 0, 0, $W - 1, $H - 1, $espresso);

            // Latte accent border strip
            drawRect($img, 8, 8, $W - 9, $H - 9, $latte);
            drawRect($img, 15, 15, $W - 16, $H - 16, $espresso);

            // Inner caramel line
            drawBorderRect($img, 25, 25, $W - 26, $H - 26, $caramel, 1);

            // Cut out 4 photo slots
            $slots = calculateSlots(4, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Caramel border around slot
                drawBorderRect($img, $s['x'] - 2, $s['y'] - 2, $s['x'] + $s['w'] + 1, $s['y'] + $s['h'] + 1, $caramel, 1);
            }

            // Coffee bean decorations (small circles at divider center)
            for ($i = 0; $i < count($slots) - 1; $i++) {
                $divY = $slots[$i]['y'] + $slots[$i]['h'] + (int)($gap / 2);
                drawDiamond($img, (int)($W / 2), $divY, 5, $caramel);
                // Short accent lines from diamond
                drawDivider($img, (int)($W / 2) - 60, $divY, (int)($W / 2) - 10, $caramel, 1, 'solid');
                drawDivider($img, (int)($W / 2) + 10, $divY, (int)($W / 2) + 60, $caramel, 1, 'solid');
            }

            // Footer area
            $footerY = $H - $footerH + 10;
            
            // Coffee cup icon (simple circle)
            $cupCx = (int)($W / 2);
            $cupCy = $footerY + 10;
            imageellipse($img, $cupCx, $cupCy, 24, 24, $caramel);
            imageellipse($img, $cupCx, $cupCy, 20, 20, $caramel);
            
            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY + 30, $cream, 5, 5);
            drawSpacedText($img, 'P H O T O B O O T H', (int)($W / 2), $footerY + 62, $caramel, 4, 2);

            // Decorative divider
            drawDivider($img, 180, $footerY + 92, $W - 180, $latte, 1, 'solid');
            
            drawCenteredText($img, date('d . m . Y'), $footerY + 105, $latte, 3);

            return $img;
        },
    ],

    // --------------------------------------------------------
    // 5. Strip Elegant — Rose gold, 3 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_elegant',
        'pose_count' => 3,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 55;
            $gap = 35;
            $footerH = 180;

            // Rose gold palette
            $roseGold  = imagecolorallocate($img, 183, 110, 121);
            $softPink  = imagecolorallocate($img, 230, 195, 200);
            $blush     = imagecolorallocate($img, 245, 230, 232);
            $darkRose  = imagecolorallocate($img, 140, 75, 85);
            $white     = imagecolorallocate($img, 255, 250, 250);

            // Fill with soft pink
            drawRect($img, 0, 0, $W - 1, $H - 1, $softPink);

            // Rose gold outer border
            drawBorderRect($img, 5, 5, $W - 6, $H - 6, $roseGold, 3);
            
            // Blush inner area
            drawRect($img, 18, 18, $W - 19, $H - 19, $blush);
            
            // Thin rose gold inner border
            drawBorderRect($img, 22, 22, $W - 23, $H - 23, $roseGold, 1);

            // Cut out 3 photo slots (elegant generous spacing)
            $slots = calculateSlots(3, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Elegant thin rose gold frame around each slot
                drawBorderRect($img, $s['x'] - 3, $s['y'] - 3, $s['x'] + $s['w'] + 2, $s['y'] + $s['h'] + 2, $roseGold, 2);
            }

            // Elegant dividers with diamonds
            for ($i = 0; $i < count($slots) - 1; $i++) {
                $divY = $slots[$i]['y'] + $slots[$i]['h'] + (int)($gap / 2);
                drawDivider($img, $margin + 50, $divY, (int)($W / 2) - 15, $roseGold, 1, 'solid');
                drawDiamond($img, (int)($W / 2), $divY, 4, $darkRose);
                drawDivider($img, (int)($W / 2) + 15, $divY, $W - $margin - 50, $roseGold, 1, 'solid');
            }

            // Footer
            $footerY = $H - $footerH + 15;
            
            // Top decorative element
            drawDiamond($img, (int)($W / 2), $footerY - 5, 5, $roseGold);
            drawDivider($img, 200, $footerY - 5, (int)($W / 2) - 15, $roseGold, 1, 'solid');
            drawDivider($img, (int)($W / 2) + 15, $footerY - 5, $W - 200, $roseGold, 1, 'solid');

            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY + 15, $darkRose, 5, 5);
            drawSpacedText($img, 'P H O T O B O O T H', (int)($W / 2), $footerY + 50, $roseGold, 4, 2);

            // Elegant bottom ornament
            drawDivider($img, 250, $footerY + 85, $W - 250, $roseGold, 1, 'solid');
            drawDiamond($img, 250, $footerY + 85, 3, $roseGold);
            drawDiamond($img, (int)($W / 2), $footerY + 85, 3, $roseGold);
            drawDiamond($img, $W - 250, $footerY + 85, 3, $roseGold);
            
            drawCenteredText($img, date('d . m . Y'), $footerY + 100, $roseGold, 3);

            return $img;
        },
    ],

    // --------------------------------------------------------
    // 6. Strip Minimalis — White/cream, 4 poses
    // --------------------------------------------------------
    [
        'name'       => 'strip_minimalis',
        'pose_count' => 4,
        'generate'   => function(int $W, int $H): GdImage {
            $img = createCanvas($W, $H);
            $margin = 50;
            $gap = 24;
            $footerH = 120;

            // Minimal palette
            $offWhite  = imagecolorallocate($img, 248, 246, 240);
            $lightGray = imagecolorallocate($img, 210, 208, 200);
            $medGray   = imagecolorallocate($img, 160, 158, 150);
            $darkGray  = imagecolorallocate($img, 80, 78, 72);

            // Fill with off-white
            drawRect($img, 0, 0, $W - 1, $H - 1, $offWhite);

            // Single thin border
            drawBorderRect($img, 20, 20, $W - 21, $H - 21, $lightGray, 1);

            // Cut out 4 photo slots
            $slots = calculateSlots(4, $W, $H, $margin, $gap, $footerH);
            foreach ($slots as $s) {
                cutoutSlot($img, $s['x'], $s['y'], $s['x'] + $s['w'] - 1, $s['y'] + $s['h'] - 1);
                // Very subtle thin border
                drawBorderRect($img, $s['x'] - 1, $s['y'] - 1, $s['x'] + $s['w'], $s['y'] + $s['h'], $lightGray, 1);
            }

            // Footer — ultra clean
            $footerY = $H - $footerH + 10;

            drawSpacedText($img, 'FAKULTAS KOPI', (int)($W / 2), $footerY, $darkGray, 4, 4);
            drawCenteredText($img, 'photobooth', $footerY + 28, $medGray, 3);
            
            // Simple line
            drawDivider($img, 350, $footerY + 52, $W - 350, $lightGray, 1, 'solid');
            
            drawCenteredText($img, date('d.m.Y'), $footerY + 65, $medGray, 2);

            return $img;
        },
    ],
];

// ============================================================
// Generate all frames
// ============================================================

echo "=== Generating Photobooth Photo Strip Frames ===\n";
echo "Canvas: {$W}x{$H} px (4R @ 300 DPI)\n\n";

$layoutConfigs = [];

foreach ($frames as $f) {
    $img = ($f['generate'])($W, $H);

    $path = $dir . '/' . $f['name'] . '.png';
    imagepng($img, $path, 1); // compression level 1 (fast, good quality)
    imagedestroy($img);

    // Calculate and store layout config
    $margin = ($f['pose_count'] === 3) ? 60 : 50;
    $gap = ($f['pose_count'] === 3) ? 40 : ($f['name'] === 'strip_minimalis' ? 24 : ($f['name'] === 'strip_modern' ? 20 : ($f['name'] === 'strip_coffee' ? 25 : 30)));
    $footerH = ($f['pose_count'] === 3) ? 180 : ($f['name'] === 'strip_coffee' ? 150 : ($f['name'] === 'strip_minimalis' ? 120 : ($f['name'] === 'strip_modern' ? 120 : 140)));
    
    $slots = calculateSlots($f['pose_count'], $W, $H, $margin, $gap, $footerH);
    $layoutConfigs[$f['name']] = [
        'pose_count' => $f['pose_count'],
        'slots'      => $slots,
    ];

    $fileSize = round(filesize($path) / 1024, 1);
    echo "  [OK] {$f['name']}.png ({$f['pose_count']} poses, {$fileSize} KB)\n";
}

echo "\n=== Layout Configs (for update_frames.php) ===\n";
echo json_encode($layoutConfigs, JSON_PRETTY_PRINT) . "\n";

echo "\nDone! " . count($frames) . " frames generated in: {$dir}\n";
