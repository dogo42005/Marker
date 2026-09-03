@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================
echo   Instalador de Marker (PDF a Markdown)
echo ============================================
echo.

REM --- Buscar un Python compatible (3.10-3.12; PyTorch aun no soporta 3.13+ de forma confiable) ---
set PYCMD=

py -3.12 -c "print(1)" >nul 2>&1
if not errorlevel 1 (
    set "PYCMD=py -3.12"
    goto :found_python
)

py -3.11 -c "print(1)" >nul 2>&1
if not errorlevel 1 (
    set "PYCMD=py -3.11"
    goto :found_python
)

py -3.10 -c "print(1)" >nul 2>&1
if not errorlevel 1 (
    set "PYCMD=py -3.10"
    goto :found_python
)

echo No se encontro una version de Python compatible (3.10, 3.11 o 3.12).
echo Marker requiere Python 3.10+, pero PyTorch todavia no soporta bien versiones
echo muy nuevas como 3.13 o 3.14.
echo.
echo Instala Python 3.12 desde https://www.python.org/downloads/ y vuelve a
echo ejecutar este archivo.
echo.
pause
exit /b 1

:found_python
echo Usando interprete: %PYCMD%
echo.

REM --- Crear entorno virtual si no existe ---
if exist marker-env (
    echo El entorno virtual marker-env ya existe, se reutilizara.
) else (
    echo Creando entorno virtual marker-env...
    %PYCMD% -m venv marker-env
    if errorlevel 1 (
        echo.
        echo ERROR al crear el entorno virtual.
        pause
        exit /b 1
    )
)
echo.

REM --- Actualizar pip ---
echo Actualizando pip...
marker-env\Scripts\python.exe -m pip install --upgrade pip
echo.

REM --- Detectar GPU NVIDIA para instalar PyTorch con soporte CUDA (opcional) ---
where nvidia-smi >nul 2>&1
if not errorlevel 1 (
    echo GPU NVIDIA detectada. Instalando PyTorch con soporte CUDA...
    marker-env\Scripts\python.exe -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
    echo.
) else (
    echo No se detecto GPU NVIDIA ^(nvidia-smi no encontrado^). Se usara PyTorch para CPU.
    echo.
)

REM --- Instalar marker-pdf ---
REM IMPORTANTE: se fija la version 1.10.2. Desde la 2.0.0, marker-pdf cambio el
REM motor de OCR a un backend llama.cpp que requiere el binario externo
REM "llama-server" (no incluido, dificil de instalar en Windows). La 1.10.2 usa
REM el pipeline clasico de surya-ocr en PyTorch puro, sin dependencias externas.
echo Instalando marker-pdf==1.10.2 ^(puede tardar varios minutos^)...
marker-env\Scripts\python.exe -m pip install marker-pdf==1.10.2
if errorlevel 1 (
    echo.
    echo ERROR: la instalacion de marker-pdf fallo. Revisa el mensaje de arriba.
    pause
    exit /b 1
)
echo.

REM --- Verificacion ---
echo Verificando instalacion...
marker-env\Scripts\marker_single.exe --help >nul 2>&1
if errorlevel 1 (
    echo.
    echo ADVERTENCIA: marker_single --help devolvio un error. Revisa el log de arriba.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Instalacion completa
echo ============================================
echo.
echo Para convertir un PDF a Markdown, abre una terminal en esta carpeta y ejecuta:
echo.
echo   marker-env\Scripts\marker_single.exe "archivo.pdf" --output_format markdown --output_dir salida
echo.
echo Notas:
echo   - La primera conversion descarga ~2-4GB de modelos desde HuggingFace
echo     (una sola vez, luego queda en cache local).
echo   - Si el PDF es un escaneo (sin texto seleccionable) y no hay GPU, el OCR
echo     puede tardar bastante y usa harta RAM. Cierra programas pesados
echo     (navegador, etc) antes de convertir documentos largos.
echo   - Mas detalles y flags utiles en instrucciones_marker_pdf.md
echo.
pause
