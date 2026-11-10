param([Parameter(Mandatory)][string]$StateDirectory)
$ErrorActionPreference = 'Stop'
$taskState = (Resolve-Path -LiteralPath $StateDirectory).Path
$taskPidFile = Join-Path $taskState 'service.pid'
if (-not (Test-Path -LiteralPath $taskPidFile)) { Write-Output 'No service PID recorded.'; return }
$taskServicePid = [int](Get-Content -LiteralPath $taskPidFile -Raw)
$taskServer = Get-CimInstance Win32_Process -Filter "ProcessId=$taskServicePid"
if ($taskServer) {
    $taskPython = Join-Path $taskState 'venv\Scripts\python.exe'
    $taskScript = Join-Path $PSScriptRoot 'server.py'
    $taskBasePythonLine = Get-Content -LiteralPath (Join-Path $taskState 'venv\pyvenv.cfg') |
        Where-Object { $_.StartsWith('executable = ') } | Select-Object -First 1
    if (-not $taskBasePythonLine) { throw 'Cannot identify the virtual environment base interpreter.' }
    $taskBasePython = $taskBasePythonLine.Substring('executable = '.Length)
    # A venv created from another venv records that intermediate launcher under
    # executable, while its running child uses the interpreter under home.
    $taskHomeLine = Get-Content -LiteralPath (Join-Path $taskState 'venv\pyvenv.cfg') |
        Where-Object { $_.StartsWith('home = ') } | Select-Object -First 1
    $taskInterpreters = @($taskPython, $taskBasePython)
    if ($taskHomeLine) { $taskInterpreters += Join-Path $taskHomeLine.Substring('home = '.Length) 'python.exe' }
    if ($taskServer.ExecutablePath -notin $taskInterpreters -or
        -not $taskServer.CommandLine.Contains($taskScript) -or
        -not $taskServer.CommandLine.Contains((Join-Path $taskState 'config.json'))) {
        throw 'Recorded PID does not match this WebDAV service; refusing to stop it.'
    }
    Stop-Process -Id $taskServicePid
    Wait-Process -Id $taskServicePid -Timeout 10 -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $taskPidFile
Write-Output 'Local WebDAV stopped; all service data retained.'
