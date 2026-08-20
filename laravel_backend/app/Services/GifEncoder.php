<?php

namespace App\Services;

/**
 * Pure PHP Animated GIF Encoder.
 * Correctly handles Global and Local Color Tables, Netscape Application Extensions,
 * and Graphic Control Extensions for 100% valid GIF89a animations.
 */
class GifEncoder
{
    private string $gif = '';
    private array $frames = [];
    private array $delays = [];
    private int $loop = 0;

    /**
     * @param array $frameImages Array of GD image resources / GdImage objects
     * @param array|int $delays Delay in 1/100ths of a second (e.g. 50 = 500ms)
     * @param int $loop 0 = infinite loop
     */
    public function __construct(array $frameImages, array|int $delays = 50, int $loop = 0)
    {
        $this->loop = $loop;

        foreach ($frameImages as $i => $img) {
            ob_start();
            imagegif($img);
            $this->frames[] = ob_get_clean();
            $this->delays[] = is_array($delays) ? ($delays[$i] ?? 50) : $delays;
        }

        $this->encode();
    }

    public function getAnimation(): string
    {
        return $this->gif;
    }

    private function encode(): void
    {
        if (empty($this->frames)) {
            return;
        }

        $firstFrame = $this->frames[0];

        // 1. Header: GIF89a
        $this->gif = "GIF89a";

        // 2. Logical Screen Descriptor (7 bytes: width, height, packed, bg, aspect)
        $screenDesc = substr($firstFrame, 6, 7);
        $this->gif .= $screenDesc;

        // 3. Global Color Table (GCT) from first frame
        $packed = ord($screenDesc[4]);
        $hasGct = ($packed & 0x80) !== 0;
        $gctSize = 0;

        if ($hasGct) {
            $colorCount = 1 << (($packed & 0x07) + 1);
            $gctSize = 3 * $colorCount;
            $this->gif .= substr($firstFrame, 13, $gctSize);
        }

        // 4. Netscape 2.0 Loop Extension (for infinite loop)
        if ($this->loop >= 0) {
            $this->gif .= "\x21\xFF\x0BNETSCAPE2.0\x03\x01" . pack('v', $this->loop) . "\x00";
        }

        // 5. Add Each Frame
        foreach ($this->frames as $idx => $frame) {
            $delay = $this->delays[$idx] ?? 40;

            // Graphic Control Extension (Disposal=2 Restore to BG, UserInput=0, Delay little-endian, TransIdx=0)
            // Block Size = 4 bytes: [Packed 0x08] [Delay low] [Delay high] [Trans 0x00] + [Terminator 0x00]
            $this->gif .= "\x21\xF9\x04\x08" . pack('v', $delay) . "\x00\x00";

            // Find Image Descriptor (0x2C)
            $imgDescPos = strpos($frame, "\x2C");
            if ($imgDescPos === false) {
                continue;
            }

            // For subsequent frames, extract local color table if frame has its own palette
            if ($idx > 0) {
                $fPacked = ord($frame[10]);
                $fHasGct = ($fPacked & 0x80) !== 0;
                if ($fHasGct) {
                    $fColorCount = 1 << (($fPacked & 0x07) + 1);
                    $fGctSize = 3 * $fColorCount;
                    $fColorTable = substr($frame, 13, $fGctSize);

                    // Image descriptor with Local Color Table flag set
                    $imgDesc = substr($frame, $imgDescPos, 10);
                    $imgDesc[9] = chr(ord($imgDesc[9]) | 0x80 | ($fPacked & 0x07));

                    $imageData = substr($frame, $imgDescPos + 10);
                    if (substr($imageData, -1) === "\x3B") {
                        $imageData = substr($imageData, 0, -1);
                    }

                    $this->gif .= $imgDesc . $fColorTable . $imageData;
                    continue;
                }
            }

            // Default image data
            $imageData = substr($frame, $imgDescPos);
            if (substr($imageData, -1) === "\x3B") {
                $imageData = substr($imageData, 0, -1);
            }
            $this->gif .= $imageData;
        }

        // 6. GIF Trailer (0x3B)
        $this->gif .= "\x3B";
    }
}
