$ErrorActionPreference = "Stop"

# Descarga previa de los modelos de Marker usando curl.exe (motor TLS nativo
# de Windows / schannel) en vez de la libreria de Python (OpenSSL empaquetado
# con Python no acepta la renegociacion TLS que pide el servidor en algunas
# redes con inspeccion SSL, ej. redes universitarias/corporativas).
#
# Una vez que los archivos quedan en la cache local, marker_single los
# detecta como ya descargados (surya/common/s3.py: check_manifest) y no
# vuelve a intentar la descarga por red, evitando el error SSL.

$modelos = @(
    "layout/2025_09_23",
    "text_detection/2025_05_07",
    "text_recognition/2025_09_23",
    "table_recognition/2025_02_18",
    "ocr_error_detection/2025_02_18"
)

$baseUrl = "https://models.datalab.to"
$cacheDir = Join-Path $env:LOCALAPPDATA "datalab\datalab\Cache\models"

Write-Host "============================================"
Write-Host "  Descarga de modelos de Marker (via curl.exe)"
Write-Host "============================================"
Write-Host ""

foreach ($modelo in $modelos) {
    $localDir = Join-Path $cacheDir ($modelo -replace "/", "\")
    $manifestPath = Join-Path $localDir "manifest.json"

    New-Item -ItemType Directory -Force -Path $localDir | Out-Null

    Write-Host "--- $modelo ---"

    # Bajar manifest.json (si falla, se aborta este modelo y se avisa)
    $manifestUrl = "$baseUrl/$modelo/manifest.json"
    curl.exe -sS -f --retry 8 --retry-delay 5 --retry-all-errors -o $manifestPath $manifestUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR descargando manifest.json para $modelo (curl exit $LASTEXITCODE)"
        continue
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $archivos = $manifest.files

    foreach ($archivo in $archivos) {
        $destino = Join-Path $localDir $archivo
        Write-Host "  descargando: $archivo"
        $url = "$baseUrl/$modelo/$archivo"
        # -C - retoma descargas parciales; --retry reintenta cortes de conexion
        # (comunes en archivos grandes como model.safetensors en redes inestables)
        curl.exe -sS -f -L -C - --retry 8 --retry-delay 5 --retry-all-errors -o $destino $url
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ERROR descargando $archivo (curl exit $LASTEXITCODE) - se reintentara si vuelves a correr el script"
        }
    }
    Write-Host ""
}

Write-Host "============================================"
Write-Host "  Listo. Ahora puedes correr marker_single"
Write-Host "  normalmente (no deberia intentar bajar nada"
Write-Host "  por red si todo quedo completo arriba)."
Write-Host "============================================"
