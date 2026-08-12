<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => User::latest()->get(['id', 'name', 'email', 'role', 'created_at'])]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'     => ['required', 'string', 'max:255'],
            'email'    => ['required', 'email', 'unique:users'],
            'password' => ['required', 'min:8'],
            'role'     => ['in:admin,operator,viewer'],
        ]);
        $data['password'] = Hash::make($data['password']);
        $user = User::create($data);
        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role'])], 201);
    }

    public function show(User $user): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role', 'created_at'])]);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'name'     => ['sometimes', 'string', 'max:255'],
            'email'    => ['sometimes', 'email', 'unique:users,email,' . $user->id],
            'password' => ['nullable', 'min:8'],
            'role'     => ['in:admin,operator,viewer'],
        ]);
        if (!empty($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        } else {
            unset($data['password']);
        }
        $user->update($data);
        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role'])]);
    }

    public function destroy(User $user): JsonResponse
    {
        $user->delete();
        return response()->json(['success' => true, 'data' => null]);
    }
}
