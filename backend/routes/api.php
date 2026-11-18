<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\MedicationController;
use App\Http\Controllers\SyncController;
use Illuminate\Support\Facades\Route;

// Public
Route::post('/auth/google', [AuthController::class, 'google']);

// Authenticated (Sanctum Bearer token)
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me',     [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::apiResource('medications', MedicationController::class);
    Route::post('/sync', SyncController::class);
});
