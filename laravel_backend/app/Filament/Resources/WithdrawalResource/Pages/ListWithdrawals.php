<?php

namespace App\Filament\Resources\WithdrawalResource\Pages;

use App\Filament\Resources\WithdrawalResource;
use App\Filament\Resources\WithdrawalResource\Widgets\WithdrawalOverviewWidget;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListWithdrawals extends ListRecords
{
    protected static string $resource = WithdrawalResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('Tarik Saldo'),
        ];
    }

    protected function getHeaderWidgets(): array
    {
        return [
            WithdrawalOverviewWidget::class,
        ];
    }
}
