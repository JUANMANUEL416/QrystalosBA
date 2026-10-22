# Reportes de Glosas

🚩

## Contexto

**Proceso:** Glosas
**Capa:** reporte

## Explicación

Proceso de reportes en módulo Glosas

## Ideas principales

- **Proceso principal**: El usuario accede al módulo y ejecuta el flujo paso a paso
- **Validaciones**: El sistema valida permisos, periodo abierto y datos obligatorios
- **Efecto**: Los cambios se reflejan en las tablas maestras y transaccionales
- **Contabilización**: Si aplica, genera comprobante contable en módulo de contabilidad
- **Errores comunes**: Periodo cerrado, permisos insuficientes, datos incompletos

## Campos decisivos y visibles

| Campo | Ubicación | Qué controla |
|-------|-----------|--------------|
| **ESTADO** | Registro principal | 0=pendiente, 1=procesado/confirmado |
| **PERIODO** | Periodo | Debe estar abierto para operar |
| **USUARIO** | Sesión | Permisos según USGRUH |
| **FECHA** | Registro | Fecha de operación |

## Variables de configuración (USVGS)

⚠️ Pendiente validar: Variables específicas del módulo en conocimiento/glosas/

## Usuario final

- **Usuario operativo**: Registra y procesa transacciones en el módulo
- **Contador**: Revisa contabilización si aplica
- **Supervisor**: Valida y autoriza operaciones críticas
- **Soporte**: Configura parámetros y resuelve incidencias

## Soporte y desarrollo

### Procedimientos almacenados

⚠️ Pendiente validar: SPs específicos en conocimiento/glosas/sps.json

**SP Principal**  
**Propósito:** Ejecuta la lógica principal del proceso  
**Valida:** Permisos, periodo abierto, datos obligatorios  
**Qué hace:** Actualiza tablas maestras y transaccionales  
**Errores:** «Periodo cerrado», «Permiso denegado», «Datos incompletos»

### Ejemplos reales

- **Ejemplo 1**: ⚠️ Pendiente validar con datos reales del cliente
- **Ejemplo 2**: ⚠️ Pendiente validar con datos reales del cliente
- **Ejemplo 3**: ⚠️ Pendiente validar con datos reales del cliente

## Pendiente validar

- ⚠️ SPs específicos en conocimiento/glosas/sps.json
- ⚠️ Variables USVGS del módulo
- ⚠️ Tablas maestras y transaccionales
- ⚠️ Flujo detallado paso a paso
- ⚠️ Ejemplos reales con datos de cliente
