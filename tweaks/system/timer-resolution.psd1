@{
    Id          = 'system.timer-resolution'
    Title       = 'Zamanlayıcı çözünürlüğü 0,5 ms'
    Description = 'FAI_TimerResolution servisini kurar (src/Native/TimerResolution.cs, açılışta otomatik başlar) ve sistem zamanlayıcısını 0,5 ms''ye (5000 × 100 ns) çeker. Windows 11''de bir sürecin istediği çözünürlük yalnız o süreci etkiler; sistem geneli etki için GlobalTimerResolutionRequests=1 gerekir (Session Manager\kernel). Pilde güç tüketimini biraz artırabilir. -Undo servisi kaldırır, değeri siler.'
    Category    = 'system'
    Risk        = 'Safe'
    Params      = @{ resolution = 5000 }
    Actions     = @(
        @{ Type = 'Registry'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'; Name = 'GlobalTimerResolutionRequests'; Value = 1; Kind = 'DWord' }
        @{ Type = 'TimerResolution'; Resolution = '{{resolution}}' }
    )
}
