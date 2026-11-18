<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('medications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('client_uuid', 64);
            $table->string('name', 120);
            $table->enum('frequency', ['once', 'daily', 'weekly']);
            $table->json('weekdays')->nullable();     // [1..7] ISO weekdays
            $table->json('times');                     // ["08:00", "20:00"]
            $table->date('start_date');
            $table->date('end_date')->nullable();
            $table->string('dose', 120)->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('client_updated_at')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->unique(['user_id', 'client_uuid']);
            $table->index('updated_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('medications');
    }
};
