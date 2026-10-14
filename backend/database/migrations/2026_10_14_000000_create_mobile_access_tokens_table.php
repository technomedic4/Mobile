<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mobile_access_tokens', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('user_id');
            $table->char('token_hash', 64)->unique();
            $table->timestamp('expires_at');
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id', 'fk_mobile_tokens_users')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
            $table->index('expires_at', 'idx_mobile_tokens_expiry');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mobile_access_tokens');
    }
};
