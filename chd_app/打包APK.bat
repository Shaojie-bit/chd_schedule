@echo off
chcp 65001 >nul
echo ===================================================
echo     长安大学原生 Flutter App 一键打包 Release APK
echo ===================================================
echo.
echo 正在映射纯英文构建虚拟驱动器 (消除中文路径报错)...
subst P: /d >nul 2>&1
subst P: "%~dp0"
if %errorlevel% neq 0 (
    echo 虚拟驱动器映射失败，将直接在当前路径构建...
    flutter build apk --release
) else (
    echo 正在以纯英文路径执行构建...
    powershell -Command "cd P:\; flutter build apk --release"
    subst P: /d >nul 2>&1
)

echo.
echo ===================================================
echo 构建完成！APK 文件位于:
echo build\app\outputs\flutter-apk\app-release.apk
echo ===================================================
pause
