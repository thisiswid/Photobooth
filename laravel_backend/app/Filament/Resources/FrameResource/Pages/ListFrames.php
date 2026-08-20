<?php

namespace App\Filament\Resources\FrameResource\Pages;

use App\Filament\Resources\FrameResource;
use App\Models\Frame;
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
                        ->options(function () {
                            $cafe = auth()->user()?->cafe;
                            if (!$cafe) {
                                return MasterFrame::where('is_active', true)
                                    ->get()
                                    ->mapWithKeys(fn ($mf) => [$mf->id => "[{$mf->category}] {$mf->name} ({$mf->pose_count} Pose)"]);
                            }

                            // Dapatkan ID master frame atau nama frame yang sudah ada di cafe ini
                            $installedMasterIds = Frame::whereHas('event', fn ($q) => $q->where('cafe_id', $cafe->id))
                                ->whereNotNull('master_frame_id')
                                ->pluck('master_frame_id')
                                ->toArray();

                            $installedNames = Frame::whereHas('event', fn ($q) => $q->where('cafe_id', $cafe->id))
                                ->pluck('name')
                                ->toArray();

                            return MasterFrame::where('is_active', true)
                                ->whereNotIn('id', $installedMasterIds)
                                ->whereNotIn('name', $installedNames)
                                ->get()
                                ->mapWithKeys(fn ($mf) => [$mf->id => "[{$mf->category}] {$mf->name} ({$mf->pose_count} Pose)"]);
                        })
                        ->searchable()
                        ->required()
                        ->helperText('Hanya menampilkan desain frame yang belum pernah diimpor ke cafe Anda.'),
                ])
                ->action(function (array $data) {
                    $masterFrame = MasterFrame::find($data['master_frame_id']);
                    $cafe = auth()->user()?->cafe;

                    if ($masterFrame && $cafe) {
                        $result = $masterFrame->pushToCafe($cafe);
                        if ($result !== null) {
                            Notification::make()
                                ->title("Frame '{$masterFrame->name}' berhasil diimpor ke cafe Anda!")
                                ->success()
                                ->send();
                        } else {
                            Notification::make()
                                ->title("Frame '{$masterFrame->name}' sudah ada di cafe Anda.")
                                ->warning()
                                ->send();
                        }
                    }
                }),
            CreateAction::make()->label('Upload Frame Kustom Sendiri'),
        ];
    }
}
