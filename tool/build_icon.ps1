param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskProject = Split-Path -Parent $PSScriptRoot
$taskBrand = Join-Path $taskProject 'assets/branding'
$taskSvgPath = Join-Path $taskBrand 'app-icon.svg'
[xml]$taskSvg = [IO.File]::ReadAllText($taskSvgPath)
$taskRect = $taskSvg.SelectSingleNode("//*[local-name()='rect']")
$taskPaths = $taskSvg.DocumentElement.SelectNodes("./*[local-name()='path']")
$taskClipPaths = @{}
foreach ($taskClip in $taskSvg.SelectNodes("//*[local-name()='clipPath']")) {
    $taskClipPaths[$taskClip.GetAttribute('id')] = $taskClip.SelectSingleNode("./*[local-name()='path']").GetAttribute('d')
}
$taskCulture = [Globalization.CultureInfo]::InvariantCulture

function Get-IconClip([System.Xml.XmlElement]$Element) {
    if (-not $Element.HasAttribute('clip-path')) { return $null }
    if ($Element.GetAttribute('clip-path') -notmatch '^url\(#([a-z-]+)\)$' -or -not $taskClipPaths.ContainsKey($Matches[1])) { throw 'Invalid icon clip reference' }
    return $taskClipPaths[$Matches[1]]
}

function Convert-IconPath([string]$Data) {
    if ($Data -match '[^MLCZ0-9.\s,-]') { throw 'Unsupported SVG command in icon source' }
    $taskTokens = [regex]::Matches($Data, '[MLCZ]|-?\d+(?:\.\d+)?') | ForEach-Object Value
    $taskPath = [Drawing.Drawing2D.GraphicsPath]::new()
    $taskIndex = 0
    $taskPoint = [Drawing.PointF]::new(0, 0)
    while ($taskIndex -lt $taskTokens.Count) {
        $taskCommand = $taskTokens[$taskIndex++]
        $taskCount = switch ($taskCommand) { 'M' { 2 } 'L' { 2 } 'C' { 6 } 'Z' { 0 } default { throw 'Invalid path command' } }
        $taskValues = @()
        for ($taskNumber = 0; $taskNumber -lt $taskCount; $taskNumber++) {
            if ($taskIndex -ge $taskTokens.Count) { throw 'Incomplete SVG path' }
            $taskValues += [single]::Parse($taskTokens[$taskIndex++], $taskCulture)
        }
        switch ($taskCommand) {
            'M' { $taskPath.StartFigure(); $taskPoint = [Drawing.PointF]::new($taskValues[0], $taskValues[1]) }
            'L' {
                $taskNext = [Drawing.PointF]::new($taskValues[0], $taskValues[1])
                $taskPath.AddLine($taskPoint, $taskNext)
                $taskPoint = $taskNext
            }
            'C' {
                $taskNext = [Drawing.PointF]::new($taskValues[4], $taskValues[5])
                $taskPath.AddBezier($taskPoint, [Drawing.PointF]::new($taskValues[0], $taskValues[1]), [Drawing.PointF]::new($taskValues[2], $taskValues[3]), $taskNext)
                $taskPoint = $taskNext
            }
            'Z' { $taskPath.CloseFigure() }
        }
    }
    return ,$taskPath
}

