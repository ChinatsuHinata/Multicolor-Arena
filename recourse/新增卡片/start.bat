@echo off
chcp 65001 >nul
cd /d "%~dp0"
python -c "from PIL import Image" >nul 2>&1
if errorlevel 1 (
    python -m pip install -r requirements.txt
    if errorlevel 1 (
        echo 安装依赖失败，请检查 Python 和网络连接。
        pause
        exit /b 1
    )
)
python crawl_cards.py
if errorlevel 1 echo 存在下载失败，请查看 download_report.csv 后重新运行。
pause
