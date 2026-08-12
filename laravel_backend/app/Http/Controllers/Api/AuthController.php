<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        $token = $user->createToken('admin-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'data'    => [
                'token' => $token,
                'user'  => $user->only(['id', 'name', 'email', 'role']),
            ],
            'message' => 'Login berhasil.',
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['success' => true, 'data' => null, 'message' => 'Logout berhasil.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data'    => $request->user()->only(['id', 'name', 'email', 'role']),
            'message' => 'OK',
        ]);
    }
}
