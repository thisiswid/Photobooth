<?php

namespace App\Mail;

use App\Models\PhotoSession;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class PhotoResultMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public PhotoSession $session) {}

    public function build()
    {
        return $this->subject('Foto Photobooth Anda')
                    ->view('emails.photo_result');
    }
}
