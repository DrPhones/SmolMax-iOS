@echo off
echo =======================================================
echo   SmolMax iOS - Push to GitHub (DrPhones)
echo =======================================================
echo.

cd /d C:\Users\MO\SmolMax-iOS

echo [1/4] Initializing Git repository...
git init

echo [2/4] Adding all project files...
git add .

echo [3/4] Creating commit...
git commit -m "SmolMax iOS - Full Expert Paging Engine & UI"

echo [4/4] Setting remote and pushing to github.com/DrPhones/SmolMax-iOS...
git branch -M main
git remote remove origin 2>nul
git remote add origin https://github.com/DrPhones/SmolMax-iOS.git
git push -u origin main

echo.
echo =======================================================
echo   Done! Now visit:
echo   https://github.com/DrPhones/SmolMax-iOS/actions
echo   to download your SmolMax-iOS.ipa file!
echo =======================================================
pause
