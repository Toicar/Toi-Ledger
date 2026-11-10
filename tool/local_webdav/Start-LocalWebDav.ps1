param([Parameter(Mandatory)][string]$StateDirectory)
$ErrorActionPreference = 'Stop'
$taskState = (Resolve-Path -LiteralPath $StateDirectory).Path
$taskConfigPath = Join-Path $taskState 'config.json'
$taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
$taskPasswordFile = Join-Path $taskState 'password.dpapi'
if (Test-Path -LiteralPath $taskPasswordFile) {
    $taskSecret = (Get-Content -LiteralPath $taskPasswordFile -Raw).Trim() | ConvertTo-SecureString
    $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
    try { $taskPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer); $taskSecret.Dispose() }
} else {
    if ($taskConfig.credentialMode -eq 'dpapi') { throw '服务DPAPI密码文件缺失，请保留现有目录并恢复密码文件，不使用其他部署的密码。' }
    # Compatibility with the user's existing deployment; never rewrite this value.
    $taskPassword = [Environment]::GetEnvironmentVariable('MYLEDGER_LOCAL_DAV_PASSWORD', 'User')
}
if ([string]::IsNullOrEmpty($taskPassword) -or $taskPassword.Length -lt 20) {
    throw 'Set MYLEDGER_LOCAL_DAV_PASSWORD (20+ characters) in the user environment.'
}
$taskPidFile = Join-Path $taskState 'service.pid'
if (Test-Path -LiteralPath $taskPidFile) {
    $taskExistingPid = [int](Get-Content -LiteralPath $taskPidFile -Raw)
    if (Get-Process -Id $taskExistingPid -ErrorAction SilentlyContinue) {
        throw 'Recorded service process is still running; use Stop-LocalWebDav.ps1 first.'
    }
}
$taskPython = Join-Path $taskState 'venv\Scripts\python.exe'
$taskScript = Join-Path $PSScriptRoot 'server.py'
$taskPreviousPassword = $env:MYLEDGER_LOCAL_DAV_PASSWORD
try {
    $env:MYLEDGER_LOCAL_DAV_PASSWORD = $taskPassword
    $taskArguments = @('"' + $taskScript + '"', '"' + $taskConfigPath + '"')
    $taskServer = Start-Process -FilePath $taskPython -ArgumentList $taskArguments `
        -WorkingDirectory $taskState -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $taskState 'server.stdout.log') `
        -RedirectStandardError (Join-Path $taskState 'server.stderr.log')
} finally {
    $env:MYLEDGER_LOCAL_DAV_PASSWORD = $taskPreviousPassword
    $taskPassword = $null
}
Set-Content -LiteralPath $taskPidFile -Value $taskServer.Id -Encoding ascii
$taskReady = $false
for ($taskAttempt = 0; $taskAttempt -lt 30; $taskAttempt++) {
    if ($taskServer.HasExited) { throw 'WebDAV exited during startup; check the private service logs.' }
    $taskListener = Get-NetTCPConnection -State Listen -LocalAddress $taskConfig.host `
        -LocalPort $taskConfig.port -ErrorAction SilentlyContinue
    foreach ($taskCandidate in $taskListener) {
        $taskListeningProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($taskCandidate.OwningProcess)"
        # Windows venv redirectors spawn the base interpreter as a child.
        if (($taskListeningProcess.ProcessId -eq $taskServer.Id -or
             $taskListeningProcess.ParentProcessId -eq $taskServer.Id) -and
            $taskListeningProcess.CommandLine.Contains($taskScript) -and
            $taskListeningProcess.CommandLine.Contains($taskConfigPath)) {
            Set-Content -LiteralPath $taskPidFile -Value $taskListeningProcess.ProcessId -Encoding ascii
            $taskReady = $true
            break
        }
    }
    if ($taskReady) { break }
    Start-Sleep -Milliseconds 200
}
if (-not $taskReady) { throw 'WebDAV did not open its configured listening port.' }
Write-Output ('WebDAV running: https://{0}:{1}/dav/ (PID {2})' -f $taskConfig.host, $taskConfig.port, (Get-Content -LiteralPath $taskPidFile -Raw).Trim())
