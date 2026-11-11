param([Parameter(Mandatory)][string]$StateDirectory)
$ErrorActionPreference = 'Stop'
$taskState = (Resolve-Path -LiteralPath $StateDirectory).Path
$taskConfigPath = Join-Path $taskState 'config.json'
$taskMutex = [Threading.Mutex]::new($false, 'Local\MyLedger-WebDAV-' + [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($taskState.ToLowerInvariant()))).Replace('/', '_').Replace('+', '-'))
$taskLocked = $false
try {
    try { $taskLocked = $taskMutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $taskLocked = $true }
    if (-not $taskLocked) { throw 'Timed out waiting for WebDAV startup.' }
    $taskPidFile = Join-Path $taskState 'service.pid'
    if (Test-Path -LiteralPath $taskPidFile) {
        $taskExistingPid = 0
        if ([int]::TryParse((Get-Content -LiteralPath $taskPidFile -Raw).Trim(), [ref]$taskExistingPid)) {
            $taskProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$taskExistingPid"
            if ($taskProcess) {
                if ($taskProcess.CommandLine -and $taskProcess.CommandLine.Contains($taskConfigPath) -and
                    $taskProcess.CommandLine -match '(?:^|[\\/])server\.py(?:"|\s)') { return }
                throw 'Recorded service PID belongs to another process.'
            }
        }
    }
    & (Join-Path $PSScriptRoot 'Start-LocalWebDav.ps1') -StateDirectory $taskState
} finally {
    if ($taskLocked) { $taskMutex.ReleaseMutex() }
    $taskMutex.Dispose()
}