function New-IconBitmap([int]$Size, [bool]$Tile = $true) {
    # Supersampling preserves the simple silhouette at 16/20/24 px.
    $taskScale = [Math]::Max(1, [Math]::Ceiling(1024 / $Size))
    $taskCanvasSize = $Size * $taskScale
    $taskCanvas = [Drawing.Bitmap]::new($taskCanvasSize, $taskCanvasSize, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $taskGraphics = [Drawing.Graphics]::FromImage($taskCanvas)
    try {
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskGraphics.ScaleTransform($taskCanvasSize / 1024.0, $taskCanvasSize / 1024.0)
        if ($Tile) {
            $taskRadius = [single]::Parse($taskRect.GetAttribute('rx'), $taskCulture)
            $taskDiameter = 2 * $taskRadius
            $taskBackground = [Drawing.Drawing2D.GraphicsPath]::new()
            $taskBrush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($taskRect.GetAttribute('fill')))
            try {
                $taskBackground.AddArc(0, 0, $taskDiameter, $taskDiameter, 180, 90)
                $taskBackground.AddArc(1024 - $taskDiameter, 0, $taskDiameter, $taskDiameter, 270, 90)
                $taskBackground.AddArc(1024 - $taskDiameter, 1024 - $taskDiameter, $taskDiameter, $taskDiameter, 0, 90)
                $taskBackground.AddArc(0, 1024 - $taskDiameter, $taskDiameter, $taskDiameter, 90, 90)
                $taskBackground.CloseFigure()
                $taskGraphics.FillPath($taskBrush, $taskBackground)
            } finally { $taskBrush.Dispose(); $taskBackground.Dispose() }
        }
        foreach ($taskElement in $taskPaths) {
            if ($taskElement.HasAttribute('data-min-size') -and $Size -lt [int]$taskElement.GetAttribute('data-min-size')) { continue }
            $taskState = $taskGraphics.Save()
            $taskClipData = Get-IconClip $taskElement
            if ($taskClipData) {
                $taskClipPath = Convert-IconPath $taskClipData
                try { $taskGraphics.SetClip($taskClipPath, [Drawing.Drawing2D.CombineMode]::Intersect) }
                finally { $taskClipPath.Dispose() }
            }
            $taskPath = Convert-IconPath $taskElement.GetAttribute('d')
            $taskFill = if ($Tile) { $taskElement.GetAttribute('fill') } else { '#B75B3E' }
            $taskBrush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($taskFill))
            try { $taskGraphics.FillPath($taskBrush, $taskPath) } finally { $taskBrush.Dispose(); $taskPath.Dispose(); $taskGraphics.Restore($taskState) }
        }
    } finally { $taskGraphics.Dispose() }
    $taskBitmap = [Drawing.Bitmap]::new($Size, $Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $taskOutput = [Drawing.Graphics]::FromImage($taskBitmap)
    try {
        $taskOutput.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $taskOutput.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $taskOutput.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $taskOutput.DrawImage($taskCanvas, [Drawing.Rectangle]::new(0, 0, $Size, $Size), 0, 0, $taskCanvasSize, $taskCanvasSize, [Drawing.GraphicsUnit]::Pixel)
    } finally { $taskOutput.Dispose(); $taskCanvas.Dispose() }
    return ,$taskBitmap
}

function Save-IconPng([string]$Path, [int]$Size, [bool]$Tile = $true) {
    $taskBitmap = New-IconBitmap $Size $Tile
    try { $taskBitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png) } finally { $taskBitmap.Dispose() }
}

