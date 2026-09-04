param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        Write-Host '无法确定项目目录。请从项目根目录运行 connect-phone.bat。' -ForegroundColor Red
        exit 1
    }
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

function Stop-Connect {
    param([string]$Message)
    Write-Host ''
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Resolve-AdbPath {
    $command = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $localProperties = Join-Path $ProjectRoot 'android\local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $sdkLine = Get-Content -LiteralPath $localProperties | Where-Object {
            $_ -match '^sdk\.dir='
        } | Select-Object -First 1
        if ($null -ne $sdkLine) {
            $sdkPath = ($sdkLine -replace '^sdk\.dir=', '') -replace '\\\\', '\'
            $candidate = Join-Path $sdkPath 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidate = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    Stop-Connect '未找到 ADB。请先安装 Android SDK Platform-Tools。'
}

function Read-RequiredValue {
    param([string]$Prompt)
    while ($true) {
        $value = (Read-Host $Prompt).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
        Write-Host '此项不能为空，请重新输入。' -ForegroundColor Yellow
    }
}

function Read-Port {
    param([string]$Prompt)
    while ($true) {
        $value = Read-RequiredValue $Prompt
        $port = 0
        if ([int]::TryParse($value, [ref]$port) -and $port -ge 1 -and $port -le 65535) {
            return $port
        }
        Write-Host '端口必须是 1 到 65535 之间的数字。' -ForegroundColor Yellow
    }
}

$adbPath = Resolve-AdbPath

Write-Host 'Android 11+ 无线调试连接助手' -ForegroundColor Cyan
Write-Host ''
Write-Host '请在手机上打开：设置 → 开发者选项 → 无线调试。'
Write-Host '首次连接需要在手机上选择“使用配对码配对设备”。'
Write-Host ''

$pairAnswer = (Read-Host '这台电脑是否需要与手机进行首次配对？[Y/n]').Trim()
$hostAddress = Read-RequiredValue '请输入手机无线调试页面显示的 IP 地址（不含端口）'

if ($pairAnswer -notmatch '^(n|no)$') {
    $pairPort = Read-Port '请输入“使用配对码配对设备”弹窗中的配对端口'
    $pairCode = Read-RequiredValue '请输入手机显示的配对码'
    Write-Host ''
    Write-Host '正在配对……' -ForegroundColor Cyan
    $pairOutput = & $adbPath pair ('{0}:{1}' -f $hostAddress, $pairPort) $pairCode 2>&1
    $pairExitCode = $LASTEXITCODE
    $pairOutput | ForEach-Object { Write-Host $_ }
    if ($pairExitCode -ne 0 -or (($pairOutput | Out-String) -notmatch '(?i)Successfully paired')) {
        Stop-Connect @'
无线调试配对失败。

请确认 IP、配对端口和配对码来自手机当前显示的同一个配对弹窗，然后重试。
'@
    }
}

$connectPort = Read-Port '请输入无线调试主页面显示的连接端口'
Write-Host ''
Write-Host '正在连接手机……' -ForegroundColor Cyan
$connectOutput = & $adbPath connect ('{0}:{1}' -f $hostAddress, $connectPort) 2>&1
$connectExitCode = $LASTEXITCODE
$connectOutput | ForEach-Object { Write-Host $_ }
$connectText = $connectOutput | Out-String
if ($connectExitCode -ne 0 -or $connectText -match '(?i)failed|cannot|unable|refused') {
    Stop-Connect @'
无线调试连接失败。

请确认电脑与手机在同一网络、手机无线调试仍处于开启状态，并检查连接端口是否正确。
'@
}

Write-Host ''
Write-Host '当前 ADB 设备：' -ForegroundColor Cyan
& $adbPath devices -l
if ($LASTEXITCODE -ne 0) {
    Stop-Connect '连接命令完成，但无法读取 ADB 设备列表。'
}

Write-Host ''
Write-Host '无线调试连接完成。现在可以双击 deploy.bat 部署 APP。' -ForegroundColor Green
exit 0
