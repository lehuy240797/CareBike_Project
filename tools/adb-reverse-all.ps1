param(
  [int[]]$Ports = @(8080, 8000)
)

$ErrorActionPreference = "Stop"

function Resolve-Adb {
  $fromPath = Get-Command adb -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  $candidates = @(
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  throw "adb.exe was not found. Add Android SDK platform-tools to PATH or install Android Studio SDK tools."
}

$adb = Resolve-Adb
Write-Host "Using adb: $adb"

& $adb start-server | Out-Null

$devices = @(& $adb devices |
  Select-String "`tdevice$" |
  ForEach-Object { ($_ -split "`t")[0] })

if (-not $devices -or $devices.Count -eq 0) {
  Write-Host "No Android devices are connected. Open an emulator or plug in a USB device, then run this script again."
  exit 0
}

foreach ($device in $devices) {
  foreach ($port in $Ports) {
    & $adb -s $device reverse "tcp:$port" "tcp:$port" | Out-Null
    Write-Host "Mapped $device tcp:$port -> computer tcp:$port"
  }
}

Write-Host ""
Write-Host "Current reverse mappings:"
foreach ($device in $devices) {
  Write-Host "[$device]"
  & $adb -s $device reverse --list
}
