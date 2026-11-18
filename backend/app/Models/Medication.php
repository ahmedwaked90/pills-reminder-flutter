<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Medication extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'client_uuid',
        'name',
        'frequency',          // 'once' | 'daily' | 'weekly'
        'weekdays',           // array of 1..7 (ISO-8601) for weekly
        'times',              // array of 'HH:mm' strings
        'start_date',         // ISO date
        'end_date',           // ISO date, nullable
        'dose',               // free text, nullable
        'notes',              // free text, nullable
        'client_updated_at',  // what the client thinks the mtime is
    ];

    protected $casts = [
        'weekdays'           => 'array',
        'times'              => 'array',
        'start_date'         => 'date',
        'end_date'           => 'date',
        'client_updated_at'  => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
