<?php

namespace App\Services;

class FrameSlotDetector
{
    /**
     * Automatically detect transparent rectangular cutout holes in a frame PNG image.
     */
    public static function detect(string $pngPath, string $layoutType = 'single', ?array $rightOrder = null): array
    {
        if (!file_exists($pngPath)) {
            return [];
        }

        $im = @imagecreatefrompng($pngPath);
        if (!$im) {
            return [];
        }

        $w = imagesx($im);
        $h = imagesy($im);

        // Sample pixels with a step of 6px
        $step = 6;
        $transparentGrid = [];

        for ($y = 0; $y < $h; $y += $step) {
            for ($x = 0; $x < $w; $x += $step) {
                $rgba = imagecolorat($im, $x, $y);
                $alpha = ($rgba & 0x7F000000) >> 24;
                // > 64 is mostly to fully transparent in PHP GD
                if ($alpha > 64) {
                    $transparentGrid[] = ['x' => $x, 'y' => $y];
                }
            }
        }

        imagedestroy($im);

        if (empty($transparentGrid)) {
            return [];
        }

        $midX = $w / 2;
        $leftSamples = array_filter($transparentGrid, fn($p) => $p['x'] < ($midX - 10));
        $rightSamples = array_filter($transparentGrid, fn($p) => $p['x'] >= ($midX + 10));

        $detectColumnSlots = function($samples, $poseOrder = null) use ($w, $h) {
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
                    if (count($current) >= 15) {
                        $rowClusters[] = $current;
                    }
                    $current = [$y];
                }
                $prev = $y;
            }
            if (count($current) >= 15) {
                $rowClusters[] = $current;
            }

            $slots = [];
            foreach ($rowClusters as $rIdx => $cluster) {
                $minY = min($cluster);
                $maxY = max($cluster);
                $slotH = $maxY - $minY;
                if ($slotH < ($h * 0.08)) continue; // skip tiny transparent artifacts

                $rowSamples = array_filter($samples, fn($p) => $p['y'] >= $minY && $p['y'] <= $maxY);
                if (empty($rowSamples)) continue;

                $xVals = array_column($rowSamples, 'x');
                $minX = min($xVals);
                $maxX = max($xVals);
                $slotW = $maxX - $minX;
                if ($slotW < ($w * 0.2)) continue;

                $poseIndex = $poseOrder && isset($poseOrder[$rIdx]) ? $poseOrder[$rIdx] : $rIdx;

                $slots[] = [
                    'x'          => $minX,
                    'y'          => $minY,
                    'w'          => $slotW,
                    'h'          => $slotH,
                    'pose_index' => $poseIndex,
                ];
            }
            return $slots;
        };

        if ($layoutType === 'double_6' || $layoutType === 'double_8') {
            $defaultRight = ($layoutType === 'double_8') ? [3, 0, 1, 2] : [2, 0, 1];
            $rightOrder = $rightOrder ?: $defaultRight;

            $leftSlots = $detectColumnSlots($leftSamples, null);
            $rightSlots = $detectColumnSlots($rightSamples, $rightOrder);

            if (count($leftSlots) > 0 && count($rightSlots) > 0) {
                return array_merge($leftSlots, $rightSlots);
            }
        }

        return $detectColumnSlots($transparentGrid, null);
    }
}
