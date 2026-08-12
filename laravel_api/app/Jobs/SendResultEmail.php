<?php

namespace App\Jobs;

use App\Mail\PhotoResultMail;
use App\Models\PhotoSession;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

class SendResultEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(
        private readonly PhotoSession $session,
        private readonly string $email,
    ) {}

    public function handle(): void
    {
        Mail::to($this->email)->send(new PhotoResultMail($this->session));
    }
}
