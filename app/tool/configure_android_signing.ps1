param(
    [Parameter(Mandatory = $true)]
    [string]$Keystore,

    [Parameter(Mandatory = $true)]
    [string]$Alias,

    [string]$Repository = 'baicie/Universal-Reader',

    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

function Read-Secret {
    param(
        [string]$EnvironmentName,
        [string]$Prompt
    )
    $fromEnvironment = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if (-not [string]::IsNullOrEmpty($fromEnvironment)) {
        return $fromEnvironment
    }
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    return [Network.Credential]::new('', $secure).Password
}

function Set-GitHubSecret {
    param(
        [string]$Name,
        [string]$Value
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'gh'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        'secret',
        'set',
        $Name,
        '--repo',
        $Repository,
        '--app',
        'actions'
    )) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.Write($Value)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "Failed to set ${Name}: $stderr"
    }
    Write-Output "Configured GitHub secret: $Name"
}

$keystorePath = (Resolve-Path -LiteralPath $Keystore).Path
if (-not (Test-Path -LiteralPath $keystorePath -PathType Leaf)) {
    throw "Keystore does not exist: $keystorePath"
}

$storePassword = Read-Secret `
    -EnvironmentName 'ANDROID_KEYSTORE_PASSWORD' `
    -Prompt 'Keystore password'
$keyPassword = Read-Secret `
    -EnvironmentName 'ANDROID_KEY_PASSWORD' `
    -Prompt 'Private key password'

$temp = Join-Path ([IO.Path]::GetTempPath()) (
    'ur-signing-validate-' + [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $certificate = Join-Path $temp 'release.der'
    & keytool -list `
        -keystore $keystorePath `
        -storepass $storePassword `
        -alias $Alias | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Keystore password or alias is invalid.'
    }
    & keytool -exportcert `
        -keystore $keystorePath `
        -storepass $storePassword `
        -alias $Alias `
        -keypass $keyPassword `
        -file $certificate | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Private key password is invalid.'
    }
    $fingerprint = & openssl x509 `
        -inform DER `
        -in $certificate `
        -noout `
        -fingerprint `
        -sha256
    Write-Output "Certificate fingerprint: $fingerprint"
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($temp)
    $resolvedRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (
        $resolvedTemp.StartsWith($resolvedRoot) -and
        (Split-Path -Leaf $resolvedTemp).StartsWith('ur-signing-validate-') -and
        (Test-Path -LiteralPath $resolvedTemp)
    ) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}

if ($ValidateOnly) {
    Write-Output 'Android signing credentials validated; upload skipped.'
    exit 0
}

$keystoreBase64 = [Convert]::ToBase64String(
    [IO.File]::ReadAllBytes($keystorePath)
)
Set-GitHubSecret -Name 'ANDROID_KEYSTORE_BASE64' -Value $keystoreBase64
Set-GitHubSecret -Name 'ANDROID_KEYSTORE_PASSWORD' -Value $storePassword
Set-GitHubSecret -Name 'ANDROID_KEY_ALIAS' -Value $Alias
Set-GitHubSecret -Name 'ANDROID_KEY_PASSWORD' -Value $keyPassword
Write-Output 'Android release signing secrets configured.'
