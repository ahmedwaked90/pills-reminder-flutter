<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Exchange a Google ID token (obtained by the Flutter google_sign_in
     * plugin) for a Sanctum personal access token.
     *
     * POST /api/auth/google
     * body: { "id_token": "<google ID token>", "device_name": "pixel-8" }
     */
    public function google(Request $request): JsonResponse
    {
        $data = $request->validate([
            'id_token'    => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:120'],
        ]);

        $payload = $this->verifyGoogleIdToken($data['id_token']);

        if (! $payload) {
            throw ValidationException::withMessages([
                'id_token' => ['Invalid or expired Google ID token.'],
            ]);
        }

        $allowed = array_filter(preg_split('/\s+/', (string) config('services.google.allowed_audiences')));
        $allowed[] = (string) config('services.google.client_id');
        $allowed = array_filter(array_unique($allowed));

        if (! empty($allowed) && ! in_array($payload['aud'] ?? null, $allowed, true)) {
            throw ValidationException::withMessages([
                'id_token' => ['Google token audience is not allowed for this app.'],
            ]);
        }

        if (empty($payload['email_verified'])) {
            throw ValidationException::withMessages([
                'id_token' => ['Google account email is not verified.'],
            ]);
        }

        $user = User::updateOrCreate(
            ['google_id' => $payload['sub']],
            [
                'name'              => $payload['name'] ?? ($payload['email'] ?? 'User'),
                'email'             => $payload['email'] ?? null,
                'avatar_url'        => $payload['picture'] ?? null,
                'email_verified_at' => now(),
            ]
        );

        $token = $user->createToken($data['device_name'])->plainTextToken;

        return response()->json([
            'token' => $token,
            'user'  => $user->only(['id', 'name', 'email', 'avatar_url']),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $request->user()->only(['id', 'name', 'email', 'avatar_url']),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'logged out']);
    }

    /**
     * Verify a Google ID token against Google's tokeninfo endpoint.
     * In production you may want to validate the JWT signature locally
     * against Google's JWKs; this is simpler and perfectly adequate for
     * a low-volume personal app.
     */
    protected function verifyGoogleIdToken(string $idToken): ?array
    {
        $resp = Http::acceptJson()
            ->timeout(8)
            ->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);

        if (! $resp->ok()) {
            return null;
        }

        $payload = $resp->json();

        if (! is_array($payload) || empty($payload['sub'])) {
            return null;
        }

        if (($payload['iss'] ?? '') !== 'accounts.google.com'
            && ($payload['iss'] ?? '') !== 'https://accounts.google.com') {
            return null;
        }

        if (isset($payload['exp']) && (int) $payload['exp'] < time()) {
            return null;
        }

        return $payload;
    }
}
