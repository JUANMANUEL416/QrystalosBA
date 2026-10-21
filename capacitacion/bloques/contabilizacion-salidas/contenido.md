# Contabilización de salidas

📊

## Contexto

**Proceso:** Inventario, Compras y Farmacia  
**Capa:** salidas

## Explicación

Contabilización de movimientos de salida con OM Inventario (mismo SP que entradas)

## Ideas principales

- **Procedimiento principal**: SPK_NC_CONTAB_INV ejecuta la lógica central de este tipo de movimiento
- **Validaciones**: El sistema valida SECONTABILIZA efectivo, permisos de bodega, periodo abierto y KMCOM cuando aplica
- **Efecto en existencias**: El movimiento incrementa o decrementa IEXI y actualiza IDXB/IART según el tipo
- **Contabilización**: Usa SPK_NC_CONTAB_INV para generar MCP según modelo MOV_INVENTARIO en KMCOM
- **Errores comunes**: KMCOM faltante, periodo cerrado, bodega bloqueada, tipo de movimiento inactivo

## Campos decisivos y visibles

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| **ITMO.SECONTABILIZA** | Tipos de movimiento | Si 1, puede contabilizarse; si 0, no |
| **ITMO.TIPO** | Tipos de movimiento | Crédito (entrada) o Débito (salida) |
| **IBOD.NOCONTABILIZA** | Bodegas | Si 1, esa bodega no contabiliza aunque ITMO diga que sí |
| **IMOV.ESTADO** | Movimientos | 0=pendiente, 1=confirmado |
| **PRI.CERRADO_INV** | Periodo | Bloquea si 1; debe estar abierto |

## Variables de configuración (USVGS)

| Código | Descripción | Valor habitual | Efecto |
|--------|-------------|----------------|--------|
| **CONTABIMOV_JOB** | CONTABIMOV_JOB | *Pendiente validar* | *Pendiente validar* |

## Usuario final

- **Farmaceuta/Auxiliar**: Registra y confirma el movimiento en inv.ges o inv.imov
- **Contador**: Revisa contabilización desde OM Inventario
- **Soporte**: Valida KMCOM, tipos de movimiento y permisos de bodega

## Soporte y desarrollo

### Procedimientos almacenados

**SPK_NC_CONTAB_INV**  
**Propósito:** Contabilización de movimientos de salida con OM Inventario (mismo SP que entradas)  
**Métodos:** *Pendiente validar en conocimiento/inventario/sps.json*  
**Valida:** SECONTABILIZA efectivo, periodo abierto, KMCOM cuando aplica  
**Qué hace:** Actualiza IEXI, IDXB/IART, genera comprobante contable si SECONTABILIZA=1  
**Errores:** «Periodo cerrado», «No existe cuenta KMCOM», «Tipo de movimiento inactivo»

### Ejemplos reales

- **Ejemplo 1**: *Pendiente validar con datos reales del cliente*
- **Ejemplo 2**: *Pendiente validar con datos reales del cliente*
- **Ejemplo 3**: *Pendiente validar con datos reales del cliente*

## Pendiente validar

- ⚠️ Métodos específicos del SP en conocimiento/inventario/sps.json
- ⚠️ Variables USVGS: valores habituales y efecto en el flujo
- ⚠️ Ejemplos reales con datos de cliente (sin información sensible)
- ⚠️ Validaciones específicas del tipo de movimiento
- ⚠️ Cruce con proceso hermano si aplica (CxP, FTR, caja)
