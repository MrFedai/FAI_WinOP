# Bilerek hatalı örnek: ?? işleci PowerShell 5.1'de yok. Lint bunu yakalamalı (tests/Unit/Lint.Tests.ps1).
# Depo taramasında hariç (build/Lint.ps1: tests/Fixtures).
param([string] $Name)

$display = $Name ?? 'varsayılan'
Write-Output $display
