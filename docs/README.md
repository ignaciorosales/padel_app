# Documentación

| Carpeta | Contenido | Estado |
|---|---|---|
| [protocol/](protocol/) | Contrato entre esclavos, maestro y app | ⭐ empieza aquí |
| [hardware/](hardware/) | Montaje RS-485, diagnóstico USB, pruebas serie | vigente |
| [app/](app/) | Temas, colores, selección de equipos | vigente |
| [deployment/](deployment/) | Android TV, publicación en Google Play | vigente |
| [producto/](producto/) | Plan de producto: qué se construye después del marcador | vigente |
| [archive/](archive/) | Documentación de la era BLE | **obsoleta** |

## Sobre `archive/`

El sistema usó Bluetooth LE antes de pasar a RS-485 + USB serial. Esos
documentos describen un protocolo que ya no existe:

| Documento | Por qué está archivado |
|---|---|
| `FULL_TELEMETRY_USAGE.md` | telemetría sobre BLE |
| `TELEMETRY_TESTING.md` | pruebas de telemetría BLE |
| `OPTIMIZATIONS.md` | latencia y captura BLE |
| `ANTI_DUPLICADOS.md` | anti-duplicados en la capa BLE |
| `MEJORAS_FINALES.md` | registro de cambios de esa época |

Se conservan porque algunas decisiones de diseño (anti-duplicados, umbrales del
sensor ToF) se heredaron tal cual al sistema actual y aquí está el razonamiento
original. **No los sigas como instrucciones de montaje.**
