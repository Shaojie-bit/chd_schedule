@echo off
chcp 65001 >nul
echo ===================================================
echo     长安大学原生 Flutter App 手机实时调试与安装
echo ===================================================
echo.
echo 正在检查已连接的安卓手机或模拟器设备...
flutter devices
echo.
echo 正在启动应用并推送到手机...
flutter run -d android
pause
