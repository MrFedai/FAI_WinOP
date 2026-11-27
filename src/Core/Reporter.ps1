# Rapor: motorun her tweak için ne yaptığını (ya da yapacağını) toplar ve okunabilir metne çevirir.
#
# Durumlar:
#   Applied   uygulandı          Planned  önizleme (-DryRun): uygulanacak
#   UpToDate  zaten uygun        Skipped  atlandı (koşul / risk / onay)
#   Failed    hata               Reverted geri alındı (-Undo)

class ReportItem {
    [string] $TweakId
    [string] $Title
    [string] $Status
    [string] $Reason
    [string[]] $Lines

    ReportItem([string] $TweakId, [string] $Title, [string] $Status, [string] $Reason, [string[]] $Lines) {
        $this.TweakId = $TweakId
        $this.Title = $Title
        $this.Status = $Status
        $this.Reason = $Reason
        $this.Lines = $Lines
    }
}

class Reporter {
    [System.Collections.ArrayList] $Items = (New-Object System.Collections.ArrayList)
    [string] $Heading = 'Rapor'

    Reporter() { }

    [ReportItem] Add([string] $TweakId, [string] $Title, [string] $Status, [string] $Reason, [string[]] $Lines) {
        $item = [ReportItem]::new($TweakId, $Title, $Status, $Reason, $Lines)
        [void]$this.Items.Add($item)
        return $item
    }

    [int] Count([string] $Status) {
        $n = 0
        foreach ($i in $this.Items) { if ($i.Status -eq $Status) { $n++ } }
        return $n
    }

    [ReportItem] Find([string] $TweakId) {
        foreach ($i in $this.Items) { if ($i.TweakId -eq $TweakId) { return $i } }
        return $null
    }

    [bool] HasFailures() { return ($this.Count('Failed') -gt 0) }

    static [string] StatusLabel([string] $Status) {
        $label = $Status
        switch ($Status) {
            'Applied' { $label = 'APPLIED' }
            'Planned' { $label = 'PREVIEW' }
            'UpToDate' { $label = 'ALREADY SET' }
            'Skipped' { $label = 'SKIPPED' }
            'Failed' { $label = 'ERROR' }
            'Reverted' { $label = 'REVERTED' }
        }
        return $label
    }

    [string] Render() {
        $nl = [Environment]::NewLine
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append($this.Heading + $nl)
        foreach ($i in $this.Items) {
            $line = '  [{0}] {1} — {2}' -f [Reporter]::StatusLabel($i.Status), $i.TweakId, $i.Title
            if ($i.Reason) { $line += ' (' + $i.Reason + ')' }
            [void]$sb.Append($line + $nl)
            foreach ($l in $i.Lines) { [void]$sb.Append('      · ' + $l + $nl) }
        }
        [void]$sb.Append($this.Summary() + $nl)
        return $sb.ToString()
    }

    [string] Summary() {
        $parts = New-Object 'System.Collections.Generic.List[string]'
        foreach ($s in @('Applied', 'Planned', 'UpToDate', 'Skipped', 'Failed', 'Reverted')) {
            $n = $this.Count($s)
            if ($n -gt 0) { $parts.Add(('{0}: {1}' -f [Reporter]::StatusLabel($s), $n)) }
        }
        if ($parts.Count -eq 0) { return 'Summary: no entries' }
        return 'Summary: ' + ($parts -join ' · ')
    }
}
