# Proceso: Facturación

**Estado:** parcial  
**Módulo:** FTR

> Solo flujo y explicación. El cuerpo de los SP se lee de DESAIX o de la copia local `sql/`/`sql_refe/` (fuera de git); aquí solo queda el nombre del SP, sus métodos y validaciones (cita `SP:línea`).

## Resumen

Quien factura arma la factura en Administrativo → Facturación, notifica a la DIAN, empaqueta anexos, junta facturas en una **cuenta de cobro** y la **radica** en Cuentas por cobrar (fecha, quién recibió, número de radicado).

**Ya cubierto (no es desarrollo):** subir el radicado de cada factura en masa = detalle de CXC **recibida** → **Importar Radicados**. No es el diálogo Radicar → «varias fechas». Ver `proceso.json` → `necesidadesYaCubiertas`.

Eso no es el menú **Radicaciones** (`/rad`): ahí se reciben lotes, incapacidades y PQR.

## Procedencias confirmadas (2026-10-03)

Contraste realizado en Qrystalos2, documentación viva e IXONLINE/SQL. La consulta tomó **PREVERSION** y la última versión cerrada **2.0.7** (anterior **2.0.6**). Los diez objetos revisados resultaron idénticos entre PREVERSION y 2.0.7.

No confundir la procedencia del cargo con `FTR.PROCEDENCIA`:

| Origen operativo | Cabecera FTR | Ventana / motor confirmado |
|---|---|---|
| Manual, cápita o PGP | `FINANCIERO` | Facturas → `FTR_COL.CREARFTR` |
| Admisión hospitalaria `HADM` | `SALUD` | Urg-Hospi-Domi → `FTR_HADM_COL` → `SPK_FACTURA_ASIS` |
| Citas y evento `CIT` | `CI` | Masiva/Evento → `SPK_FACTURACE_N` o `SPK_FACTURACI_EVENTO_PAQ` |
| Autorizaciones `AUT` | `CE` | Masiva → `SPQ_FACTURACE_ESCMA` / `SPK_FACTURACE_N` |
| Programa | `AUTPG` | `AUTPG.FACTURAR_AUTPG` → `SPK_FACTURA_AUTPG` |
| NOPOS `APLIMF` | `CE` | `FTR_MASIVA_COL.FACTURAR_NOPOS_APLIM` → `SPK_FACTURACE_N` |
| Copago o recibo de caja | `CAJA` | `SPK_CREA_FACTURA_POS_CAJA` |
| Venta de inventario | `INVENTARIO` | Nace en Inventario; Facturación continúa consulta/DIAN |

`ONCO`, `APLIM`, `INV`, `HADM`, `CIT` y `AUT` también aparecen como filtros o procedencias de cargos (`FTRD`/`FTRDC`); no deben asumirse automáticamente como el código final de la cabecera.

### Acciones comunes después de crear FTR

- **Editar cabecera y líneas:** solo factura manual `FINANCIERO`, pendiente, no notificada y no contabilizada.
- **Liberar:** factura pendiente, fuera de cartera/CxC y no notificada; devuelve cargos al origen.
- **Anular / nota crédito:** depende de DIAN, contabilidad, cartera y procedencia.
- **Contabilizar:** `FTR_COL.ENVIA_CONTAB`; con `CONTAB_FTR_POSTDIAN=SI` exige `FACTE=2`.
- **DIAN:** `NOTI_DIAN`/`FE_ENCOLAR` → `FACTE=1`; el facturador externo deja `FACTE=2`, XML y CUFE.
- **Ministerio/SISPRO:** exige factura DIAN; genera JSON RIPS y registra CUV. **CUFE ≠ CUV ≠ radicado CXC**.

## Factura financiera: evento, cápita y PGP

**Ruta:** Administrativo → Facturación → Facturas → **Nueva Factura**. El frontend siempre guarda esta cabecera con `FTR.PROCEDENCIA=FINANCIERO`.

El plan seleccionado determina la modalidad:

| Modalidad | Identificación | Detalle y relación |
|---|---|---|
| Financiera por evento | `CAPITADA=0` | Líneas financieras manuales en `FTRD`; no usa relación capitada. |
| Cápita | `CAPITADA=1`, `PPT.PGP=0` | `TIPOCAP`: 1 Inicial, 2 Periodo, 3 Final, 4 Masiva. Periodo/Final/Masiva relacionan prestaciones en `FTRDC`; Inicial no las exige. |
| PGP | `CAPITADA=1`, `PPT.PGP=1` | Valor global prospectivo en `FTRD` y prestaciones/pacientes cubiertos en `FTRDC`. |

`FTRD` expresa lo cobrado en la factura; `FTRDC` conserva qué pacientes y servicios asistenciales soportan ese valor. Para cápita/PGP, la ausencia de la relación bloquea o invalida pasos posteriores como contabilidad y DIAN.

### TIPOCAP=4 — capitación masiva

`TIPOCAP=4` no es un estado DIAN. Identifica una **factura de capitación masiva** o consolidada por contrato:

- Queda fuera de la secuencia contractual `1 Inicial → 2 Periodo → 3 Final`; `CREARFTR` no le aplica esas validaciones de precedencia.
- La pantalla la etiqueta **Masiva** y oculta el bloque de datos reservado a Inicial/Periodo/Final.
- Debe tener relación de prestaciones `FTRDC`; el generador rechaza «FACTURA CAPITADA SIN RELACION DE SERVICIOS».
- `SPK_GENERAR_RIPS_JSON` la dirige a `SPK_RIPS_JSON_FTR_CAPMASI`.
- Para envío SISPRO usa el endpoint FEV estándar `CargarFevRips`, no los endpoints específicos de cápita Inicial, Periodo o Final.

