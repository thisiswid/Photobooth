<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Traits\ScopesToCafe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    use ScopesToCafe;

    /** Super admin tidak pernah tampil atau bisa disunting lewat API ini. */
    protected function baseQuery()
    {
        return $this->scopeOwn(User::query())->where('role', '!=', 'super_admin');
    }

    public function index(): JsonResponse
    {
        $users = $this->baseQuery()->latest()->get(['id', 'name', 'email', 'role', 'cafe_id', 'created_at']);
        return response()->json(['success' => true, 'data' => $users]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->requireAdmin();

        $data = $request->validate([
            'name'     => ['required', 'string', 'max:255'],
            'email'    => ['required', 'email', 'unique:users'],
            'password' => ['required', 'min:8'],
            'role'     => ['required', 'in:admin,operator,viewer'],
        ]);
        $data['password'] = Hash::make($data['password']);

        // Tanpa ini pengguna baru lahir dengan cafe_id null dan melihat
        // seluruh tenant di panel admin.
        $user = User::create($this->withCafeId($data));

        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role'])], 201);
    }

    public function show(User $user): JsonResponse
    {
        $this->guardUser($user);
        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role', 'created_at'])]);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $this->requireAdmin();
        $this->guardUser($user);

        $data = $request->validate([
            'name'     => ['sometimes', 'string', 'max:255'],
            'email'    => ['sometimes', 'email', 'unique:users,email,' . $user->id],
            'password' => ['nullable', 'min:8'],
            'role'     => ['sometimes', 'in:admin,operator,viewer'],
        ]);
        if (!empty($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        } else {
            unset($data['password']);
        }
        $user->update($data);
        return response()->json(['success' => true, 'data' => $user->only(['id', 'name', 'email', 'role'])]);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $this->requireAdmin();
        $this->guardUser($user);

        abort_if($user->id === $request->user()->id, 422, 'Tidak bisa menghapus akun sendiri.');

        $user->delete();
        return response()->json(['success' => true, 'data' => null]);
    }

    /** Hanya pengguna satu cafe, dan tidak pernah super admin. */
    protected function guardUser(User $user): void
    {
        abort_if($user->isSuperAdmin(), 404, 'Data tidak ditemukan.');
        $this->guardCafe($user->cafe_id);
    }
}
