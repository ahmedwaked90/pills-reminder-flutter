<?php

namespace App\Http\Controllers;

use App\Models\Medication;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MedicationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $items = $request->user()
            ->medications()
            ->orderBy('name')
            ->get();

        return response()->json(['data' => $items]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validatePayload($request);

        $med = $request->user()->medications()->create($data);

        return response()->json(['data' => $med], 201);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $med = $request->user()->medications()->findOrFail($id);

        return response()->json(['data' => $med]);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $med = $request->user()->medications()->findOrFail($id);
        $med->update($this->validatePayload($request, forUpdate: true));

        return response()->json(['data' => $med]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $med = $request->user()->medications()->findOrFail($id);
        $med->delete();

        return response()->json(['message' => 'deleted']);
    }

    protected function validatePayload(Request $request, bool $forUpdate = false): array
    {
        $required = $forUpdate ? 'sometimes' : 'required';

        return $request->validate([
            'client_uuid'        => [$required, 'string', 'max:64'],
            'name'               => [$required, 'string', 'max:120'],
            'frequency'          => [$required, 'in:once,daily,weekly'],
            'weekdays'           => ['nullable', 'array'],
            'weekdays.*'         => ['integer', 'between:1,7'],
            'times'              => [$required, 'array', 'min:1'],
            'times.*'            => ['string', 'regex:/^([01]\d|2[0-3]):[0-5]\d$/'],
            'start_date'         => [$required, 'date'],
            'end_date'           => ['nullable', 'date', 'after_or_equal:start_date'],
            'dose'               => ['nullable', 'string', 'max:120'],
            'notes'              => ['nullable', 'string', 'max:2000'],
            'client_updated_at'  => ['nullable', 'date'],
        ]);
    }
}
