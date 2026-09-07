$lines = Get-Content D:\workspace\git-code\Universal-Reader\app\coverage\lcov.info
$rows = New-Object System.Collections.Generic.List[object]
$file = $null
$lf = 0
foreach ($l in $lines) {
    if ($l -like 'SF:*') { $file = $l.Substring(3) }
    elseif ($l -like 'LF:*') { $lf = [int]$l.Substring(3) }
    elseif ($l -like 'LH:*') {
        $lh = [int]$l.Substring(3)
        if ($file -and $lf -gt 0) {
            $pct = [math]::Round(($lh * 100.0 / $lf), 1)
            $rows.Add([pscustomobject]@{ File = $file; LF = $lf; LH = $lh; Pct = $pct })
            $file = $null; $lf = 0
        }
    }
}
$rows |
    Where-Object { $_.File -notmatch '[\\/]test[\\/]' -and $_.File -notmatch 'generated' } |
    Sort-Object Pct |
    ForEach-Object { '{0,6} % {1,5}/{2,-5}  {3}' -f $_.Pct, $_.LH, $_.LF, $_.File }
