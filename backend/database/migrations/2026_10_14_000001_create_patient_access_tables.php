<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('patient_access_requests', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('requester_user_id');
            $table->integer('patient_id')->nullable();
            $table->string('national_id', 16);
            $table->string('patient_name', 150);
            $table->string('phone_number', 20);
            $table->date('birth_date')->nullable();
            $table->string('gender', 1)->nullable();
            $table->text('address')->nullable();
            $table->string('relationship', 40);
            $table->string('status', 20)->default('Pending');
            $table->integer('reviewed_by_user_id')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->foreign('requester_user_id', 'fk_patient_access_requests_requester')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
            $table->foreign('patient_id', 'fk_patient_access_requests_patient')
                ->references('id')
                ->on('patient_profiles')
                ->nullOnDelete();
            $table->foreign('reviewed_by_user_id', 'fk_patient_access_requests_reviewer')
                ->references('id')
                ->on('users')
                ->nullOnDelete();
            $table->index(['requester_user_id', 'status'], 'idx_patient_access_requests_owner');
        });

        Schema::create('authorized_patient_accounts', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('patient_id');
            $table->integer('account_user_id');
            $table->string('relationship', 40);
            $table->integer('approved_by_user_id');
            $table->timestamp('approved_at');
            $table->timestamps();

            $table->foreign('patient_id', 'fk_authorized_accounts_patient')
                ->references('id')
                ->on('patient_profiles')
                ->cascadeOnDelete();
            $table->foreign('account_user_id', 'fk_authorized_accounts_user')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
            $table->foreign('approved_by_user_id', 'fk_authorized_accounts_approver')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
            $table->unique(['patient_id', 'account_user_id'], 'uq_authorized_patient_account');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('authorized_patient_accounts');
        Schema::dropIfExists('patient_access_requests');
    }
};
