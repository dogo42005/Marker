# Instalar y usar Marker para convertir PDF → Markdown

## Objetivo
Instalar `marker-pdf` en este equipo y usarlo para convertir uno o varios PDFs a Markdown, preservando fórmulas LaTeX, tablas y estructura del documento.

## Requisitos previos
- Python 3.10+ instalado
- Conexión a internet (la primera ejecución descarga ~2-4GB de modelos desde HuggingFace)
- GPU NVIDIA opcional (acelera mucho el proceso, pero no es obligatoria)

---

## Paso 1 — Crear entorno virtual

```bash
python -m venv marker-env
source marker-env/bin/activate        # Linux/macOS
# marker-env\Scripts\activate.bat     # Windows
```

**Verificación:** el prompt de la terminal debe mostrar `(marker-env)` al inicio.

---

## Paso 2 — Instalar PyTorch (opcional, solo si hay GPU NVIDIA)

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
```

Si no hay GPU, saltar este paso — Marker igual funciona en CPU, solo más lento.

---

## Paso 3 — Instalar marker-pdf

**IMPORTANTE:** instalar la versión `1.10.2`, no la última. `marker-pdf>=2.0.0` cambió el motor de OCR a un backend `llama.cpp` que requiere un binario `llama-server` instalado aparte (no viene con pip, no hay build fácil en Windows) y falla con `SpawnError: llama-server binary not found`. La versión `1.10.2` usa el pipeline clásico de `surya-ocr` en PyTorch puro, sin dependencias externas.

```bash
pip install marker-pdf==1.10.2
```

**Verificación:**

```bash
marker_single --help
```

Debe mostrar las opciones del comando sin error.

---

## Paso 4 — Convertir un PDF individual

```bash
marker_single "ruta/al/archivo.pdf" --output_format markdown --output_dir salida/
```

La primera ejecución descargará los modelos de layout/OCR (surya) — puede tardar varios minutos. Ejecuciones posteriores son mucho más rápidas.

**Verificación:** debe existir `salida/archivo/archivo.md`.

---

## Paso 5 — (Opcional) Convertir varios PDFs de una carpeta

```bash
marker "carpeta_con_pdfs/" --output_dir salida/ --workers 4
```

Ajustar `--workers` según la RAM/VRAM disponible.

---

## Paso 6 — Revisar el resultado

- El markdown queda en `salida/<nombre>/<nombre>.md`
- Las imágenes extraídas quedan en la misma carpeta
- Las fórmulas matemáticas deben aparecer como LaTeX (`$...$` o `$$...$$`)

Si el resultado se ve mal (texto cortado, fórmulas rotas, tablas desalineadas), usar los flags del siguiente paso.

---

## Paso 7 — Flags útiles para mejorar el resultado

| Problema | Flag |
|---|---|
| PDF escaneado / texto corrupto | `--force_ocr` |
| Documento en español | `--langs es` |
| Fórmulas/tablas complejas mal reconocidas | `--use_llm` (requiere API key de Anthropic o Gemini, tiene costo) |

Ejemplo combinando flags:

```bash
marker_single "archivo.pdf" --output_format markdown --output_dir salida/ --force_ocr --langs es
```

---

## Notas
- Los pesos de los modelos usan licencia `cc-by-nc-sa-4.0`: uso personal/académico libre, con restricciones para uso comercial.
- Si `marker_single` no se reconoce como comando después de instalar, confirmar que el entorno virtual sigue activado.
- El flag `--langs` **no existe** en `marker-pdf==1.10.2` (era de versiones más viejas). El idioma se detecta automáticamente vía OCR, no hace falta especificarlo.

## Lecciones aprendidas (RAM y rendimiento en CPU)

Para PDFs escaneados (sin capa de texto) en equipos sin GPU, el paso de OCR (`Recognizing Text`) es el cuello de botella real, no la descarga de modelos:

- **Verificar antes si el PDF tiene texto embebido.** Si lo tiene, el OCR profundo se puede evitar casi por completo (mucho más rápido). Para comprobarlo:
  ```bash
  python -c "import pypdfium2 as pdfium; pdf = pdfium.PdfDocument('archivo.pdf'); print(len(pdf[0].get_textpage().get_text_range()))"
  ```
  Si imprime `0`, es un escaneo puro y el OCR es obligatorio.
- **RAM es el factor limitante, no CPU.** Con menos de ~8GB libres, el pipeline de `surya-ocr` (modelos de layout + detección + reconocimiento cargados en PyTorch/CPU) empieza a hacer *swap* a disco y cada iteración se vuelve progresivamente más lenta (de ~15s a 60-100s+ por bloque), en vez de mantener un ritmo estable. Cerrar navegador/apps pesadas **antes** de lanzar la conversión es más efectivo que bajar el batch size.
- **Bajar `RECOGNITION_BATCH_SIZE` / `DETECTOR_BATCH_SIZE` no ayuda si el problema es RAM total insuficiente** — puede incluso empeorar el tiempo por iteración al perder eficiencia de batching, sin reducir el swap. Solo tiene sentido si hay RAM de sobra pero VRAM/CPU cache limitada.
- Para un libro de ~90 páginas escaneadas sin GPU, contar con **varias horas** de procesamiento si la RAM disponible es ajustada (<8GB libres). Con RAM de sobra el ritmo debería ser de varios segundos por bloque de texto, no aumentando con el tiempo.
- El entorno virtual (`marker-env/`) y la caché de modelos (`%LOCALAPPDATA%\datalab\datalab\Cache\models`) **no son portables entre equipos** (rutas absolutas, binarios específicos de la instalación). Para usar Marker en otra máquina, repetir la instalación desde cero (Pasos 1-3) en vez de copiar estas carpetas.

## Si la descarga de modelos falla con error SSL (redes universitarias/corporativas)

Si al correr `marker_single` aparece un error como:

```
ssl.SSLEOFError: [SSL: UNEXPECTED_EOF_WHILE_READING] EOF occurred in violation of protocol
```

al intentar bajar `manifest.json` desde `models.datalab.to` (o `download.pytorch.org`), es porque la red (típico en redes de campus/corporativas con inspección SSL) pide una renegociación TLS a mitad de la conexión que el OpenSSL empaquetado con Python rechaza por seguridad, aunque el navegador y `curl.exe` sí la manejan bien (usan el motor TLS nativo de Windows, schannel).

**Diagnóstico rápido:** si `curl.exe -v https://models.datalab.to/layout/2025_09_23/manifest.json` funciona pero el error de Python persiste, es exactamente este problema.

**Solución:** correr `descargar_modelos.bat` (o `descargar_modelos.ps1`) antes de `marker_single`. Este script baja todos los modelos necesarios usando `curl.exe` (que sí funciona en estas redes) y los deja en la carpeta de caché exacta que Marker espera (`%LOCALAPPDATA%\datalab\datalab\Cache\models\...`). Una vez ahí, `marker_single` los detecta como ya descargados y no vuelve a intentar la descarga por red. El script reintenta automáticamente archivos grandes que se corten a mitad de descarga.
