# Temiz örnek: 5.1 uyumlu, BOM'lu. Lint bunu geçirmeli (tests/Unit/Lint.Tests.ps1).
param([string] $Name)

$display = $Name
if (-not $display) { $display = 'varsayılan' }
Write-Output $display
