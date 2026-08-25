<?php

namespace App\Filament\Forms\Components;

use Filament\Forms\Components\Field;

class FramePencilEditor extends Field
{
    protected string $view = 'filament.forms.components.frame-pencil-editor';

    protected string $imageField = 'asset_url';

    public function imageField(string $field): static
    {
        $this->imageField = $field;
        return $this;
    }

    public function getImageField(): string
    {
        return $this->imageField;
    }
}
