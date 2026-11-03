@echo off
setlocal
git add .
git diff --cached --quiet
if not errorlevel 1 (
    echo Degisiklik yok: commit atlandi.
    pause
    exit /b 0
)
git commit -m "Auto update: %DATE% %TIME%"
if errorlevel 1 goto fail
git push origin main
if errorlevel 1 goto fail
echo.
echo OK kanka hallettim, GitHub guncellendi!
pause
exit /b 0

:fail
echo.
echo HATA: git basarisiz oldu, yukaridaki ciktiyi kontrol et.
pause
exit /b 1
