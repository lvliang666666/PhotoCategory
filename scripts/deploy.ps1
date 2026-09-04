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
        Write-Host '无法确定项目目录。请从项目根目录运行 deploy.bat。' -ForegroundColor Red
        exit 1
    }
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

# Values below are taken from this project's real Gradle and manifest files.
$GradleModule = 'app'
$GradleTask = ':app:assembleStandardDebug'
$BuildVariant = 'standardDebug'
$ApplicationId = 'com.photostorer.photo_storer'
$LauncherActivity = 'com.photostorer.photo_storer.MainActivity'

function Stop-Deploy {
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

    Stop-Deploy @'
未找到 ADB。

请确认 Android SDK Platform-Tools 已安装，或将 adb.exe 所在目录加入 PATH。
'@
}

function Resolve-GradleUserHome {
    # Prefer the cache that was used to build this project successfully. The
    # environment variables keep the script portable if the project is moved.
    $candidates = @(
        $env:PHOTO_STORER_GRADLE_HOME,
        $env:GRADLE_USER_HOME,
        'C:\Users\35226\Documents\Codex\2026-08-10\new-chat\work\gradle-home',
        (Join-Path $env:USERPROFILE '.gradle')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($candidate in $candidates) {
        $moduleCache = Join-Path $candidate 'caches\modules-2'
        if (Test-Path -LiteralPath $moduleCache) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }

    # A fresh machine can still use the normal Gradle cache; the Wrapper will
    # download missing files through the repositories configured by the project.
    return (Join-Path $env:USERPROFILE '.gradle')
}

function Resolve-GradleRunner {
    param([string]$WrapperPath)

    # Gradle's executable distribution and dependency cache may live in
    # different Gradle homes on this workstation. Reuse the installed 8.13
    # executable when available, while still running inside this project.
    $distributionRoot = Join-Path $env:USERPROFILE '.gradle\wrapper\dists\gradle-8.13-bin'
    if (Test-Path -LiteralPath $distributionRoot) {
        $installed = Get-ChildItem -LiteralPath $distributionRoot -Filter 'gradle.bat' `
            -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*\gradle-8.13\bin\gradle.bat' } |
            Select-Object -First 1
        if ($null -ne $installed) {
            return $installed.FullName
        }
    }
    return $WrapperPath
}

function Get-AdbDevices {
    param([string]$AdbPath)

    $raw = & $AdbPath devices -l 2>&1
    if ($LASTEXITCODE -ne 0) {
        $raw | ForEach-Object { Write-Host $_ }
        Stop-Deploy 'ADB 无法列出设备，请检查 Android SDK Platform-Tools。'
    }

    $result = @()
    foreach ($line in $raw) {
        $text = [string]$line
        if ($text -match '^([^\s]+)\s+([^\s]+)(?:\s+(.*))?$' -and
            $Matches[1] -ne 'List') {
            $result += [PSCustomObject]@{
                Serial = $Matches[1]
                State = $Matches[2]
                Detail = if ($Matches.Count -gt 3) { $Matches[3] } else { '' }
            }
        }
    }
    return @($result)
}

function Select-TargetDevice {
    param(
        [string]$AdbPath,
        [object[]]$Devices
    )

    $online = @($Devices | Where-Object { $_.State -eq 'device' })
    if ($online.Count -eq 0) {
        if ($Devices.Count -gt 0) {
            Write-Host 'ADB 检测到了设备，但设备当前不可用：' -ForegroundColor Yellow
            foreach ($device in $Devices) {
                Write-Host ('  {0}  状态：{1}' -f $device.Serial, $device.State)
            }
            Write-Host ''
            Write-Host '如果状态是 unauthorized，请在手机上确认 USB 调试授权。'
            Write-Host '如果状态是 offline，请重新连接 USB 或无线调试。'
            exit 1
        }

        Stop-Deploy @'
未检测到 Android 设备。

请确认：
1. 手机已开启开发者选项
2. 已开启 USB 调试或无线调试
3. 手机已经与电脑配对
4. adb devices 可以识别设备

未开始构建，也没有执行任何安装操作。
'@
    }

    if ($online.Count -eq 1) {
        return $online[0]
    }

    Write-Host '检测到多台 Android 设备，请选择部署目标：' -ForegroundColor Cyan
    for ($index = 0; $index -lt $online.Count; $index++) {
        Write-Host ('  [{0}] {1} {2}' -f ($index + 1), $online[$index].Serial, $online[$index].Detail)
    }

    while ($true) {
        $answer = Read-Host ('请输入 1-{0}' -f $online.Count)
        $selection = 0
        if ([int]::TryParse($answer, [ref]$selection) -and
            $selection -ge 1 -and $selection -le $online.Count) {
            return $online[$selection - 1]
        }
        Write-Host '输入无效，请重新选择。' -ForegroundColor Yellow
    }
}

function Find-BuiltApk {
    $variantOutput = Join-Path $ProjectRoot 'build\app\outputs\apk\standard\debug'
    $metadataPath = Join-Path $variantOutput 'output-metadata.json'

    if (Test-Path -LiteralPath $metadataPath) {
        try {
            $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            foreach ($element in @($metadata.elements)) {
                if (-not [string]::IsNullOrWhiteSpace($element.outputFile)) {
                    $candidate = Join-Path $variantOutput $element.outputFile
                    if (Test-Path -LiteralPath $candidate) {
                        return (Get-Item -LiteralPath $candidate).FullName
                    }
                }
            }
        } catch {
            Write-Host '提示：无法读取 output-metadata.json，将搜索 Debug APK。' -ForegroundColor Yellow
        }
    }

    $searchRoots = @(
        $variantOutput,
        (Join-Path $ProjectRoot 'build\app\outputs\flutter-apk')
    )
    $candidates = @()
    foreach ($root in $searchRoots) {
        if (Test-Path -LiteralPath $root) {
            $candidates += Get-ChildItem -LiteralPath $root -Filter '*.apk' -File -Recurse |
                Where-Object {
                    $_.Name -notmatch 'androidTest|unaligned' -and
                    ($_.DirectoryName -like '*\standard\debug' -or
                     $_.Name -match 'standard.*debug|debug.*standard')
                }
        }
    }

    $latest = $candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        return $null
    }
    return $latest.FullName
}

Write-Host '正在检查 ADB 和 Android 设备……' -ForegroundColor Cyan
$adbPath = Resolve-AdbPath
$devices = Get-AdbDevices -AdbPath $adbPath
$targetDevice = Select-TargetDevice -AdbPath $adbPath -Devices $devices
Write-Host ('目标设备：{0}' -f $targetDevice.Serial) -ForegroundColor Green

$gradleWrapper = Join-Path $ProjectRoot 'android\gradlew.bat'
$androidDirectory = Join-Path $ProjectRoot 'android'
if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    Stop-Deploy ('未找到 Gradle Wrapper：{0}' -f $gradleWrapper)
}

if ([string]::IsNullOrWhiteSpace($env:PUB_HOSTED_URL)) {
    $env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
}
if ([string]::IsNullOrWhiteSpace($env:FLUTTER_STORAGE_BASE_URL)) {
    $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
}
$env:GRADLE_USER_HOME = Resolve-GradleUserHome
Write-Host ('Gradle 缓存：{0}' -f $env:GRADLE_USER_HOME)
$gradleRunner = Resolve-GradleRunner -WrapperPath $gradleWrapper
Write-Host ('Gradle 命令：{0}' -f $gradleRunner)

Write-Host ''
Write-Host ('正在构建 {0}（{1}）……' -f $BuildVariant, $GradleTask) -ForegroundColor Cyan
Push-Location $androidDirectory
try {
    & $gradleRunner $GradleTask '--console=plain'
    $buildExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($buildExitCode -ne 0) {
    Stop-Deploy @'
APK 构建失败，请查看上方 Gradle 错误。

已停止部署，不会安装已有的旧 APK。
'@
}

$apkPath = Find-BuiltApk
if ([string]::IsNullOrWhiteSpace($apkPath)) {
    Stop-Deploy @'
未找到构建生成的 APK。

已停止部署，不会安装其他 APK。
'@
}
Write-Host ('构建产物：{0}' -f $apkPath) -ForegroundColor Green

Write-Host ''
Write-Host '正在通过 ADB 覆盖安装（保留应用数据）……' -ForegroundColor Cyan
$installOutput = & $adbPath -s $targetDevice.Serial install -r $apkPath 2>&1
$installExitCode = $LASTEXITCODE
$installOutput | ForEach-Object { Write-Host $_ }
$installText = ($installOutput | Out-String)

if ($installExitCode -ne 0 -or $installText -notmatch '(?m)^Success\s*$') {
    if ($installText -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|UPDATE_INCOMPATIBLE|signatures do not match') {
        Stop-Deploy @'
新旧 APK 签名不一致，不能安全覆盖。

为了保护数据，本脚本不会自动卸载旧 APP，也不会清除应用数据。
请保留手机上的旧 APP，并先确认旧版本所用签名。
'@
    }
    Stop-Deploy @'
APK 安装失败，ADB 原始错误已显示在上方。

为了保护数据，本脚本不会自动卸载 APP，也不会清除应用数据。
'@
}

Write-Host ''
Write-Host '正在解析并启动 APP……' -ForegroundColor Cyan
$resolveOutput = & $adbPath -s $targetDevice.Serial shell cmd package resolve-activity --brief `
    -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $ApplicationId 2>&1
$component = $null
foreach ($line in @($resolveOutput)) {
    $candidate = ([string]$line).Trim()
    if ($candidate -match '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$') {
        $component = $candidate
        break
    }
}
if ([string]::IsNullOrWhiteSpace($component)) {
    $component = '{0}/{1}' -f $ApplicationId, $LauncherActivity
}

$startOutput = & $adbPath -s $targetDevice.Serial shell am start -n $component 2>&1
$startExitCode = $LASTEXITCODE
$startOutput | ForEach-Object { Write-Host $_ }
if ($startExitCode -ne 0 -or (($startOutput | Out-String) -match '(?i)Error:|Exception')) {
    Stop-Deploy @'
APP 已覆盖安装，但自动启动失败。

应用数据仍然保留，请在手机桌面手动打开“相册分类”。
'@
}

Write-Host ''
Write-Host '==================================' -ForegroundColor Green
Write-Host ''
Write-Host 'APP 部署成功' -ForegroundColor Green
Write-Host ''
Write-Host ('设备：{0}' -f $targetDevice.Serial)
Write-Host '版本：Standard Debug'
Write-Host '安装方式：ADB 覆盖升级（install -r）'
Write-Host '用户数据：保留'
Write-Host ('应用：{0}' -f $ApplicationId)
Write-Host 'APP 已自动启动'
Write-Host ''
Write-Host '==================================' -ForegroundColor Green
exit 0
