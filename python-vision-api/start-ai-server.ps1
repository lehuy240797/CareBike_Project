Set-Location $PSScriptRoot

if (-not (Test-Path .\venv\Scripts\Activate.ps1)) {
    Write-Host "Missing python-vision-api venv. Run: python -m venv venv; .\venv\Scripts\python.exe -m pip install -r requirements.txt"
    pause
    exit 1
}

.\venv\Scripts\Activate.ps1
python -m uvicorn main:app --host 0.0.0.0 --port 8000
pause
