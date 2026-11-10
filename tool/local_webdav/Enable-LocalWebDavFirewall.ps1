param([Parameter(Mandatory)][string]$StateDirectory)
$ErrorActionPreference = 'Stop'
$taskState = (Resolve-Path -LiteralPath $StateDirectory).Path
$taskConfig = Get-Content -LiteralPath (Join-Path $taskState 'config.json') -Raw | ConvertFrom-Json
if ($taskConfig.port -ne 8443) { throw 'This rule is limited to the configured MyLedger port 8443.' }
$taskHostIp = [System.Net.IPAddress]::Parse($taskConfig.host)
$taskPhoneIp = [System.Net.IPAddress]::Parse($taskConfig.phone)
if ($taskHostIp.AddressFamily -ne 'InterNetwork' -or $taskPhoneIp.AddressFamily -ne 'InterNetwork') {
    throw 'Expected explicit IPv4 addresses.'
}
$taskName = 'MyLedger-LAN-WebDAV-8443'
if (Get-NetFirewallRule -Name $taskName -ErrorAction SilentlyContinue) {
    throw 'A rule with this name already exists; inspect it before changing it.'
}
New-NetFirewallRule -Name $taskName -DisplayName 'MyLedger LAN HTTPS WebDAV (phone only)' `
    -Direction Inbound -Action Allow -Enabled True -Protocol TCP -LocalPort 8443 `
    -LocalAddress $taskConfig.host -RemoteAddress $taskConfig.phone `
    -Profile Any -EdgeTraversalPolicy Block | Out-Null
Write-Output 'Created a MyLedger-only TCP 8443 rule restricted to the configured phone address.'
