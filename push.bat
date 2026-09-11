@echo off
git add .
git commit -m "Auto update: %DATE% %TIME%"
git push origin main
echo.
echo OK kanka hallettim, GitHub guncellendi!
echo.
pause