<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class FrameSlotDetector
{
    /**
     * Resolve the absolute filesystem path from Filament/Livewire upload state.
     */
    public static function resolveRealPath(mixed $state): ?string
    {
        if (empty($state)) {
            return null;
        }

        // If array of files (e.g. multi-upload), take first
        if (is_array($state)) {
            $state = reset($state);
        }

        // Livewire Temporary Uploaded File
        if (is_object($state) && method_exists($state, 'getRealPath')) {
            $path = $state->getRealPath();
            if (file_exists($path)) {
                return $path;
            }
        }

        if (is_string($state)) {
            if (file_exists($state)) {
                return $state;
            }
            if (Storage::disk('public')->exists($state)) {
                return Storage::disk('public')->path($state);
            }
            $publicPath = storage_path('app/public/' . ltrim($state, '/'));
            if (file_exists($publicPath)) {
                return $publicPath;
            }
            $appPath = storage_path('app/' . ltrim($state, '/'));
            if (file_exists($appPath)) {
                return $appPath;
            }
        }

        return null;
    }

    /**
     * Intelligent analysis of frame template: detects photo holes, layout type, and pose count.
     * If image is not transparent, optionally punches photo holes using AI Vision.
     */
    public static function analyze(mixed $fileInput, bool $autoPunchTransparency = true): array
    {
        $realPath = self::resolveRealPath($fileInput);
        if (!$realPath || !file_exists($realPath)) {
            return [
                'success'      => false,
                'message'      => 'File frame tidak ditemukan atau belum terunggah sempurna.',
                'layout_type'  => 'single',
                'pose_count'   => 4,
                'slot_count'   => 4,
                'slots'        => [],
                'method'       => 'none',
                'punched'      => false,
            ];
        }

        // 1. Check dimensions & format
        $imageInfo = @getimagesize($realPath);
        $w = $imageInfo[0] ?? 1200;
        $h = $imageInfo[1] ?? 1800;
        $aspectRatio = $h > 0 ? ($w / $h) : 0.66;
        $isPng = ($imageInfo[2] ?? 0) === IMAGETYPE_PNG;

        // 2. Primary method: Alpha Channel Masking (If already transparent PNG)
        // Only trust alpha detection if it finds multiple distinct slots with reasonable sizing.
        // A single giant cluster (e.g. frame_klasik: 92% of frame) means detection failed.
        if ($isPng) {
            $alphaResult = self::detectAlphaCutouts($realPath, $w, $h);
            $alphaSlots = $alphaResult['slots'] ?? [];
            $alphaSlotCount = $alphaResult['slot_count'] ?? 0;

            // Validate: each slot must be <50% of frame height and we need >=2 slots
            $validSlots = array_filter($alphaSlots, function($slot) use ($h) {
                $slotH = ($slot['h'] ?? ($slot['height'] ?? 0));
                return $slotH < ($h * 0.5) && $slotH > ($h * 0.05);
            });

            if ($alphaResult['success'] && count($validSlots) >= 2) {
                $alphaResult['slots'] = array_values($validSlots);
                $alphaResult['slot_count'] = count($validSlots);
                $alphaResult['punched'] = false;
                $alphaResult['relative_path'] = null;
                return $alphaResult;
            }
        }

        // 3. Secondary method: AI Vision (Gemini / OpenAgentic / OpenAI) based on Super Admin config
        $aiSetting = \App\Models\AiSetting::getGlobal();
        $isAiEnabled = $aiSetting->is_enabled && $aiSetting->enable_frame_detection;

        $oaKey = ($aiSetting->provider === 'openagentic' && !empty($aiSetting->api_key))
            ? $aiSetting->api_key 
            : (config('services.openagentic.key') ?? env('OPENAGENTIC_API_KEY'));
        $oaBaseUrl = config('services.openagentic.base_url') ?? env('OPENAGENTIC_BASE_URL', 'https://openagentic.id/api/v1');
        $oaModel = !empty($aiSetting->model) ? $aiSetting->model : (config('services.openagentic.model') ?? env('OPENAGENTIC_MODEL', 'claude-sonnet-4.6'));

        $aiKey = ($aiSetting->provider === 'gemini' && !empty($aiSetting->api_key))
            ? $aiSetting->api_key
            : (config('services.gemini.key') ?? env('GEMINI_API_KEY'));
        $aiModel = !empty($aiSetting->model) ? $aiSetting->model : 'gemini-1.5-flash';

        $aiResult = null;
        $aiFeedback = null;

        if ($isAiEnabled) {
            if ($aiSetting->provider === 'gemini' && !empty($aiKey)) {
                $aiResult = self::detectWithGeminiAi($realPath, $aiKey, $w, $h);
                $aiFeedback = $aiResult['ai_feedback'] ?? null;
            } elseif ($aiSetting->provider === 'openagentic' && !empty($oaKey)) {
                $aiResult = self::detectWithOpenAgenticAi($realPath, $oaKey, $oaBaseUrl, $oaModel, $w, $h);
                $aiFeedback = $aiResult['ai_feedback'] ?? null;
            } else {
                if (!empty($aiKey)) {
                    $aiResult = self::detectWithGeminiAi($realPath, $aiKey, $w, $h);
                    $aiFeedback = $aiResult['ai_feedback'] ?? null;
                } elseif (!empty($oaKey)) {
                    $aiResult = self::detectWithOpenAgenticAi($realPath, $oaKey, $oaBaseUrl, $oaModel, $w, $h);
                    $aiFeedback = $aiResult['ai_feedback'] ?? null;
                }
            }
        } else {
            $aiFeedback = [
                'attempted' => false,
                'success'   => false,
                'status'    => 'warning',
                'title'     => '⚠️ AI Platform Dinonaktifkan',
                'message'   => 'Fitur AI dinonaktifkan di Pengaturan Super Admin. Menggunakan analisis Computer Vision lokal.',
            ];
        }

        // 4. Fallback Heuristic if AI did not return slots
        if (!$aiResult || empty($aiResult['slots'])) {
            $isDouble = ($aspectRatio >= 0.55);
            $layoutType = $isDouble ? 'double_6' : 'single';
            $poseCount = $isDouble ? 3 : 4;
            $slotCount = $isDouble ? 6 : 4;
            $label = $isDouble ? 'Double Strip (6 Slot / 3 Pose Kembar)' : 'Single Strip (4 Pose)';

            $fallbackSlots = self::generateStandardSlots($w, $h, $layoutType, $poseCount);

            $aiResult = [
                'success'      => true,
                'layout_type'  => $layoutType,
                'layout_label' => $label,
                'pose_count'   => $poseCount,
                'slot_count'   => $slotCount,
                'slots'        => $fallbackSlots,
                'dimensions'   => ['w' => $w, 'h' => $h],
                'method'       => 'aspect_ratio_heuristic',
                'confidence'   => 'medium',
                'description'  => "Dianalisis berdasarkan rasio kanvas ({$w}×{$h}px).",
                'ai_feedback'  => $aiFeedback,
            ];
        } else {
            $aiResult['ai_feedback'] = $aiFeedback;
        }

        // 5. If requested, Punch Transparency for the photo slots in-place
        if ($autoPunchTransparency && !empty($aiResult['slots'])) {
            self::punchTransparency($realPath, $aiResult['slots'], $realPath);
            $aiResult['punched'] = true;
            $aiResult['description'] .= " 🪄 Background kotak foto berhasil dilubangi transparan!";
        }

        return $aiResult;
    }

    /**
     * Accurately partitions and assigns pose indices to slots based on layout type and right column order.
     * Guarantees left column is ordered top-to-bottom (0..N) and right column is mapped to rightOrder top-to-bottom.
     */
    public static function assignSlotPoses(array $slots, string $layoutType, ?array $rightOrder = null, int $poseCount = 4): array
    {
        if (empty($slots)) {
            return [];
        }

        if ($layoutType === 'double_6' || $layoutType === 'double_8' || count($slots) >= 6) {
            $expectedRows = ($layoutType === 'double_8' || count($slots) === 8) ? 4 : 3;
            $defaultRight = ($expectedRows === 4) ? [3, 0, 1, 2] : [2, 0, 1];
            $rightOrder = $rightOrder ?: $defaultRight;

            // Find median X coordinate to partition left and right columns
            $xCoords = array_map(fn($s) => $s['x'] + ($s['w'] / 2), $slots);
            sort($xCoords);
            $midX = $xCoords[(int) floor(count($xCoords) / 2)];

            $leftSlots = [];
            $rightSlots = [];

            foreach ($slots as $s) {
                $centerX = $s['x'] + ($s['w'] / 2);
                if ($centerX < $midX) {
                    $leftSlots[] = $s;
                } else {
                    $rightSlots[] = $s;
                }
            }

            // Fallback if partition was unbalanced
            if (empty($leftSlots) || empty($rightSlots)) {
                $half = (int) ceil(count($slots) / 2);
                $leftSlots = array_slice($slots, 0, $half);
                $rightSlots = array_slice($slots, $half);
            }

            // Sort top to bottom (Y ascending)
            usort($leftSlots, fn($a, $b) => $a['y'] <=> $b['y']);
            usort($rightSlots, fn($a, $b) => $a['y'] <=> $b['y']);

            $result = [];
            foreach ($leftSlots as $idx => $s) {
                $s['pose_index'] = $idx;
                $result[] = $s;
            }

            foreach ($rightSlots as $idx => $s) {
                $s['pose_index'] = $rightOrder[$idx] ?? ($idx % max(1, $poseCount));
                $result[] = $s;
            }

            return $result;
        }

        // Single Column: Sort top to bottom (Y ascending)
        usort($slots, fn($a, $b) => $a['y'] <=> $b['y']);
        foreach ($slots as $idx => &$s) {
            $s['pose_index'] = $idx % max(1, $poseCount);
        }
        unset($s);

        return $slots;
    }

    /**
     * Generates standard photobooth slot coordinates based on canvas resolution.
     */
    public static function generateStandardSlots(int $w, int $h, string $layoutType, int $poseCount, ?array $rightOrder = null): array
    {
        $slots = [];
        if ($layoutType === 'double_6' || $layoutType === 'double_8') {
            $rows = ($layoutType === 'double_8') ? 4 : 3;
            $colW = (int) round($w * 0.42);
            $slotH = (int) round($h * ($rows === 4 ? 0.20 : 0.265));
            $leftColX = (int) round($w * 0.055);
            $rightColX = (int) round($w * 0.525);
            $topPad = (int) round($h * ($rows === 4 ? 0.035 : 0.04));
            $gapY = (int) round($h * ($rows === 4 ? 0.025 : 0.035));

            $defaultRight = ($rows === 4) ? [3, 0, 1, 2] : [2, 0, 1];
            $rightOrder = $rightOrder ?: $defaultRight;

            // Left Column
            for ($r = 0; $r < $rows; $r++) {
                $top = $topPad + ($r * ($slotH + $gapY));
                $slots[] = ['x' => $leftColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $r];
            }
            // Right Column
            for ($r = 0; $r < $rows; $r++) {
                $top = $topPad + ($r * ($slotH + $gapY));
                $slots[] = ['x' => $rightColX, 'y' => $top, 'w' => $colW, 'h' => $slotH, 'pose_index' => $rightOrder[$r] ?? ($r % $poseCount)];
            }
        } else {
            // Single Column
            $slotH = (int) round($h * (0.80 / max(1, $poseCount)));
            $slotW = (int) round($w * 0.88);
            $leftX = (int) round($w * 0.06);
            $topPad = (int) round($h * 0.04);
            $gapY = (int) round($h * (0.12 / max(1, $poseCount)));

            for ($r = 0; $r < $poseCount; $r++) {
                $top = $topPad + ($r * ($slotH + $gapY));
                $slots[] = ['x' => $leftX, 'y' => $top, 'w' => $slotW, 'h' => $slotH, 'pose_index' => $r];
            }
        }

        return $slots;
    }

    /**
     * Cut out / punch transparent rectangles into an image and save as PNG.
     */
    public static function punchTransparency(string $sourcePath, array $slots, ?string $targetPath = null): ?string
    {
        if (!file_exists($sourcePath)) {
            return null;
        }

        $imageInfo = @getimagesize($sourcePath);
        if (!$imageInfo) {
            return null;
        }

        $w = $imageInfo[0];
        $h = $imageInfo[1];
        $type = $imageInfo[2];

        $src = match ($type) {
            IMAGETYPE_PNG  => @imagecreatefrompng($sourcePath),
            IMAGETYPE_JPEG => @imagecreatefromjpeg($sourcePath),
            IMAGETYPE_WEBP => @imagecreatefromwebp($sourcePath),
            default        => null,
        };

        if (!$src) {
            return null;
        }

        $dest = imagecreatetruecolor($w, $h);
        imagealphablending($dest, false);
        imagesavealpha($dest, true);

        // Copy source to destination canvas
        imagecopy($dest, $src, 0, 0, 0, 0, $w, $h);

        // Define transparent color (alpha 127 = 100% transparent in GD)
        $transparent = imagecolorallocatealpha($dest, 0, 0, 0, 127);

        // Punch holes for all detected/defined slots
        foreach ($slots as $slot) {
            $sx = max(0, min($w - 1, (int)$slot['x']));
            $sy = max(0, min($h - 1, (int)$slot['y']));
            $sw = max(1, (int)$slot['w']);
            $sh = max(1, (int)$slot['h']);

            imagefilledrectangle($dest, $sx, $sy, min($w, $sx + $sw), min($h, $sy + $sh), $transparent);
        }

        $targetDir = storage_path('app/public/frames');
        if (!file_exists($targetDir)) {
            @mkdir($targetDir, 0755, true);
        }

        if (!$targetPath) {
            $filename = 'transparent_' . uniqid() . '.png';
            $targetPath = $targetDir . DIRECTORY_SEPARATOR . $filename;
            $relativeReturn = 'frames/' . $filename;
        } else {
            $relativeReturn = str_replace([storage_path('app/public/'), storage_path('app/public\\')], '', $targetPath);
        }

        imagepng($dest, $targetPath, 8);

        if (PHP_VERSION_ID < 80000) {
            @imagedestroy($src);
            @imagedestroy($dest);
        }

        return $relativeReturn;
    }

    /**
     * Removes green screen (Chroma Key) areas from an image, turning green pixels 100% transparent.
     * Saves the resulting image as a PNG and detects the bounding box slots automatically.
     */
    public static function removeGreenScreenAndDetectSlots(string $sourcePath, ?string $targetPath = null): array
    {
        if (!file_exists($sourcePath)) {
            return ['success' => false, 'message' => 'File tidak ditemukan', 'slots' => []];
        }

        $imageInfo = @getimagesize($sourcePath);
        if (!$imageInfo) {
            return ['success' => false, 'message' => 'Format gambar tidak valid', 'slots' => []];
        }

        $w = $imageInfo[0];
        $h = $imageInfo[1];
        $type = $imageInfo[2];

        $src = match ($type) {
            IMAGETYPE_PNG  => @imagecreatefrompng($sourcePath),
            IMAGETYPE_JPEG => @imagecreatefromjpeg($sourcePath),
            IMAGETYPE_WEBP => @imagecreatefromwebp($sourcePath),
            default        => null,
        };

        if (!$src) {
            return ['success' => false, 'message' => 'Gagal membaca gambar', 'slots' => []];
        }

        $dest = imagecreatetruecolor($w, $h);
        imagealphablending($dest, false);
        imagesavealpha($dest, true);

        $transparent = imagecolorallocatealpha($dest, 0, 0, 0, 127);

        // Convert green pixels to transparent
        for ($y = 0; $y < $h; $y++) {
            for ($x = 0; $x < $w; $x++) {
                $rgb = imagecolorat($src, $x, $y);
                $r = ($rgb >> 16) & 0xFF;
                $g = ($rgb >> 8) & 0xFF;
                $b = $rgb & 0xFF;
                $alpha = ($rgb & 0x7F000000) >> 24;

                // If already transparent in PNG, preserve transparency
                if ($type === IMAGETYPE_PNG && $alpha > 64) {
                    imagesetpixel($dest, $x, $y, $transparent);
                    continue;
                }

                // Check if color is Chroma Green (#00FF00, #00E000, #00FF11, #39FF14, etc.)
                $isGreen = false;
                if ($g > 110 && $g > ($r + 30) && $g > ($b + 30)) {
                    $isGreen = true;
                } else {
                    // Distance to pure green (0, 255, 0)
                    $dist = sqrt($r * $r + (255 - $g) * (255 - $g) + $b * $b);
                    if ($dist < 135) {
                        $isGreen = true;
                    }
                }

                if ($isGreen) {
                    imagesetpixel($dest, $x, $y, $transparent);
                } else {
                    $color = imagecolorallocatealpha($dest, $r, $g, $b, $alpha);
                    imagesetpixel($dest, $x, $y, $color);
                }
            }
        }

        // Save output file as PNG
        $targetDir = storage_path('app/public/frames');
        if (!file_exists($targetDir)) {
            @mkdir($targetDir, 0755, true);
        }

        if (!$targetPath) {
            $filename = 'chroma_' . uniqid() . '.png';
            $targetPath = $targetDir . DIRECTORY_SEPARATOR . $filename;
            $relativeReturn = 'frames/' . $filename;
        } else {
            if (!str_ends_with(strtolower($targetPath), '.png')) {
                $targetPath = preg_replace('/\.[^.]+$/', '.png', $targetPath);
            }
            $relativeReturn = str_replace([storage_path('app/public/'), storage_path('app/public\\')], '', $targetPath);
        }

        imagepng($dest, $targetPath, 8);

        if (PHP_VERSION_ID < 80000) {
            @imagedestroy($src);
            @imagedestroy($dest);
        }

        // Run alpha cutout detection on the resulting transparent PNG
        $alphaRes = self::detectAlphaCutouts($targetPath, $w, $h);

        return [
            'success'       => true,
            'relative_path' => $relativeReturn,
            'absolute_path' => $targetPath,
            'slots'         => $alphaRes['slots'] ?? [],
            'slot_count'    => $alphaRes['slot_count'] ?? 0,
            'layout_type'   => $alphaRes['layout_type'] ?? 'single',
            'dimensions'    => ['w' => $w, 'h' => $h],
        ];
    }

    /**
     * Computer vision scanner for transparent bounding boxes in PNG.
     */
    public static function detectAlphaCutouts(string $pngPath, int $w, int $h): array
    {
        $im = @imagecreatefrompng($pngPath);
        if (!$im) {
            return ['success' => false, 'slot_count' => 0];
        }

        $step = 6;
        $transparentGrid = [];

        for ($y = 0; $y < $h; $y += $step) {
            for ($x = 0; $x < $w; $x += $step) {
                $rgba = imagecolorat($im, $x, $y);
                $alpha = ($rgba & 0x7F000000) >> 24;
                if ($alpha > 64) {
                    $transparentGrid[] = ['x' => $x, 'y' => $y];
                }
            }
        }

        if (PHP_VERSION_ID < 80000) {
            @imagedestroy($im);
        }

        if (empty($transparentGrid)) {
            return ['success' => false, 'slot_count' => 0];
        }

        $midX = $w / 2;
        $margin = max(10, (int)($w * 0.02));
        $leftSamples = array_filter($transparentGrid, fn($p) => $p['x'] < ($midX - $margin));
        $rightSamples = array_filter($transparentGrid, fn($p) => $p['x'] >= ($midX + $margin));

        $detectColumnClusters = function(array $samples) use ($w, $h) {
            if (empty($samples)) return [];

            $yValues = array_values(array_unique(array_column($samples, 'y')));
            sort($yValues);

            $rowClusters = [];
            $current = [];
            $prev = null;
            foreach ($yValues as $y) {
                if ($prev === null || ($y - $prev) <= 18) {
                    $current[] = $y;
                } else {
                    if (count($current) >= 12) {
                        $rowClusters[] = $current;
                    }
                    $current = [$y];
                }
                $prev = $y;
            }
            if (count($current) >= 12) {
                $rowClusters[] = $current;
            }

            $slots = [];
            foreach ($rowClusters as $cluster) {
                $minY = min($cluster);
                $maxY = max($cluster);
                $slotH = $maxY - $minY;
                if ($slotH < ($h * 0.07)) continue;

                $rowSamples = array_filter($samples, fn($p) => $p['y'] >= $minY && $p['y'] <= $maxY);
                if (empty($rowSamples)) continue;

                $xVals = array_column($rowSamples, 'x');
                $minX = min($xVals);
                $maxX = max($xVals);
                $slotW = $maxX - $minX;
                if ($slotW < ($w * 0.15)) continue;

                $slots[] = [
                    'x' => $minX,
                    'y' => $minY,
                    'w' => $slotW,
                    'h' => $slotH,
                ];
            }
            return $slots;
        };

        // Check if transparent cutouts cross the center vertical axis (Single column vs Double column)
        $centerSamples = array_filter($transparentGrid, fn($p) => abs($p['x'] - $midX) <= max(10, (int)($w * 0.04)));
        $hasCenterCutout = count($centerSamples) >= 10;

        if ($hasCenterCutout) {
            $fullWidthSlots = $detectColumnClusters($transparentGrid);
            if (!empty($fullWidthSlots)) {
                $avgW = array_sum(array_column($fullWidthSlots, 'w')) / count($fullWidthSlots);
                if ($avgW >= ($w * 0.48)) {
                    $count = count($fullWidthSlots);
                    $combinedSlots = self::assignSlotPoses($fullWidthSlots, 'single', [], $count);
                    return [
                        'success'      => true,
                        'layout_type'  => 'single',
                        'layout_label' => "Single Strip {$count} Foto",
                        'pose_count'   => $count,
                        'slot_count'   => $count,
                        'slots'        => $combinedSlots,
                        'dimensions'   => ['w' => $w, 'h' => $h],
                        'method'       => 'alpha_contour',
                        'confidence'   => 'high',
                    ];
                }
            }
        }

        $leftSlots = $detectColumnClusters($leftSamples);
        $rightSlots = $detectColumnClusters($rightSamples);

        $hasDoubleColumn = (count($leftSlots) > 0 && count($rightSlots) > 0);

        if ($hasDoubleColumn) {
            $leftCount = count($leftSlots);
            $rightCount = count($rightSlots);

            if ($leftCount === 3 || ($leftCount + $rightCount) === 6) {
                $layoutType = 'double_6';
                $poseCount = 3;
                $label = 'Double Strip 6 Foto (2 Kolom × 3 Pose)';
            } elseif ($leftCount === 4 || ($leftCount + $rightCount) === 8) {
                $layoutType = 'double_8';
                $poseCount = 4;
                $label = 'Double Strip 8 Foto (2 Kolom × 4 Pose)';
            } else {
                $layoutType = 'double_6';
                $poseCount = max($leftCount, $rightCount);
                $label = "Double Strip ({$leftCount}+{$rightCount} Slot)";
            }

            $rightOrder = ($poseCount === 4) ? [3, 0, 1, 2] : [2, 0, 1];
            $allSlots = array_merge($leftSlots, $rightSlots);
            $combinedSlots = self::assignSlotPoses($allSlots, $layoutType, $rightOrder, $poseCount);

            return [
                'success'      => true,
                'layout_type'  => $layoutType,
                'layout_label' => $label,
                'pose_count'   => $poseCount,
                'slot_count'   => count($combinedSlots),
                'slots'        => $combinedSlots,
                'dimensions'   => ['w' => $w, 'h' => $h],
                'method'       => 'alpha_contour',
                'confidence'   => 'high',
                'description'  => "Ditemukan {$leftCount} slot kiri & {$rightCount} slot kanan transparan secara otomatis.",
            ];
        }

        // Single Column
        $singleSlots = $detectColumnClusters($transparentGrid);
        $slotCount = count($singleSlots);

        if ($slotCount > 0) {
            foreach ($singleSlots as $idx => &$s) {
                $s['pose_index'] = $idx;
            }
            unset($s);

            $layoutType = 'single';
            $poseCount = $slotCount;
            $label = "Single Strip ({$slotCount} Pose Vertikal)";

            return [
                'success'      => true,
                'layout_type'  => $layoutType,
                'layout_label' => $label,
                'pose_count'   => $poseCount,
                'slot_count'   => $slotCount,
                'slots'        => $singleSlots,
                'dimensions'   => ['w' => $w, 'h' => $h],
                'method'       => 'alpha_contour',
                'confidence'   => 'high',
                'description'  => "Ditemukan {$slotCount} kotak lubang foto vertikal transparan secara presisi.",
            ];
        }

        return ['success' => false, 'slot_count' => 0];
    }

    /**
     * Prepare optimized (compressed & scaled down to max 1024px) base64 image for AI API requests.
     * Dramatically reduces payload size from megabytes to ~100KB, preventing network timeouts.
     */
    private static function prepareOptimizedAiImage(string $imagePath, int $maxDim = 1024): array
    {
        $imageInfo = @getimagesize($imagePath);
        if (!$imageInfo) {
            $raw = @file_get_contents($imagePath);
            return [
                'data' => base64_encode($raw ?: ''),
                'mime' => 'image/png',
            ];
        }

        $origW = $imageInfo[0];
        $origH = $imageInfo[1];
        $type  = $imageInfo[2];

        // If image is already small enough, return directly
        if ($origW <= $maxDim && $origH <= $maxDim) {
            return [
                'data' => base64_encode(file_get_contents($imagePath)),
                'mime' => $imageInfo['mime'] ?? 'image/png',
            ];
        }

        // Downscale image using GD
        $src = match ($type) {
            IMAGETYPE_PNG  => @imagecreatefrompng($imagePath),
            IMAGETYPE_JPEG => @imagecreatefromjpeg($imagePath),
            IMAGETYPE_WEBP => @imagecreatefromwebp($imagePath),
            default        => null,
        };

        if (!$src) {
            return [
                'data' => base64_encode(file_get_contents($imagePath)),
                'mime' => $imageInfo['mime'] ?? 'image/png',
            ];
        }

        $scale = min($maxDim / $origW, $maxDim / $origH);
        $newW = (int) round($origW * $scale);
        $newH = (int) round($origH * $scale);

        $dest = imagecreatetruecolor($newW, $newH);
        $white = imagecolorallocate($dest, 255, 255, 255);
        imagefill($dest, 0, 0, $white);
        imagecopyresampled($dest, $src, 0, 0, 0, 0, $newW, $newH, $origW, $origH);

        ob_start();
        imagejpeg($dest, null, 85);
        $jpegData = ob_get_clean();

        imagedestroy($src);
        imagedestroy($dest);

        return [
            'data' => base64_encode($jpegData),
            'mime' => 'image/jpeg',
        ];
    }

    /**
     * Gemini AI Vision detection for non-transparent or complex mockups.
     */
    private static function detectWithGeminiAi(string $imagePath, string $apiKey, int $w, int $h): ?array
    {
        try {
            $optimized = self::prepareOptimizedAiImage($imagePath, 1024);
            $imageData = $optimized['data'];
            $mimeType  = $optimized['mime'];

            $prompt = <<<PROMPT
You are a Computer Vision expert for Photobooth software. Analyze this photobooth frame template.
Detect all rectangular photo placeholder boxes/openings where camera photos should appear.
Return normalized coordinates (0 to 1000) for each box in [ymin, xmin, ymax, xmax].

Determine:
1. "pose_count": Integer number of camera poses/takes (usually 3 or 4).
2. "layout_type": Either "single" (1 column vertical strip), "double_6" (2 columns with 3 photos each = 6 slots), "double_8" (2 columns with 4 photos each = 8 slots), or "grid".
3. "slot_count": Total number of photo slots/openings.
4. "layout_label": Human readable description in Indonesian.
5. "boxes": Array of objects: [{"ymin": int, "xmin": int, "ymax": int, "xmax": int, "pose_index": int}]

Return ONLY valid JSON matching this exact structure:
{
  "pose_count": 4,
  "layout_type": "single",
  "slot_count": 4,
  "layout_label": "Single Strip (4 Pose)",
  "boxes": [
    {"ymin": 40, "xmin": 50, "ymax": 240, "xmax": 950, "pose_index": 0},
    {"ymin": 260, "xmin": 50, "ymax": 460, "xmax": 950, "pose_index": 1},
    {"ymin": 480, "xmin": 50, "ymax": 680, "xmax": 950, "pose_index": 2},
    {"ymin": 700, "xmin": 50, "ymax": 900, "xmax": 950, "pose_index": 3}
  ]
}
PROMPT;

            $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={$apiKey}";
            $response = Http::timeout(25)->post($endpoint, [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $prompt],
                            [
                                'inlineData' => [
                                    'mimeType' => $mimeType,
                                    'data'     => $imageData,
                                ],
                            ],
                        ],
                    ],
                ],
                'generationConfig' => [
                    'responseMimeType' => 'application/json',
                ],
            ]);

            if ($response->successful()) {
                $jsonText = $response->json('candidates.0.content.parts.0.text');
                $parsed = json_decode($jsonText, true);
                if (!empty($parsed['layout_type']) && !empty($parsed['pose_count'])) {
                    $slots = [];
                    if (!empty($parsed['boxes']) && is_array($parsed['boxes'])) {
                        foreach ($parsed['boxes'] as $i => $b) {
                            $sx = (int) round(($b['xmin'] / 1000.0) * $w);
                            $sy = (int) round(($b['ymin'] / 1000.0) * $h);
                            $sw = (int) round((($b['xmax'] - $b['xmin']) / 1000.0) * $w);
                            $sh = (int) round((($b['ymax'] - $b['ymin']) / 1000.0) * $h);
                            $slots[] = [
                                'x'          => $sx,
                                'y'          => $sy,
                                'w'          => $sw,
                                'h'          => $sh,
                                'pose_index' => $b['pose_index'] ?? $i,
                            ];
                        }
                    }

                    return [
                        'success'      => true,
                        'layout_type'  => $parsed['layout_type'],
                        'layout_label' => $parsed['layout_label'] ?? 'AI Detected Layout',
                        'pose_count'   => (int)$parsed['pose_count'],
                        'slot_count'   => (int)($parsed['slot_count'] ?? count($slots)),
                        'slots'        => $slots,
                        'dimensions'   => ['w' => $w, 'h' => $h],
                        'method'       => 'gemini_ai_vision',
                        'confidence'   => 'high',
                        'description'  => 'Dianalisis & dikenali kotak fotonya menggunakan Gemini AI Vision.',
                        'ai_feedback'  => [
                            'attempted' => true,
                            'success'   => true,
                            'status'    => 'success',
                            'title'     => '✨ Gemini AI Vision Sukses!',
                            'message'   => "AI berhasil mendeteksi " . count($slots) . " kotak foto & layout {$parsed['layout_label']}.",
                        ],
                    ];
                }
            }

            // Handle HTTP Error Codes
            $statusCode = $response->status();
            $errorDetail = $response->json('error.message') ?? $response->body();

            if ($statusCode === 429) {
                return [
                    'success'     => false,
                    'ai_feedback' => [
                        'attempted' => true,
                        'success'   => false,
                        'status'    => 'warning',
                        'title'     => '⚠️ Limit Kuota Gemini AI Tercapai (Rate Limit 429)',
                        'message'   => 'Batas permintaan API Gemini harian/menit Anda telah habis. Sistem beralih ke deteksi aspek rasio lokal.',
                    ],
                ];
            }

            if ($statusCode === 400 || $statusCode === 403) {
                return [
                    'success'     => false,
                    'ai_feedback' => [
                        'attempted' => true,
                        'success'   => false,
                        'status'    => 'danger',
                        'title'     => "❌ API Key Gemini Bermasalah (Error {$statusCode})",
                        'message'   => 'GEMINI_API_KEY di file .env tidak valid atau akses ditolak. Periksa API key Anda di Google AI Studio.',
                    ],
                ];
            }

            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => "⚠️ Gagal Menganalisis dengan AI (HTTP {$statusCode})",
                    'message'   => 'Respon AI tidak sesuai. Sistem beralih menggunakan deteksi aspek rasio standar.',
                ],
            ];
        } catch (\Illuminate\Http\Client\ConnectionException $e) {
            Log::warning('Gemini AI Vision connection timeout: ' . $e->getMessage());
            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => '⚠️ Koneksi Gemini AI Timeout',
                    'message'   => 'Gagal menghubungi server Gemini AI karena timeout jaringan. Sistem beralih ke deteksi lokal.',
                ],
            ];
        } catch (\Throwable $e) {
            Log::warning('Gemini AI Vision frame detection error: ' . $e->getMessage());
            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => '⚠️ Terjadi Kesalahan pada AI Vision',
                    'message'   => $e->getMessage(),
                ],
            ];
        }
    }

    /**
     * OpenAgentic AI Vision detection (Claude Sonnet 4.6, etc.) via OpenAI-compatible endpoint.
     */
    private static function detectWithOpenAgenticAi(string $imagePath, string $apiKey, string $baseUrl, string $model, int $w, int $h): ?array
    {
        try {
            $optimized = self::prepareOptimizedAiImage($imagePath, 1024);
            $imageData = $optimized['data'];
            $mimeType  = $optimized['mime'];

            $prompt = <<<PROMPT
You are a Computer Vision expert for Photobooth templates.
Inspect the image and find all rectangular camera photo placeholder boxes/openings.
For each photo opening, return normalized coordinates (0 to 1000) for [ymin, xmin, ymax, xmax].

Output ONLY a single JSON object with this format:
{
  "pose_count": 4,
  "layout_type": "single",
  "slot_count": 4,
  "layout_label": "Single Strip (4 Pose)",
  "boxes": [
    {"ymin": 40, "xmin": 50, "ymax": 240, "xmax": 950, "pose_index": 0},
    {"ymin": 260, "xmin": 50, "ymax": 460, "xmax": 950, "pose_index": 1},
    {"ymin": 480, "xmin": 50, "ymax": 680, "xmax": 950, "pose_index": 2},
    {"ymin": 700, "xmin": 50, "ymax": 900, "xmax": 950, "pose_index": 3}
  ]
}
PROMPT;

            $endpoint = rtrim($baseUrl, '/') . '/chat/completions';
            $response = Http::withToken($apiKey)->timeout(45)->post($endpoint, [
                'model'       => $model,
                'messages'    => [
                    [
                        'role'    => 'user',
                        'content' => [
                            ['type' => 'text', 'text' => $prompt],
                            [
                                'type'      => 'image_url',
                                'image_url' => [
                                    'url' => "data:{$mimeType};base64,{$imageData}",
                                ],
                            ],
                        ],
                    ],
                ],
                'temperature' => 0.0,
                'max_tokens'  => 1200,
                'stream'      => false,
            ]);

            if ($response->successful()) {
                $rawBody = (string) $response->body();
                $cleanJson = preg_replace('/data:\s*\[DONE\].*$/si', '', trim($rawBody));
                $data = json_decode(trim($cleanJson), true);
                $content = $data['choices'][0]['message']['content'] ?? $rawBody;

                $parsed = self::parseJsonSafely($content);

                if (!empty($parsed) && is_array($parsed)) {
                    $slots = self::extractSlotsFromParsedAi($parsed, $w, $h);
                    $slotCount = count($slots);

                    $layoutType = $parsed['layout_type'] ?? null;
                    $poseCount = isset($parsed['pose_count']) ? (int)$parsed['pose_count'] : null;

                    if (empty($layoutType)) {
                        if ($slotCount === 6) {
                            $layoutType = 'double_6';
                            $poseCount = $poseCount ?: 3;
                        } elseif ($slotCount === 8) {
                            $layoutType = 'double_8';
                            $poseCount = $poseCount ?: 4;
                        } else {
                            $layoutType = 'single';
                            $poseCount = $poseCount ?: ($slotCount ?: 4);
                        }
                    }

                    if (empty($poseCount)) {
                        $poseCount = ($layoutType === 'double_6') ? 3 : (($layoutType === 'double_8') ? 4 : max(1, $slotCount));
                    }

                    $label = $parsed['layout_label'] ?? match($layoutType) {
                        'double_6' => 'Double Strip (6 Foto / 3 Pose)',
                        'double_8' => 'Double Strip (8 Foto / 4 Pose)',
                        default    => "Single Strip ({$poseCount} Pose)",
                    };

                    $modelLabel = ($model === 'claude-sonnet-4.6') ? 'Claude Sonnet 4.6' : $model;

                    return [
                        'success'      => true,
                        'layout_type'  => $layoutType,
                        'layout_label' => $label,
                        'pose_count'   => $poseCount,
                        'slot_count'   => $slotCount,
                        'slots'        => $slots,
                        'dimensions'   => ['w' => $w, 'h' => $h],
                        'method'       => 'openagentic_ai_vision',
                        'confidence'   => 'high',
                        'description'  => "Dianalisis & dilubangi menggunakan {$modelLabel} (OpenAgentic).",
                        'ai_feedback'  => [
                            'attempted' => true,
                            'success'   => true,
                            'status'    => 'success',
                            'title'     => "✨ {$modelLabel} Vision Sukses!",
                            'message'   => "AI berhasil mendeteksi {$slotCount} kotak foto & layout {$label}.",
                        ],
                    ];
                }
            }

            // Handle HTTP Error Codes
            $statusCode = $response->status();
            $errorMessage = $response->json('error.message') ?? $response->body();

            if ($statusCode === 429) {
                return [
                    'success'     => false,
                    'ai_feedback' => [
                        'attempted' => true,
                        'success'   => false,
                        'status'    => 'warning',
                        'title'     => '⚠️ Limit Kuota AI Tercapai (Rate Limit 429)',
                        'message'   => 'Batas permintaan API harian/menit telah habis. Menggunakan analisis aspek rasio lokal.',
                    ],
                ];
            }

            if ($statusCode === 400 || $statusCode === 403) {
                return [
                    'success'     => false,
                    'ai_feedback' => [
                        'attempted' => true,
                        'success'   => false,
                        'status'    => 'danger',
                        'title'     => "❌ API Key AI Bermasalah (Error {$statusCode})",
                        'message'   => $errorMessage ?: 'API Key OpenAgentic tidak valid atau akses ditolak.',
                    ],
                ];
            }

            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => "⚠️ Gagal Menganalisis dengan AI (HTTP {$statusCode})",
                    'message'   => 'Respon AI tidak sesuai. Menggunakan deteksi aspek rasio standar.',
                ],
            ];
        } catch (\Illuminate\Http\Client\ConnectionException $e) {
            Log::warning('OpenAgentic AI Vision connection timeout: ' . $e->getMessage());
            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => '⚠️ Koneksi AI Timeout',
                    'message'   => 'Gagal menghubungi server OpenAgentic AI karena timeout jaringan.',
                ],
            ];
        } catch (\Throwable $e) {
            Log::warning('OpenAgentic AI Vision error: ' . $e->getMessage());
            return [
                'success'     => false,
                'ai_feedback' => [
                    'attempted' => true,
                    'success'   => false,
                    'status'    => 'warning',
                    'title'     => '⚠️ Terjadi Kesalahan pada AI Vision',
                    'message'   => $e->getMessage(),
                ],
            ];
        }
    }

    /**
     * Ultra-resilient JSON parser that handles markdown fences, unquoted keys, missing commas, and comments.
     */
    public static function parseJsonSafely(string $content): ?array
    {
        $content = trim($content);
        if (empty($content)) {
            return null;
        }

        // Direct decode attempt
        $direct = json_decode($content, true);
        if (is_array($direct)) {
            return $direct;
        }

        // 1. Extract from markdown code fence
        if (preg_match('/```(?:json)?\s*([\s\S]*?)\s*```/i', $content, $m)) {
            $extracted = trim($m[1]);
            $res = json_decode($extracted, true);
            if (is_array($res)) {
                return $res;
            }
            $content = $extracted;
        }

        // 2. Extract outermost JSON object { ... } or array [ ... ]
        if (preg_match('/\{[\s\S]*\}/', $content, $m)) {
            $content = $m[0];
        } elseif (preg_match('/\[[\s\S]*\]/', $content, $m)) {
            $content = $m[0];
        }

        // 3. Remove comments // and /* */
        $clean = preg_replace('![/][*][\s\S]*?[*][/]!', '', $content);
        $clean = preg_replace('!//.*$!m', '', $clean);

        // 4. Remove trailing dots or ellipsis e.g. ...
        $clean = preg_replace('/\.\.\.+$/', '', trim($clean));

        // 5. Fix missing commas between values and subsequent keys e.g. 506 "ymax"
        $clean = preg_replace('/(\d+|true|false|null|"[^"]*")\s+("([a-zA-Z0-9_-]+)":)/', '$1, $2', $clean);

        // 6. Fix missing commas between objects in array e.g. } {
        $clean = preg_replace('/\}\s*\{/', '}, {', $clean);

        // 7. Remove trailing commas before } or ]
        $clean = preg_replace('/,\s*([\}\]])/', '$1', $clean);

        $res = json_decode($clean, true);
        if (is_array($res)) {
            return $res;
        }

        return null;
    }

    /**
     * Extract rectangular photo slots from parsed AI output with key alias fallback.
     */
    public static function extractSlotsFromParsedAi(array $parsed, int $w, int $h): array
    {
        $rawBoxes = null;
        $boxKeys = ['boxes', 'slots', 'openings', 'photos', 'rectangles', 'photo_boxes', 'photo_slots', 'items'];
        foreach ($boxKeys as $k) {
            if (!empty($parsed[$k]) && is_array($parsed[$k])) {
                $rawBoxes = $parsed[$k];
                break;
            }
        }

        if (!$rawBoxes && isset($parsed[0]) && is_array($parsed[0])) {
            $rawBoxes = $parsed;
        }

        $slots = [];
        if (!empty($rawBoxes) && is_array($rawBoxes)) {
            $lastXmin = 40;
            $lastXmax = 960;
            foreach ($rawBoxes as $i => $b) {
                $ymin = $b['ymin'] ?? $b['top'] ?? $b['y'] ?? $b['y1'] ?? $b['min_y'] ?? 0;
                $ymax = $b['ymax'] ?? $b['bottom'] ?? $b['y2'] ?? $b['max_y'] ?? null;
                $xmin = $b['xmin'] ?? $b['left'] ?? $b['x'] ?? $b['x1'] ?? $b['min_x'] ?? $lastXmin;
                $xmax = $b['xmax'] ?? $b['right'] ?? $b['x2'] ?? $b['max_x'] ?? $lastXmax;

                if ($ymax === null) {
                    $heightNorm = $b['height'] ?? $b['h'] ?? 200;
                    $ymax = $ymin + $heightNorm;
                }
                if (isset($b['width']) || isset($b['w'])) {
                    $widthNorm = $b['width'] ?? $b['w'];
                    $xmax = $xmin + $widthNorm;
                }

                $lastXmin = $xmin;
                $lastXmax = $xmax;

                $isPixel = ($ymin > 1000 || $ymax > 1000 || $xmin > 1000 || $xmax > 1000 || $ymin > $h || $ymax > $h);
                if ($isPixel) {
                    $sx = (int) round($xmin);
                    $sy = (int) round($ymin);
                    $sw = (int) round($xmax - $xmin);
                    $sh = (int) round($ymax - $ymin);
                } else {
                    $sx = (int) round(($xmin / 1000.0) * $w);
                    $sy = (int) round(($ymin / 1000.0) * $h);
                    $sw = (int) round((($xmax - $xmin) / 1000.0) * $w);
                    $sh = (int) round((($ymax - $ymin) / 1000.0) * $h);
                }

                $slots[] = [
                    'x'          => max(0, min($w - 10, $sx)),
                    'y'          => max(0, min($h - 10, $sy)),
                    'w'          => max(10, min($w, $sw)),
                    'h'          => max(10, min($h, $sh)),
                    'pose_index' => $b['pose_index'] ?? $i,
                ];
            }
        }

        return $slots;
    }

    /**
     * Backward-compatible detect method for existing callers.
     */
    public static function detect(string $pngPath, string $layoutType = 'single', ?array $rightOrder = null): array
    {
        $analysis = self::analyze($pngPath, false);
        return $analysis['slots'] ?? [];
    }
}

