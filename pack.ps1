$ErrorActionPreference = "Stop"
$pluginSrc = $PSScriptRoot
$distDir = Join-Path $pluginSrc "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$manifestRaw = [System.IO.File]::ReadAllText((Join-Path $pluginSrc "plugin.json"), [System.Text.UTF8Encoding]::new($false)).Trim()
$manifest = $manifestRaw | ConvertFrom-Json
$ver = $manifest.version
$zipOut = Join-Path $distDir "mooc-monitor-v$ver.zip"
$bundleOut = Join-Path $distDir "mooc-monitor-v$ver.ndplugin"

# 1. 生成 .zip 插件分发包
if (Test-Path $zipOut) { Remove-Item -Force $zipOut }
Compress-Archive -Path (Join-Path $pluginSrc "plugin.json"), (Join-Path $pluginSrc "ui") -DestinationPath $zipOut -Force

# 2. 生成 .ndplugin 单文件插件分发包（使用 StringBuilder 避免 Windows PowerShell 5.1 ConvertTo-Json 对大字符串的 O(n^2) 卡顿）
function ConvertTo-FastJsonString([string]$s) {
    $sb = [System.Text.StringBuilder]::new($s.Length + 64)
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        switch ($code) {
            34 { [void]$sb.Append('\"') }
            92 { [void]$sb.Append('\\') }
            8  { [void]$sb.Append('\b') }
            12 { [void]$sb.Append('\f') }
            10 { [void]$sb.Append('\n') }
            13 { [void]$sb.Append('\r') }
            9  { [void]$sb.Append('\t') }
            default {
                if ($code -lt 32) {
                    [void]$sb.AppendFormat('\u{0:x4}', $code)
                } else {
                    [void]$sb.Append($ch)
                }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

$html = [System.IO.File]::ReadAllText((Join-Path $pluginSrc "ui\index.html"), [System.Text.UTF8Encoding]::new($false))
$htmlJson = ConvertTo-FastJsonString $html
$bundleJson = "{`n  `"manifest`": $manifestRaw,`n  `"files`": {`n    `"ui/index.html`": $htmlJson`n  }`n}`n"
[System.IO.File]::WriteAllText($bundleOut, $bundleJson, [System.Text.UTF8Encoding]::new($false))

Write-Host "Packed zip:    $zipOut"
Write-Host "Packed bundle: $bundleOut"