$taskIcoPath = Join-Path $taskProject 'windows/runner/resources/app_icon.ico'
$taskSizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
$taskDensities = @{mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192}
if (-not $VerifyOnly) {
    Save-IconPng (Join-Path $taskBrand 'app-icon-1024.png') 1024
    Save-IconPng (Join-Path $taskBrand 'app-icon-256.png') 256
    Save-IconPng (Join-Path $taskBrand 'app-mark-1024.png') 1024 $false
    foreach ($taskDensity in $taskDensities.GetEnumerator()) {
        Save-IconPng (Join-Path $taskProject "android/app/src/main/res/mipmap-$($taskDensity.Key)/ic_launcher.png") $taskDensity.Value
    }
    $taskFrames = @()
    foreach ($taskSize in $taskSizes) {
        $taskBitmap = New-IconBitmap $taskSize
        $taskStream = [IO.MemoryStream]::new()
        try { $taskBitmap.Save($taskStream, [Drawing.Imaging.ImageFormat]::Png); $taskFrames += ,$taskStream.ToArray() }
        finally { $taskStream.Dispose(); $taskBitmap.Dispose() }
    }
    $taskWriter = [IO.BinaryWriter]::new([IO.File]::Create($taskIcoPath))
    try {
        $taskWriter.Write([uint16]0); $taskWriter.Write([uint16]1); $taskWriter.Write([uint16]$taskSizes.Count)
        $taskOffset = 6 + 16 * $taskSizes.Count
        for ($taskIndex = 0; $taskIndex -lt $taskSizes.Count; $taskIndex++) {
            $taskDimension = if ($taskSizes[$taskIndex] -eq 256) { 0 } else { $taskSizes[$taskIndex] }
            $taskWriter.Write([byte]$taskDimension); $taskWriter.Write([byte]$taskDimension)
            $taskWriter.Write([byte]0); $taskWriter.Write([byte]0); $taskWriter.Write([uint16]1); $taskWriter.Write([uint16]32)
            $taskWriter.Write([uint32]$taskFrames[$taskIndex].Length); $taskWriter.Write([uint32]$taskOffset)
            $taskOffset += $taskFrames[$taskIndex].Length
        }
        foreach ($taskFrame in $taskFrames) { $taskWriter.Write([byte[]]$taskFrame) }
    } finally { $taskWriter.Dispose() }

    # Derive Android's vector from the same editable paths, inside its safe zone.
    $taskVectorPaths = foreach ($taskElement in $taskPaths) {
        $taskVectorPath = '    <path android:fillColor="' + $taskElement.GetAttribute('fill') + '" android:fillType="' + $(if ($taskElement.GetAttribute('fill-rule') -eq 'evenodd') { 'evenOdd' } else { 'nonZero' }) + '" android:pathData="' + $taskElement.GetAttribute('d') + '"/>'
        $taskClipData = Get-IconClip $taskElement
        if ($taskClipData) { $taskVectorPath = "    <group>`n      <clip-path android:fillType=`"evenOdd`" android:pathData=`"$taskClipData`"/>`n$taskVectorPath`n    </group>" }
        $taskVectorPath
    }
    $taskVector = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">' + "`n  <group android:pivotX=`"512`" android:pivotY=`"512`" android:scaleX=`"0.85`" android:scaleY=`"0.85`">`n" + ($taskVectorPaths -join "`n") + "`n  </group>`n</vector>`n"
    [IO.File]::WriteAllText((Join-Path $taskProject 'android/app/src/main/res/drawable/ic_launcher_foreground.xml'), $taskVector, [Text.UTF8Encoding]::new($false))
    $taskDefs = $taskSvg.SelectSingleNode("//*[local-name()='defs']")
    $taskMark = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">' + "`n" + $(if ($taskDefs) { $taskDefs.OuterXml + "`n" }) + (($taskPaths | ForEach-Object { '  <path fill="#B75B3E" fill-rule="' + $(if ($_.GetAttribute('fill-rule') -eq 'evenodd') { 'evenodd' } else { 'nonzero' }) + '"' + $(if ($_.HasAttribute('clip-path')) { ' clip-path="' + $_.GetAttribute('clip-path') + '"' }) + ' d="' + $_.GetAttribute('d') + '"/>' }) -join "`n") + "`n</svg>`n"
    [IO.File]::WriteAllText((Join-Path $taskBrand 'app-mark.svg'), $taskMark, [Text.UTF8Encoding]::new($false))

    # The in-app mark uses the same geometry as the launcher, without an SVG
    # runtime or a second hand-maintained drawing.
    function Convert-DartCommands([string]$Data) {
        foreach ($taskCommand in [regex]::Matches($Data, '([MLCZ])([^MLCZ]*)')) {
            $taskNumbers = [regex]::Matches($taskCommand.Groups[2].Value, '-?\d+(?:\.\d+)?') | ForEach-Object Value
            $taskMethod = switch ($taskCommand.Groups[1].Value) { 'M' { 'moveTo' } 'L' { 'lineTo' } 'C' { 'cubicTo' } 'Z' { 'close' } }
            '      ..' + $taskMethod + '(' + ($taskNumbers -join ', ') + ')'
        }
    }
    $taskDartDraws = foreach ($taskElement in $taskPaths) {
        $taskDartCommands = Convert-DartCommands $taskElement.GetAttribute('d')
        $taskFillRule = if ($taskElement.GetAttribute('fill-rule') -eq 'evenodd') { 'evenOdd' } else { 'nonZero' }
        $taskDraw = "    canvas.drawPath(Path()..fillType = PathFillType.$taskFillRule`n" + ($taskDartCommands -join "`n") + ", paint);"
        $taskClipData = Get-IconClip $taskElement
        if ($taskClipData) { $taskDraw = "    canvas.save();`n    canvas.clipPath(Path()..fillType = PathFillType.evenOdd`n" + ((Convert-DartCommands $taskClipData) -join "`n") + ");`n$taskDraw`n    canvas.restore();" }
        if ($taskElement.HasAttribute('data-min-size')) { $taskDraw = '    if (logicalSize >= ' + $taskElement.GetAttribute('data-min-size') + ") {`n" + $taskDraw + "`n    }" }
        $taskDraw
    }
    $taskDartSource = "// Generated by tool/build_icon.ps1 from assets/branding/app-icon.svg.`n// Edit the SVG source, then regenerate.`nimport 'dart:ui';`n`nabstract final class LedgerBrand {`n  static void paint(Canvas canvas, Color color, {double logicalSize = 1024}) {`n    final paint = Paint()..color = color;`n" + ($taskDartDraws -join "`n") + "`n  }`n}`n"
    [IO.File]::WriteAllText((Join-Path $taskProject 'lib/app/brand_mark.dart'), $taskDartSource, [Text.UTF8Encoding]::new($false))
}

# Decode every ICO frame and density image; no hashes or visual-match tests.
$taskReader = [IO.BinaryReader]::new([IO.File]::OpenRead($taskIcoPath))
try {
    if ($taskReader.ReadUInt16() -ne 0 -or $taskReader.ReadUInt16() -ne 1 -or $taskReader.ReadUInt16() -ne $taskSizes.Count) { throw 'Invalid ICO header' }
    for ($taskIndex = 0; $taskIndex -lt $taskSizes.Count; $taskIndex++) {
        $taskReader.BaseStream.Position = 6 + 16 * $taskIndex + 8
        $taskLength = $taskReader.ReadUInt32(); $taskOffset = $taskReader.ReadUInt32()
        $taskReader.BaseStream.Position = $taskOffset
        $taskStream = [IO.MemoryStream]::new($taskReader.ReadBytes($taskLength))
        $taskBitmap = [Drawing.Bitmap]::new($taskStream)
        try { if ($taskBitmap.Width -ne $taskSizes[$taskIndex] -or $taskBitmap.Height -ne $taskSizes[$taskIndex]) { throw 'ICO frame size mismatch' } }
        finally { $taskBitmap.Dispose(); $taskStream.Dispose() }
    }
} finally { $taskReader.Dispose() }
foreach ($taskDensity in $taskDensities.GetEnumerator()) {
    $taskBitmap = [Drawing.Bitmap]::new((Join-Path $taskProject "android/app/src/main/res/mipmap-$($taskDensity.Key)/ic_launcher.png"))
    try { if ($taskBitmap.Width -ne $taskDensity.Value -or $taskBitmap.Height -ne $taskDensity.Value) { throw 'Android density size mismatch' } }
    finally { $taskBitmap.Dispose() }
}
Write-Output 'Icon assets verified: 9 ICO frames, 5 Android densities, shared vector source.'
