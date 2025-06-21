<?php

use Illuminate\Support\Facades\Route;

// Health check endpoint for Cloud Run
Route::get('/health', function () {
    return response()->json([
        'status' => 'OK',
        'timestamp' => now()->toISOString(),
        'service' => 'placetory-backoffice',
    ], 200);
});

Route::get('/', [App\Http\Controllers\HomeController::class, 'root']);
Route::get('{any}', [App\Http\Controllers\HomeController::class, 'index'])->name('index');
