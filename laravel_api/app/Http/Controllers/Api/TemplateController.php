<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Frame;
use App\Models\Package;
use App\Models\Sticker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TemplateController extends Controller
{
    // Frames
    public function frames(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => Frame::all(),
        ]);
    }

    public function storeFrame(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'       => 'required|string',
            'image_path' => 'required|string',
        ]);

        $frame = Frame::create($validated);

        return response()->json([
            'success' => true,
            'data'    => $frame,
        ], 201);
    }

    public function deleteFrame(int $id): JsonResponse
    {
        Frame::findOrFail($id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Frame berhasil dihapus.',
        ]);
    }

    // Stickers
    public function stickers(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => Sticker::all(),
        ]);
    }

    public function storeSticker(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'       => 'required|string',
            'image_path' => 'required|string',
        ]);

        $sticker = Sticker::create($validated);

        return response()->json([
            'success' => true,
            'data'    => $sticker,
        ], 201);
    }

    public function deleteSticker(int $id): JsonResponse
    {
        Sticker::findOrFail($id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Sticker berhasil dihapus.',
        ]);
    }

    // Packages
    public function packages(): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => Package::all(),
        ]);
    }

    public function storePackage(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'  => 'required|string',
            'price' => 'required|numeric',
        ]);

        $package = Package::create($validated);

        return response()->json([
            'success' => true,
            'data'    => $package,
        ], 201);
    }

    public function deletePackage(int $id): JsonResponse
    {
        Package::findOrFail($id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Paket berhasil dihapus.',
        ]);
    }
}
