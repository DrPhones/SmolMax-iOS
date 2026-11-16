@echo off
echo =======================================================
echo   SmolMax iOS - Push to GitHub (DrPhones)
echo =======================================================
echo.

cd /d C:\Users\MO\SmolMax-iOS

echo [1/3] Adding updated workflow files...
git add .

echo [2/3] Creating commit...
git commit -m "Fix GitHub Actions runner: update macos-14 to macos-latest"

echo [3/3] Pushing to github.com/DrPhones/SmolMax-iOS...
git push -u origin main

echo.
echo =======================================================
echo   Done! Now check the Actions tab:
echo   https://github.com/DrPhones/SmolMax-iOS/actions
echo =======================================================
pause
