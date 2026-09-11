@echo off
git add .
git commit -m "auto update: %date% %time%"
git push origin main
echo OK kanka hallettim!
pause