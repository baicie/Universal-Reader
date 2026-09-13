param(
    [Parameter(Mandatory = $true)]
    [string]$Archive,

    [string]$Report = 'release-launch-windows.md',

    [string]$Executable = 'app.exe',

    [int]$WaitSeconds = 8
)

$ErrorActionPreference = 'Stop'
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$tempRoot = [IO.Path]::GetTempPath()
$temp = Join-Path $tempRoot ('ur-launch-' + [guid]::NewGuid().ToString('N'))

function Write-Report {
    param(
        [string]$Result,
        [string]$Detail
    )
    @(
        '# Release launch smoke',
        '',
        '- Platform: Windows x64',
        "- Archive: $archivePath",
        "- Executable: $Executable",
        "- Result: $Result",
        "- Detail: $Detail"
    ) | Set-Content -LiteralPath $Report -Encoding utf8
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $temp
    $candidate = Get-ChildItem -LiteralPath $temp -Recurse -Filter $Executable |
        Select-Object -First 1
    if ($null -eq $candidate) {
        throw "Archive does not contain $Executable"
    }

    $process = Start-Process `
        -FilePath $candidate.FullName `
        -WorkingDirectory $candidate.DirectoryName `
        -WindowStyle Hidden `
        -PassThru
    Start-Sleep -Seconds $WaitSeconds
    if ($process.HasExited) {
        throw "Process exited early with code $($process.ExitCode)"
    }

    $processId = $process.Id
    Stop-Process -Id $processId -Force
    $process.WaitForExit()
    Write-Report -Result 'PASS' -Detail "Process $processId stayed alive for $WaitSeconds seconds"
    Write-Output "Windows release launch smoke passed: $archivePath"
}
catch {
    Write-Report -Result 'FAIL' -Detail $_.Exception.Message
    throw
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($temp)
    $resolvedRoot = [IO.Path]::GetFullPath($tempRoot)
    if (
        $resolvedTemp.StartsWith($resolvedRoot) -and
        (Split-Path -Leaf $resolvedTemp).StartsWith('ur-launch-') -and
        (Test-Path -LiteralPath $resolvedTemp)
    ) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
