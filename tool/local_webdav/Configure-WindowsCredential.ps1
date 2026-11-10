param(
    [Parameter(Mandatory)][string]$StateDirectory,
    [Parameter(Mandatory)][string]$AppSupportDirectory
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name my_ledger -ErrorAction SilentlyContinue) {
    throw 'Close MyLedger before configuring its stored credential.'
}
$taskState = (Resolve-Path -LiteralPath $StateDirectory).Path
$taskSupport = (Resolve-Path -LiteralPath $AppSupportDirectory).Path
$taskConfig = Get-Content -LiteralPath (Join-Path $taskState 'config.json') -Raw | ConvertFrom-Json
$taskPassword = [Environment]::GetEnvironmentVariable('MYLEDGER_LOCAL_DAV_PASSWORD', 'User')
if ([string]::IsNullOrEmpty($taskPassword) -or $taskPassword.Length -lt 20 -or
    $taskPassword.Contains("`n") -or $taskPassword.Contains("`r")) {
    throw 'Set a 20+ character dedicated password without line breaks in the user environment.'
}
$taskCredentialFile = Join-Path $taskSupport 'flutter_secure_storage.dat'
$taskMap = @{}
if (Test-Path -LiteralPath $taskCredentialFile) {
    $taskEncrypted = [System.IO.File]::ReadAllBytes($taskCredentialFile)
    $taskExisting = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $taskEncrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $taskMap = [System.Text.Encoding]::UTF8.GetString($taskExisting) | ConvertFrom-Json -AsHashtable
    $taskBackup = Join-Path $taskState 'backups\windows-credentials-before-webdav.dat'
    if (-not (Test-Path -LiteralPath $taskBackup)) {
        [System.IO.File]::Copy($taskCredentialFile, $taskBackup, $false)
    }
    [Array]::Clear($taskExisting, 0, $taskExisting.Length)
}
$taskDav = @{
    endpoint = ('https://{0}:{1}/dav/' -f $taskConfig.host, $taskConfig.port)
    username = $taskConfig.username
    password = $taskPassword
} | ConvertTo-Json -Compress
$taskMap['myledger.webdav.v1'] = $taskDav
$taskPlain = [System.Text.Encoding]::UTF8.GetBytes(($taskMap | ConvertTo-Json -Compress))
try {
    # This matches flutter_secure_storage_windows 3.1.2: UTF-8 JSON, current-user DPAPI, no entropy.
    $taskProtected = [System.Security.Cryptography.ProtectedData]::Protect(
        $taskPlain, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $taskTemp = $taskCredentialFile + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [System.IO.File]::WriteAllBytes($taskTemp, $taskProtected)
    Move-Item -LiteralPath $taskTemp -Destination $taskCredentialFile -Force
} finally {
    [Array]::Clear($taskPlain, 0, $taskPlain.Length)
    $taskPassword = $null
    $taskDav = $null
    $taskMap = $null
}
Write-Output 'WebDAV credential saved in MyLedger current-user DPAPI storage.'
