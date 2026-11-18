<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'name'    => config('app.name'),
        'status'  => 'ok',
        'docs'    => 'See backend/README.md for the API contract.',
    ]);
});
