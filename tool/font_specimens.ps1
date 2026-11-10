$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskProject = Split-Path -Parent $PSScriptRoot
$taskOutput = Join-Path $taskProject 'reports/font-options'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskFonts = @('Georgia', 'Cambria', 'Palatino Linotype')
foreach ($taskName in $taskFonts) {
    $taskFamily = [Drawing.FontFamily]::new($taskName)
    if ($taskFamily.GetName(1033) -ne $taskName) { throw "Font fallback detected: $taskName" }
    $taskFamily.Dispose()
}
$taskBitmap = [Drawing.Bitmap]::new(1320, 730)
$taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
$taskGraphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$taskGraphics.Clear([Drawing.ColorTranslator]::FromHtml('#FAF8F3'))
function Write-SpecimenText([string]$Text, [string]$Family, [single]$Size, [single]$X, [single]$Y, [string]$Color = '#30302B') {
    $taskFont = [Drawing.Font]::new($Family, $Size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $taskBrush = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($Color))
    try { $taskGraphics.DrawString($Text, $taskFont, $taskBrush, [Drawing.PointF]::new($X, $Y), [Drawing.StringFormat]::GenericTypographic) }
    finally { $taskFont.Dispose(); $taskBrush.Dispose() }
}
try {
    Write-SpecimenText '英文与数字 · 三种系统字体' 'SimSun' 32 40 30
    Write-SpecimenText '同字号、同配色、本机字库渲染；中文保留微软雅黑 UI。此图仅供选择，尚未更改应用字体。' 'Microsoft YaHei UI' 15 40 85 '#77776B'
    for ($taskIndex = 0; $taskIndex -lt $taskFonts.Count; $taskIndex++) {
        $taskX = 40 + $taskIndex * 420
        $taskFamily = $taskFonts[$taskIndex]
        $taskFill = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#FFFEFA'))
        $taskLine = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#E4E0D7'), 1)
        try { $taskGraphics.FillRectangle($taskFill, $taskX, 130, 400, 520); $taskGraphics.DrawRectangle($taskLine, $taskX, 130, 400, 520) }
        finally { $taskFill.Dispose(); $taskLine.Dispose() }
        $taskLabel = @('A  Georgia · 原版风格', 'B  Cambria · 更规整', 'C  Palatino · 更舒展')[$taskIndex]
        Write-SpecimenText $taskLabel 'Microsoft YaHei UI' 18 ($taskX + 24) 153 '#B75B3E'
        Write-SpecimenText '本月结余' 'Microsoft YaHei UI' 14 ($taskX + 24) 211 '#77776B'
        Write-SpecimenText '¥14,546.50' $taskFamily 44 ($taskX + 24) 246
        Write-SpecimenText '收入' 'Microsoft YaHei UI' 15 ($taskX + 24) 319 '#77776B'
        Write-SpecimenText '¥18,000.00' $taskFamily 23 ($taskX + 86) 312
        Write-SpecimenText '餐饮美食' 'Microsoft YaHei UI' 16 ($taskX + 24) 373
        Write-SpecimenText 'Coffee & breakfast' $taskFamily 21 ($taskX + 24) 405
        Write-SpecimenText '0123456789' $taskFamily 30 ($taskX + 24) 459
        Write-SpecimenText '¥28.50    +12.8%' $taskFamily 24 ($taskX + 24) 511
        Write-SpecimenText '2026-11-10   08:30' $taskFamily 19 ($taskX + 24) 562
        Write-SpecimenText 'Aa Bb  ·  Ledger & life' $taskFamily 18 ($taskX + 24) 605 '#77776B'
    }
    Write-SpecimenText '三套字库本机均已安装。全部可零内嵌用于 Windows；Android 使用系统衬线回退，具体字形会随设备变化。' 'Microsoft YaHei UI' 14 40 682 '#77776B'
    $taskBitmap.Save((Join-Path $taskOutput 'latin-comparison.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally { $taskGraphics.Dispose(); $taskBitmap.Dispose() }
Write-Output (Join-Path $taskOutput 'latin-comparison.png')
