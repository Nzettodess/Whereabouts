@echo off
REM Local development script with API keys from .env file

REM Check if .env exists
if not exist .env (
    echo Error: .env file not found!
    echo Please create a .env file with your API keys.
    echo See .env.example for the format.
    exit /b 1
)

REM Read environment variables from .env file
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    if "%%a"=="CALENDARIFIC_API_KEY" set CALENDARIFIC_API_KEY=%%b
    if "%%a"=="FESTIVO_API_KEY" set FESTIVO_API_KEY=%%b
    if "%%a"=="GOOGLE_CALENDAR_API_KEY" set GOOGLE_CALENDAR_API_KEY=%%b
)

REM Run Flutter with environment variables
flutter run -d chrome ^
    --dart-define=CALENDARIFIC_API_KEY=%CALENDARIFIC_API_KEY% ^
    --dart-define=FESTIVO_API_KEY=%FESTIVO_API_KEY% ^
    --dart-define=GOOGLE_CALENDAR_API_KEY=%GOOGLE_CALENDAR_API_KEY%
