$ErrorActionPreference = "Stop"

# Instala PyTorch con soporte CUDA descargando los wheels via curl.exe
# (motor TLS nativo de Windows) en vez de pip directo, porque pip/Python
# falla con SSLEOFError al hablar con download.pytorch.org en redes que
# piden renegociacion TLS a mitad de conexion (ver instrucciones_marker_pdf.md).
#
# El indice cu121 quedo desactualizado (tope torch 2.5.1, marker-pdf pide
# >=2.7.0). cu126 es el que trae la version mas nueva de torch (2.14.0) al
# momento de escribir esto. Si esto se corre mas adelante y falla por
# version, revisar https://download.pytorch.org/whl/cu126/torch/ (o el
# indice cu que corresponda) para actualizar $torchVer/$tvVer.

$torchVer = "2.14.0"
$tvVer = "0.29.0"
$cuTag = "cu126"

$scriptDir = $PSScriptRoot
$pythonExe = Join-Path $scriptDir "marker-env\Scripts\python.exe"
$wheelDir = Join-Path $scriptDir "wheels"
New-Item -ItemType Directory -Force -Path $wheelDir | Out-Null

Write-Host "============================================"
Write-Host "  Instalando PyTorch $torchVer con CUDA ($cuTag)"
Write-Host "============================================"
Write-Host ""

$verInfo = & $pythonExe -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}')"
$cpTag = "cp$verInfo"
Write-Host "Python detectado en marker-env: $cpTag"
Write-Host ""

$baseUrl = "https://download-r2.pytorch.org/whl/$cuTag"
$archivos = @(
    @{ name = "torch-$torchVer+$cuTag-$cpTag-$cpTag-win_amd64.whl"; url = "$baseUrl/torch-$torchVer%2B$cuTag-$cpTag-$cpTag-win_amd64.whl" },
    @{ name = "torchvision-$tvVer+$cuTag-$cpTag-$cpTag-win_amd64.whl"; url = "$baseUrl/torchvision-$tvVer%2B$cuTag-$cpTag-$cpTag-win_amd64.whl" }
)

$rutasLocales = @()
foreach ($a in $archivos) {
    $destino = Join-Path $wheelDir $a.name
    $rutasLocales += $destino
    if ((Test-Path $destino) -and ((Get-Item $destino).Length -gt 1MB)) {
        Write-Host "ya existe: $($a.name)"
        continue
    }
    Write-Host "descargando: $($a.name) (puede pesar varios GB, toma un rato)"
    curl.exe -sS -f -L -C - --retry 10 --retry-delay 5 --retry-all-errors -o $destino $a.url
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR descargando $($a.name) (curl exit $LASTEXITCODE)"
        Write-Host "Vuelve a correr este script, retoma la descarga donde quedo."
        exit 1
    }
    Write-Host ""
}

Write-Host "Instalando wheels descargados con pip..."
& $pythonExe -m pip install --force-reinstall $rutasLocales
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: pip install fallo. Revisa el mensaje de arriba."
    exit 1
}

Write-Host ""
Write-Host "Verificando GPU..."
& $pythonExe -c "import torch; print('CUDA disponible:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'ninguna')"
