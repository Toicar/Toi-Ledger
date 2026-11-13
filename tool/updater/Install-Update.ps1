param(
    [Parameter(Mandatory)][string]$Archive,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$InstallDirectory,
    [Parameter(Mandatory)][int]$AppPid,
    [switch]$NonInteractive
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName PresentationFramework
$taskInstall = (Resolve-Path -LiteralPath $InstallDirectory).Path.TrimEnd('\')
$taskArchive = (Resolve-Path -LiteralPath $Archive).Path
$taskWork = Join-Path ([IO.Path]::GetTempPath()) ('myledger-update-' + [guid]::NewGuid().ToString('N'))
$taskStage = Join-Path $taskWork 'stage'
$taskBackup = Join-Path $taskWork 'backup'
$taskWritten = [Collections.Generic.List[string]]::new()
$taskExisted = @{}
try {
    $taskHasher = [Security.Cryptography.SHA256]::Create()
    $taskStream = [IO.File]::OpenRead($taskArchive)
    try { $taskHash = [BitConverter]::ToString($taskHasher.ComputeHash($taskStream)).Replace('-', '') }
    finally { $taskStream.Dispose(); $taskHasher.Dispose() }
    if ($taskHash -ine $ExpectedSha256) { throw 'The update package checksum does not match.' }
    [IO.Directory]::CreateDirectory($taskStage) | Out-Null
    [IO.Directory]::CreateDirectory($taskBackup) | Out-Null
    $taskZip = [IO.Compression.ZipFile]::OpenRead($taskArchive)
    try {
        if ($taskZip.Entries.Count -gt 10000) { throw 'The update contains too many files.' }
        $taskNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $taskTotal = 0L
        foreach ($entry in $taskZip.Entries) {
            $name = $entry.FullName.Replace('/', '\')
            if ($name.EndsWith('\')) { continue }
            if ($name -match '(^|\\)(\.\.?|[^\\]*:)(\\|$)' -or $name.StartsWith('\') -or $name.Contains([char]0)) { throw 'Unsafe update path.' }
            if (-not ($name -match '^(data|webdav-setup|updater)\\' -or $name -match '^(my_ledger\.exe|app_icon\.ico|native_assets\.json|[a-zA-Z0-9_.-]+\.dll)$')) { throw 'Unexpected update file.' }
            if (-not $taskNames.Add($name)) { throw 'Duplicate update path.' }
            if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Symbolic links are not supported.' }
            $taskTotal += $entry.Length
            if ($taskTotal -gt 536870912 -or $entry.Length -gt 268435456) { throw 'The update exceeds the size limit.' }
            $output = [IO.Path]::GetFullPath((Join-Path $taskStage $name))
            if (-not $output.StartsWith($taskStage + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe update path.' }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $output, $false)
        }
        if (-not $taskNames.Contains('my_ledger.exe') -or -not $taskNames.Contains('data\app.so')) { throw 'Incomplete Windows update.' }
    } finally { $taskZip.Dispose() }
    $taskProcess = Get-Process -Id $AppPid -ErrorAction SilentlyContinue
    if ($taskProcess) { $taskProcess | Wait-Process -Timeout 60 }
    foreach ($name in $taskNames) {
        $target = [IO.Path]::GetFullPath((Join-Path $taskInstall $name))
        if (-not $target.StartsWith($taskInstall + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe destination path.' }
        $parent = [IO.Path]::GetDirectoryName($target)
        $check = $parent
        while ($check.StartsWith($taskInstall, [StringComparison]::OrdinalIgnoreCase)) {
            if ((Test-Path -LiteralPath $check) -and ((Get-Item -LiteralPath $check -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked installation directories are not supported.' }
            if ($check -eq $taskInstall) { break }
            $check = [IO.Path]::GetDirectoryName($check)
        }
        $backup = Join-Path $taskBackup $name
        if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'An update file conflicts with an existing directory.' }
        $taskExisted[$name] = Test-Path -LiteralPath $target -PathType Leaf
        if ($taskExisted[$name]) {
            if ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked destination files are not supported.' }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup)) | Out-Null
            Copy-Item -LiteralPath $target -Destination $backup -Force
        }
        [IO.Directory]::CreateDirectory($parent) | Out-Null
        $taskWritten.Add($name)
        Copy-Item -LiteralPath (Join-Path $taskStage $name) -Destination $target -Force
    }
    Start-Process -FilePath (Join-Path $taskInstall 'my_ledger.exe') -WorkingDirectory $taskInstall
} catch {
    $taskFailure = $_.Exception.Message
    $taskRollbackFailed = $false
    foreach ($name in $taskWritten) {
        try {
            $target = Join-Path $taskInstall $name
            if ($taskExisted[$name]) { Copy-Item -LiteralPath (Join-Path $taskBackup $name) -Destination $target -Force }
            elseif (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
        } catch { $taskRollbackFailed = $true }
    }
    $detail = if ($taskRollbackFailed) { "Rollback incomplete. Backup: $taskBackup" } else { 'Existing application files were restored.' }
    if ($NonInteractive) { [Console]::Error.WriteLine("Update failed: $taskFailure`n$detail`nFiles attempted: $($taskWritten.Count)") }
    else { [System.Windows.MessageBox]::Show("Update failed: $taskFailure`n$detail", 'MyLedger update') | Out-Null }
    exit 1
}
