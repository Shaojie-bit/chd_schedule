@echo off
chcp 65001 > nul
title 长安大学现代课表中心
echo ========================================================
echo        长安大学现代教务课表与学术日程中心
echo ========================================================
echo.
echo 正在为您启动本地极速服务...
echo.

start "" "http://localhost:8000"
python app.py

pause
