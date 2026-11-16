Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  SmolMax iOS - Push to GitHub (DrPhones)               " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Set-Location -Path "C:\Users\MO\SmolMax-iOS"

Write-Host "`n[1/4] Initializing Git repository..." -ForegroundColor Yellow
git init

Write-Host "[2/4] Adding all project files..." -ForegroundColor Yellow
git add .

Write-Host "[3/4] Creating commit..." -ForegroundColor Yellow
git commit -m "SmolMax iOS - Full Expert Paging Engine & UI"

Write-Host "[4/4] Setting remote and pushing to https://github.com/DrPhones/SmolMax-iOS.git..." -ForegroundColor Yellow
git branch -M main
try { git remote remove origin 2>$null } catch {}
git remote add origin https://github.com/DrPhones/SmolMax-iOS.git
git push -u origin main

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host "  Done! Check your build at:" -ForegroundColor Green
Write-Host "  https://github.com/DrPhones/SmolMax-iOS/actions" -ForegroundColor White
Write-Host "=======================================================" -ForegroundColor Green
Read-Host -Prompt "Press Enter to exit"
