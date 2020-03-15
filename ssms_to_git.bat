@echo off

setlocal enableextensions enabledelayedexpansion

rem Данный bat-файл необходимо разместить в папке репозитория Git, где находятся папки схем БД с sql-объектами
rem Добавить в SSMS внешний инструмент
rem SSMS -> Tools -> External Tools
rem   Command - путь к данному bat-файлу
rem   Arguments - $(ItemPath) mode
rem     mode может принимать следующие значения:
rem       copy - копирование открытого файла с объектом в SSMS (процедура, функция, представление, триггер) в папку репозитория Git
rem       diff - сравнение файлов SSMS и Git
rem       merge - слияние файлов SSMS и Git
rem       open - открытие файла из Git
rem       explore - открытие в проводнике файла из Git
rem     Для корректного определения sql-объекта в скрипте должна быть строка вида: (CREATE|ALTER|CREATE OR ALTER) (PROCEDURE|PROC|FUNCTION|VIEW|TRIGGER) [schema].[name]
rem     Для сравнения и слияния файлов используется KDiff3
rem   Close on exit - необходимо включить, чтобы окно командной строки автоматически закрывалось
rem Вызвать добавленный инструмент можно из меню SSMS -> Tools -> Название_инструмента
rem или назначить сочетание клавиш в SSMS -> Tools -> Options -> Environment -> Keyboard для соответствующей команды Tools.ExternalCommand1, Tools.ExternalCommand2 и т.д.

goto :main

:help
echo Usage: ssms_to_git file mode
echo file - path to file ($(ItemPath) in SSMS)
echo mode - copy, diff, merge, open, explore
exit /b 0

:main

set file=%~1

if not exist "%file%" (
    echo File not found
    echo;
    call :help
    exit /b 1
)

set modes=;copy;diff;merge;open;explore;
set mode=%~2

if "!modes:;%mode%;=!"=="!modes!" (
    echo Mode not specified
    echo;
    call :help
    exit /b 1
)

for /f "tokens=1,2,3 delims=[]." %%a in ('findstr /r /i "\<CREATE\> \<ALTER\>" "%file%" ^| findstr /r /i "\<PROC \<FUNCTION \<VIEW \<TRIGGER"') do (
    for %%i in (%%a) do set type=%%i
    set schema=%%b
    set name=%%c
    goto :break
)
:break

set types[PROCEDURE]=Stored Procedures
set types[PROC]=Stored Procedures
set types[FUNCTION]=Functions
set types[VIEW]=Views
set types[TRIGGER]=Triggers

set type=!types[%type%]!

if "%type%"=="" (
    echo Sql object type not found
    exit /b 1
)

if "%schema%"=="" (
    echo Sql object schema not found
    exit /b 1
)

set name=%name:?=_%
for %%a in (\ / : ^< ^> ^| ^") do set name=!name:%%a=_!

if "%name%"=="" (
    echo Sql object name not found
    exit /b 1
)

set git_file=%~dp0%schema%\%type%\%name%.sql

if "%mode%"=="copy" (
    xcopy "%file%" "%git_file%*" /y /f
) else (
    if not exist "%git_file%" (
        echo Git file not found
        exit /b 1
    )

    set diff_modes=;diff;merge;

    if "!diff_modes:;%mode%;=!" neq "!diff_modes!" (
        for /f "skip=2 tokens=3*" %%a in ('reg query "HKEY_CURRENT_USER\SOFTWARE\KDiff3" /ve 2^>nul') do set kdiff=%%b\kdiff3.exe

        if not exist "!kdiff!" (
            echo KDiff not found
            exit /b 1
        )

        if "%mode%"=="diff" (
            "!kdiff!" "%file%" "%git_file%"
        ) else if "%mode%"=="merge" (
            "!kdiff!" "%file%" "%git_file%" -o "%git_file%"
        )
    ) else if "%mode%"=="open" (
        explorer "%git_file%"
    ) else if "%mode%"=="explore" (
        explorer /select,"%git_file%"
    )
)
