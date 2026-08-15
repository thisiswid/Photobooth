<?php

namespace App\Services;

/**
 * Pure PHP Animated GIF Encoder.
 * Combines multiple GD image frames into an animated GIF89a file.
 */
class GifEncoder
{
    private string $gif = '';
    private array $frames = [];
    private array $delays = [];
    private int $loop = 0;
    private int $transparentR = -1;
    private int $transparentG = -1;
    private int $transparentB = -1;

    /**
     * @param array $frameImages Array of GD image resources / GdImage objects
     * @param array|int $delays Delay in 1/100ths of a second (e.g., 50 = 0.5s)
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

        // Header: GIF89a
        $this->gif = "GIF89a";

        // Logical Screen Descriptor from first frame
        $firstFrame = $this->frames[0];
        $screenDescriptor = substr($firstFrame, 6, 7);
        $this->gif .= $screenDescriptor;

        // Netscape 2.0 Loop Extension block
        if ($this->loop >= 0) {
            $this->gif .= "!\xFF\x0BNETSCAPE2.0\x03\x01" . pack('v', $this->loop) . "\x00";
        }

        for ($i = 0; $i < count($this->frames); $i++) {
            $frame = $this->frames[$i];
            $delay = $this->delays[$i];

            // Graphic Control Extension
            $this->gif .= "!\xF9\x04" . pack('C2vC2', 0, 0, $delay, 0, 0);

            // Find Image Descriptor (starts with 0x2C / ',')
            $pos = strpos($frame, ',');
            if ($pos !== false) {
                // Find end of local color table / image data until trailer 0x3B (';')
                $len = strlen($frame);
                if (substr($frame, -1) === ';') {
                    $len -= 1;
                }
                $this->gif .= substr($frame, $pos, $len - $pos);
            }
        }

        // GIF Trailer
        $this->gif .= ";";
    }
}
