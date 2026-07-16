& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
Write-Host "Da cau noi Port 8080 (Backend) va 8000 (AI Server) thanh cong cho thiet bi Android!"
Write-Host "Ban co the chay app tren dien thoai that ngay bay gio."
pause
