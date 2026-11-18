<?php

namespace Tests\Feature;

use App\Models\Medication;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SyncTest extends TestCase
{
    use RefreshDatabase;

    public function test_first_sync_uploads_all_client_changes(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $resp = $this->postJson('/api/sync', [
            'since' => null,
            'changes' => [[
                'client_uuid'       => 'uuid-1',
                'name'              => 'Ibuprofen',
                'frequency'         => 'daily',
                'times'             => ['08:00', '20:00'],
                'start_date'        => '2026-11-18',
                'client_updated_at' => '2026-11-18T09:00:00Z',
            ]],
        ]);

        $resp->assertOk()
             ->assertJsonPath('applied.0', 'uuid-1');

        $this->assertDatabaseHas('medications', [
            'user_id'     => $user->id,
            'client_uuid' => 'uuid-1',
            'name'        => 'Ibuprofen',
        ]);
    }

    public function test_stale_client_write_is_rejected(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $user->medications()->create([
            'client_uuid'       => 'uuid-2',
            'name'              => 'Server version',
            'frequency'         => 'daily',
            'times'             => ['08:00'],
            'start_date'        => '2026-11-18',
            'client_updated_at' => '2026-11-18T10:00:00Z',
        ]);

        $resp = $this->postJson('/api/sync', [
            'since'   => null,
            'changes' => [[
                'client_uuid'       => 'uuid-2',
                'name'              => 'Older client version',
                'frequency'         => 'daily',
                'times'             => ['08:00'],
                'start_date'        => '2026-11-18',
                'client_updated_at' => '2026-11-18T09:00:00Z', // older
            ]],
        ]);

        $resp->assertOk()
             ->assertJsonPath('rejected.0.client_uuid', 'uuid-2')
             ->assertJsonPath('rejected.0.reason', 'stale');

        $this->assertDatabaseHas('medications', [
            'client_uuid' => 'uuid-2',
            'name'        => 'Server version',
        ]);
    }

    public function test_soft_delete_propagates_as_tombstone(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $med = $user->medications()->create([
            'client_uuid'       => 'uuid-3',
            'name'              => 'To be removed',
            'frequency'         => 'daily',
            'times'             => ['08:00'],
            'start_date'        => '2026-11-18',
            'client_updated_at' => '2026-11-18T09:00:00Z',
        ]);

        $resp = $this->postJson('/api/sync', [
            'since' => null,
            'changes' => [[
                'client_uuid'       => 'uuid-3',
                'deleted'           => true,
                'client_updated_at' => '2026-11-18T11:00:00Z',
            ]],
        ]);

        $resp->assertOk()
             ->assertJsonPath('applied.0', 'uuid-3');

        $this->assertSoftDeleted('medications', ['id' => $med->id]);
    }

    public function test_sync_returns_other_devices_changes_since_cursor(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        // Simulate a row created from "another device" before our cursor.
        $old = $user->medications()->create([
            'client_uuid' => 'uuid-old',
            'name'        => 'Old (before cursor)',
            'frequency'   => 'daily',
            'times'       => ['08:00'],
            'start_date'  => '2026-11-15',
        ]);
        $old->update(['updated_at' => '2026-11-15 00:00:00']);

        $fresh = $user->medications()->create([
            'client_uuid' => 'uuid-fresh',
            'name'        => 'Fresh (after cursor)',
            'frequency'   => 'daily',
            'times'       => ['08:00'],
            'start_date'  => '2026-11-20',
        ]);
        $fresh->update(['updated_at' => '2026-11-20 00:00:00']);

        $resp = $this->postJson('/api/sync', [
            'since'   => '2026-11-17T00:00:00Z',
            'changes' => [],
        ]);

        $resp->assertOk();
        $uuids = collect($resp->json('changes'))->pluck('client_uuid')->all();

        $this->assertContains('uuid-fresh', $uuids);
        $this->assertNotContains('uuid-old', $uuids);
    }

    public function test_other_users_rows_are_never_returned(): void
    {
        $me    = User::factory()->create();
        $other = User::factory()->create();

        $other->medications()->create([
            'client_uuid' => 'uuid-other',
            'name'        => 'Not mine',
            'frequency'   => 'daily',
            'times'       => ['08:00'],
            'start_date'  => '2026-11-18',
        ]);

        Sanctum::actingAs($me);

        $resp = $this->postJson('/api/sync', [
            'since'   => null,
            'changes' => [],
        ]);

        $resp->assertOk();
        $this->assertSame([], $resp->json('changes'));
    }

    public function test_unauthenticated_requests_are_rejected(): void
    {
        $this->postJson('/api/sync', [
            'since'   => null,
            'changes' => [],
        ])->assertStatus(401);
    }
}
