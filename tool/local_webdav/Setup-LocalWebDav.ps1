param(
    [string]$StateDirectory = (Join-Path $env:LOCALAPPDATA 'MyLedger-WebDAV'),
    [string]$PythonExecutable
)
$ErrorActionPreference = 'Stop'
$taskState = [IO.Path]::GetFullPath($StateDirectory)
Write-Host 'MyLedger WebDAV 设置向导：仅在用户运行本脚本时安装服务。'
Write-Host '现有部署、MyLedger账本、旧同步密码不会自动改动。'
if (Test-Path -LiteralPath (Join-Path $taskState 'config.json')) {
    Write-Host '此目录已有服务，将沿用原配置启动，不重新生成密码或证书。'
    & (Join-Path $PSScriptRoot 'Start-LocalWebDav.ps1') -StateDirectory $taskState
    Write-Host ('公共服务配置：' + (Join-Path $taskState 'service-setup.json'))
    return
}
if (-not $PythonExecutable) {
    $taskLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($taskLauncher) { $PythonExecutable = & $taskLauncher.Source -3 -c 'import sys; print(sys.executable)' }
    else {
        $taskCommand = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($taskCommand -and $taskCommand.Source -notlike '*WindowsApps*') { $PythonExecutable = $taskCommand.Source }
    }
}
if (-not $PythonExecutable -or -not (Test-Path -LiteralPath $PythonExecutable)) {
    throw '请先从 https://www.python.org/downloads/windows/ 安装Python3.12或以上，重新打开本向导。'
}
& $PythonExecutable -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,12) else 1)'
if ($LASTEXITCODE -ne 0) { throw '需要Python3.12或以上。' }
$taskAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' })
$taskAddresses | Select-Object InterfaceAlias, IPAddress | Format-Table | Out-Host
$taskHostIp = Read-Host '输入电脑连接Wi-Fi的IPv4地址（从上表选择）'
$taskPhoneIp = Read-Host '输入手机当前Wi-Fi的IPv4地址'
if ($taskHostIp -notin $taskAddresses.IPAddress) { throw '电脑地址必须是上表本机实际IPv4。' }
foreach ($taskAddress in @($taskHostIp, $taskPhoneIp)) {
    $taskParsed = [Net.IPAddress]::Parse($taskAddress)
    if ($taskParsed.AddressFamily -ne 'InterNetwork' -or $taskAddress -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)') {
        throw '仅支持同一局域网的私有IPv4地址。'
    }
}
if (Get-NetTCPConnection -State Listen -LocalAddress $taskHostIp -LocalPort 8443 -ErrorAction SilentlyContinue) {
    throw '该地址的8443端口已被使用，请保留现有服务，不重复部署。'
}
if (Test-Path -LiteralPath $taskState) {
    if (@(Get-ChildItem -LiteralPath $taskState -Force).Count -gt 0) { throw '目录内已有文件，请保留并检查，不自动覆盖。' }
} else { New-Item -ItemType Directory -Path $taskState | Out-Null }
# Restrict the state directory BEFORE creating passwords, keys, or data.
$taskSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$taskAcl = [Security.AccessControl.DirectorySecurity]::new()
$taskAcl.SetOwner($taskSid)
$taskAcl.SetAccessRuleProtection($true, $false)
foreach ($taskIdentity in @($taskSid, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
    $taskAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $taskIdentity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
}
Set-Acl -LiteralPath $taskState -AclObject $taskAcl
$taskSecret = Read-Host '设置20～128位半角专用密码（输入隐藏）' -AsSecureString
$taskConfirm = Read-Host '再次输入同一密码' -AsSecureString
$taskPointer = $taskConfirmPointer = [IntPtr]::Zero
try {
    $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecret)
    $taskConfirmPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskConfirm)
    $taskPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer)
    $taskRepeated = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskConfirmPointer)
    if ($taskPlain.Length -lt 20 -or $taskPlain.Length -gt 128 -or $taskPlain -match '[^\x21-\x7e]' -or $taskPlain -cne $taskRepeated) {
        throw '密码须20～128位半角非空白字符，且两次一致。未启动服务。'
    }
    & $PythonExecutable -m venv (Join-Path $taskState 'venv')
    if ($LASTEXITCODE -ne 0) { throw 'Python虚拟环境创建失败。' }
    $taskPython = Join-Path $taskState 'venv/Scripts/python.exe'
    & $taskPython -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot 'setup-requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw '服务依赖安装失败，请检查网络；保留目录排查后再继续。' }
    & $taskPython (Join-Path $PSScriptRoot 'provision.py') $taskState $taskHostIp $taskPhoneIp
    if ($LASTEXITCODE -ne 0) { throw 'HTTPS配置生成失败，请保留目录排查。' }
    $taskSecret | ConvertFrom-SecureString | Set-Content -LiteralPath (Join-Path $taskState 'password.dpapi') -Encoding ascii
} finally {
    if ($taskPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer) }
    if ($taskConfirmPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskConfirmPointer) }
    $taskSecret.Dispose(); $taskConfirm.Dispose()
    $taskPlain = $taskRepeated = $null
}
& (Join-Path $PSScriptRoot 'Start-LocalWebDav.ps1') -StateDirectory $taskState
Write-Host ('完成。公共服务配置：' + (Join-Path $taskState 'service-setup.json'))
Write-Host '用记事本打开此JSON，复制全文到两端MyLedger的“导入WebDAV服务配置”，核对上方指纹，单独输入刚才的密码。'
Write-Host '手机连接失败时按README中说明添加仅限该手机的防火墙规则；不要关闭整个防火墙。'
