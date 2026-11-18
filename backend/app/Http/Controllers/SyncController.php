<?php

namespace App\Http\Controllers;

use App\Models\Medication;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Last-write-wins sync for medications.
 *
 * POST /api/sync
 * body:
 *   {
 *     "since": "<ISO-8601 timestamp or null for first sync>",
 *     "changes": [
 *        {
 *          "client_uuid": "...",
 *          "deleted": false,
 *          "name": "...", "frequency": "daily", "times": ["08:00"],
 *          "weekdays": [1,2,3], "start_date": "2026-11-18",
 *          "end_date": null, "dose": null, "notes": null,
 *          "client_updated_at": "2026-11-18T09:00:00Z"
 *        },
 *        ...
 *     ]
 *   }
 *
 * response:
 *   {
 *     "server_time": "2026-11-18T09:01:02Z",
 *     "applied":   ["<client_uuid>", ...],   // our writes that stuck
 *     "rejected":  [{"client_uuid":"...", "reason":"stale"}],
 *     "changes":   [ ...full Medication rows the server has that are
 *                    newer than `since` for this user, including soft-
 *                    deleted ones so the client can tombstone locally ]
 *   }
 */
class SyncController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'since'                           => ['nullable', 'date'],
            'changes'                         => ['sometimes', 'array'],
            'changes.*.client_uuid'           => ['required', 'string', 'max:64'],
            'changes.*.deleted'               => ['sometimes', 'boolean'],
            'changes.*.name'                  => ['sometimes', 'string', 'max:120'],
            'changes.*.frequency'             => ['sometimes', 'in:once,daily,weekly'],
            'changes.*.weekdays'              => ['sometimes', 'nullable', 'array'],
            'changes.*.weekdays.*'            => ['integer', 'between:1,7'],
            'changes.*.times'                 => ['sometimes', 'array'],
            'changes.*.times.*'               => ['string', 'regex:/^([01]\d|2[0-3]):[0-5]\d$/'],
            'changes.*.start_date'            => ['sometimes', 'date'],
            'changes.*.end_date'              => ['sometimes', 'nullable', 'date'],
            'changes.*.dose'                  => ['sometimes', 'nullable', 'string', 'max:120'],
            'changes.*.notes'                 => ['sometimes', 'nullable', 'string', 'max:2000'],
            'changes.*.client_updated_at'     => ['required', 'date'],
        ]);

        $user     = $request->user();
        $since    = isset($validated['since']) ? Carbon::parse($validated['since']) : null;
        $incoming = $validated['changes'] ?? [];

        $applied  = [];
        $rejected = [];

        DB::transaction(function () use ($user, $incoming, &$applied, &$rejected) {
            foreach ($incoming as $row) {
                $uuid       = $row['client_uuid'];
                $clientTime = Carbon::parse($row['client_updated_at']);
                $deleted    = (bool) ($row['deleted'] ?? false);

                /** @var Medication|null $existing */
                $existing = $user->medications()
                    ->withTrashed()
                    ->where('client_uuid', $uuid)
                    ->first();

                if ($existing) {
                    $serverTime = $existing->client_updated_at ?? $existing->updated_at;
                    if ($serverTime && $serverTime->greaterThanOrEqualTo($clientTime)) {
                        $rejected[] = ['client_uuid' => $uuid, 'reason' => 'stale'];
                        continue;
                    }
                }

                if ($deleted) {
                    if ($existing) {
                        $existing->client_updated_at = $clientTime;
                        $existing->save();
                        $existing->delete();      // soft delete
                    }
                    // if it didn't exist, nothing to delete — treat as applied
                    $applied[] = $uuid;
                    continue;
                }

                $payload = array_intersect_key($row, array_flip([
                    'client_uuid', 'name', 'frequency', 'weekdays', 'times',
                    'start_date', 'end_date', 'dose', 'notes', 'client_updated_at',
                ]));

                if ($existing) {
                    if ($existing->trashed()) {
                        $existing->restore();
                    }
                    $existing->update($payload);
                } else {
                    $user->medications()->create($payload);
                }

                $applied[] = $uuid;
            }
        });

        $serverChanges = $user->medications()
            ->withTrashed()
            ->when($since, fn ($q) => $q->where('updated_at', '>', $since))
            ->orderBy('updated_at')
            ->get()
            ->map(function (Medication $m) {
                $out = $m->toArray();
                $out['deleted'] = $m->trashed();
                return $out;
            });

        return response()->json([
            'server_time' => now()->toIso8601String(),
            'applied'     => $applied,
            'rejected'    => $rejected,
            'changes'     => $serverChanges,
        ]);
    }
}