El formulario de validación externa agrupa la opción 4 como «Masiva / PGP / facturación en contrato», pero PGP se identifica realmente por `PPT.PGP=1` y usa `SPK_RIPS_JSON_FTR_PGP`. Marcar `TIPOCAP=4` no convierte por sí solo una factura en PGP.

### RIPS externos

El botón **Relación JSON** abre `SubirJsonExterComponent` para cargar RIPS producidos por prestadores externos dentro del período de la factura. El frontend valida fechas y pacientes; `SPQ_SUBIR_AUTCOL.SUBIR_JSON_EXTERNO` valida régimen/tipo de usuario, crea el afiliado básico si no existe y persiste usuarios/servicios válidos en `FTRDJSON`. Los motores RIPS PGP/masivos integran después esa información cuando corresponde.

Esto **no envía a SISPRO** y **no genera CUV**: solo incorpora prestaciones externas al insumo RIPS de la factura.

## Radicación de cartera — controles de la cuenta

En `FCXCAComponent` los botones cambian con el estado de la cuenta:

- **Abierta** (`CERRADA=0`, `INDRECIBIDO=0`): Agregar Facturas, Borrar Marcadas, Cerrar CxC, Imprimir y Adjuntar.
- **Cerrada sin recibir** (`CERRADA=1`, `INDRECIBIDO=0`): Abrir CxC, Imprimir, F_ENVIO cuando la variable lo exige, Radicar CXC y Adjuntar.
- **Radicada** (`INDRECIBIDO=1`): Importar Radicados por Excel, asignar/editar el radicado de una factura, Adjuntar, Contabilizar, imprimir comprobante y descargar FE/PDF/FEV-RIPS.

El control que el usuario reconoce como escaneo documental se llama **Adjuntar**. Abre `DOCXTPOComponent` con procedencia `CXC`; permite Nuevo, Subir varios, Ver, Descargar, Descargar todos y Eliminar según permiso.

**Importar Radicados no radica la cuenta:** solo completa el número externo de cada factura después de que la cuenta ya fue recibida. La radicación inicial se realiza con **Radicar CXC**.

## Capas

1. Configuración — resolución DIAN, firma, pagador/plan.
2. Proceso propio — facturar → notificar → empaquetar → armar cuenta → radicar.
3. Lo que llega — admisión, citas, autorizaciones.
4. Subproceso unido — empaque y RIPS/FEV (no bancos).
5. Envío a contabilidad — factura y cuenta (cuerpo de SP no leído).

## Árbol RIPS JSON (2026-09-12)

```
FE (useRipsJsonAsync / Validaciones / masivos)
  └─ FTR_COL
       ├─ INICIAR_RIPS_JSON_JOB → FNK_RIPS_JSON_USAR_ASYNC
       │     └─ 0: FE cae a RIPS_JSON síncrono
       │     └─ 1: SPQ_PROCESO_JOB → EJECUTAR_RIPS_JSON_ASYNC
       └─ RIPS_JSON / EJECUTAR_RIPS_JSON_ASYNC
            └─ SPK_GENERAR_RIPS_JSON   (exige FTR.FACTE=2)
                 ├─ SOLO_META=SI → meta, sin JSON
                 ├─ GENERAR=NO y FTRJSON.JSON_ENVIO lleno → reutiliza
                 ├─ FACTURA
                 │    ├─ CAPITADA=1 + PPT.PGP=1     → SPK_RIPS_JSON_FTR_PGP
                 │    ├─ CAPITADA=1 + TIPOCAP<4     → SPK_RIPS_JSON_FTR_CAPI
                 │    ├─ TIPOCAP=4 (capita o no)    → SPK_RIPS_JSON_FTR_CAPMASI
                 │    ├─ TIPOFAC=M + AUTPG          → SPK_RIPS_JSON_FTR_AUTPG
                 │    ├─ TIPOFAC=M + NEDXC/NEDXS    → SPK_RIPS_JSON_FTR_CITPAQ
                 │    ├─ TIPOFAC=M (resto)          → SPK_RIPS_JSON_FTR_MAS
                 │    └─ evento (no M, no capita)   → SPK_RIPS_JSON_FTR_IND
                 ├─ AJUSTE (CNSGLO o CNSFCT) + CUV obligatorio
                 │    ├─ capita + PGP               → SPK_RIPS_JSON_AJUSTE_PGP  → RETURN
                 │    ├─ capita no-PGP              → no genera (JSON actual) → RETURN
                 │    └─ evento                     → SPK_RIPS_JSON_AJUSTE_IND → RETURN
                 ├─ NOTACR / NOTADB (FNOT.FACTE=2)  → SPK_RIPS_JSON_NDBCR_IND
                 └─ luego SPK_PERSISTIR_RIPSJSON_ENVIO → FTRJSON / FNOTJSON

NOTAAJUSTE_PGP y NOTAAJUSTE_MAS están en el script después del RETURN de AJUSTE:
no se ejecutan por este camino. Confirmar otro caller al leerlos.
```

Árbol **cerrado 2026-09-12**. El módulo propio (preguntas, FAQ, fichas) es `conocimiento/rips-json/`. No pido más SQL de este circuito.

Módulos hermanos de documentos electrónicos:

- XML DIAN / FEV (Colombia, `FACTE`) → `conocimiento/dian-xml/`
- JSON Perú / SUNAT (`FACTEP`) → `conocimiento/json-peru/`

