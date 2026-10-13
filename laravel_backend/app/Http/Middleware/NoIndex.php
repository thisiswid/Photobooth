<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Halaman download foto pelanggan bersifat pribadi. Header ini mencegah
 * Google mengindeks halaman maupun file foto/video/GIF-nya, termasuk
 * kalau link QR sempat dibagikan ke tempat publik.
 */
class NoIndex
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $response->headers->set('X-Robots-Tag', 'noindex, nofollow, noimageindex');

        return $response;
    }
}
