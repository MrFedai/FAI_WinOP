# Günlükçü: bellekte tutar, isteğe bağlı dosyaya yazar, isteğe bağlı konsola basar.
class Logger {
    [string] $Path = ''
    [bool] $Quiet = $true
    [System.Collections.ArrayList] $Entries = (New-Object System.Collections.ArrayList)

    Logger() { }

    Logger([string] $Path, [bool] $Quiet) {
        $this.Path = $Path
        $this.Quiet = $Quiet
    }

    [void] Write([string] $Level, [string] $Message) {
        $stamp = (Get-Date).ToString('s')
        $line = '{0} [{1}] {2}' -f $stamp, $Level, $Message
        [void]$this.Entries.Add([pscustomobject]@{ Time = $stamp; Level = $Level; Message = $Message })
        $this.AppendFile($line + [Environment]::NewLine)
        if (-not $this.Quiet) {
            $color = 'Gray'
            if ($Level -eq 'WARN') { $color = 'Yellow' }
            if ($Level -eq 'ERROR') { $color = 'Red' }
            Write-Host $line -ForegroundColor $color
        }
    }

    # Çok satırlı blok (ör. rapor): zaman damgasız, yalnız dosyaya; bellekte ve konsolda yok.
    [void] Block([string] $Text) {
        $this.AppendFile([Environment]::NewLine + $Text)
    }

    hidden [void] AppendFile([string] $Text) {
        if (-not $this.Path) { return }
        $dir = Split-Path -Parent $this.Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::AppendAllText($this.Path, $Text, (New-Object System.Text.UTF8Encoding($true)))
    }

    [void] Info([string] $Message) { $this.Write('INFO', $Message) }
    [void] Warn([string] $Message) { $this.Write('WARN', $Message) }
    [void] Error([string] $Message) { $this.Write('ERROR', $Message) }
    [void] Debug([string] $Message) { $this.Write('DEBUG', $Message) }

    # Belirli düzeydeki girdi sayısı (testler ve rapor için).
    [int] Count([string] $Level) {
        $n = 0
        foreach ($e in $this.Entries) { if ($e.Level -eq $Level) { $n++ } }
        return $n
    }
}
