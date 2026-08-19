<?php

namespace App\Filament\Resources\FrameResource\Pages;

use App\Filament\Resources\FrameResource;
use App\Models\MasterFrame;
use Filament\Actions\Action;
use Filament\Actions\CreateAction;
use Filament\Forms\Components\Select;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;

class ListFrames extends ListRecords
{
    protected static string $resource = FrameResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('import_from_master')
                ->label('✨ Impor dari Master Library')
                ->icon('heroicon-o-sparkles')
                ->color('info')
                ->form([
                    Select::make('master_frame_id')
                        ->label('Pilih Desain Frame dari Master Library')
                        ->options(
                            MasterFrame::where('is_active', true)
                                ->get()
                                ->mapWithKeys(fn ($mf) => [$mf->id => "[{$mf->category}] {$mf->name} ({$mf->pose_count} Pose)"])
                        )
                        ->searchable()
                        ->required()
                        ->helperText('Template ini akan langsung disalin ke daftar frame aktif cafe Anda.'),
                ])
                ->action(function (array $data) {
                    $masterFrame = MasterFrame::find($data['master_frame_id']);
                    $cafe = auth()->user()?->cafe;

                    if ($masterFrame && $cafe) {
                        $masterFrame->pushToCafe($cafe);
                        Notification::make()
                            ->title("Frame '{$masterFrame->name}' berhasil diimpor ke cafe Anda!")
                            ->success()
                            ->send();
                    }
                }),
            CreateAction::make()->label('Upload Frame Kustom Sendiri'),
        ];
    }
}
