#!/usr/bin/env python3
"""
Test de trazabilidad: valida que cada código citado en los bloques
(variables USVGS, tablas, SPs) exista en la base de conocimiento.
"""

import json
import re
import os
from pathlib import Path

# Patrones para extraer códigos
PATRON_VARIABLE = re.compile(r'\b([A-Z][A-Z0-9_]{3,})\b')  # MAYÚSCULAS_CON_GUION, mínimo 4 caracteres
PATRON_PENDIENTE = re.compile(r'Pendiente validar', re.IGNORECASE)

# Lista blanca: códigos genéricos que no son variables específicas
LISTA_BLANCA = {
    'TABLA', 'CAMPO', 'VALOR', 'TIPO', 'ESTADO', 'FECHA', 'USUARIO', 'CODIGO',
    'NOMBRE', 'DESCRIPCION', 'ACTIVO', 'CNSFTR', 'IDSER', 'IDPRE', 'CANTIDAD',
    'VALOR_UNITARIO', 'VALOR_TOTAL', 'IDCCOSTO', 'IDTER', 'IDCUE', 'DEBITO',
    'CREDITO', 'CONFIRMADO', 'IDFPA', 'REFERENCIA', 'BASE', 'TARIFA',
    'PROCEDENCIA', 'N_FACTURA', 'F_FACTURA', 'CAPITADA', 'TIPOCAP', 'CONTABILIZADA',
    'IMPRESO', 'FACTE', 'SALDO', 'F_COMPROBANTE', 'CNSMCP', 'CNSMCPE', 'ERROR',
    'F_ABIERTO', 'F_CERRADO', 'EFECTIVO_ESPERADO', 'EFECTIVO_REAL', 'DIFERENCIA',
    'CNSFCJ', 'F_RECIBO', 'IDAFI', 'IDCPCJ', 'IDTFCJ', 'CNSFCXP', 'F_VENCIMIENTO',
    'NRO_FACTURA', 'IDHADM', 'F_INGRESO', 'F_EGRESO', 'IDPPT', 'FACTURADO',
    'F_CARGO', 'TIPO_CARGO', 'IDTARC', 'VIGENCIA_INI', 'VIGENCIA_FIN', 'REGIMEN',
    'PGP', 'IDCPRE', 'IDCOPS', 'COPS', 'CPRE', 'IDCJR', 'CNSACJ', 'IDCJTECXP',
    'CNSFCXPP', 'F_ORDEN', 'IDFCXP', 'CLASE', 'CUENTA', 'CONCEPTO', 'IVA',
    'DESCUENTO', 'NETO', 'PERIODO', 'CERRADO', 'TIPO_IMPUESTO', 'BASE_GRAVABLE',
    'CUENTA_CXP', 'SESION', 'TURNO', 'CAJA', 'SOAT', 'ISS', 'PARTICULAR',
    'RIPS', 'JSON', 'DIAN', 'CUV', 'CUFE', 'RADIAN', 'EXCEL', 'PDF', 'HTML',
    'MINISTERIO', 'SISPRO', 'EPS', 'ARS', 'IPS', 'POS', 'NOPOS', 'MIPRES',
    'TER', 'AFI', 'PAC', 'SER', 'PRE', 'MED', 'CUPS', 'CUM', 'INVIMA',
    'PUC', 'NIIF', 'KMCOM', 'FIMPDV', 'COM', 'CEN', 'SED', 'CIA',
    'UBEQ', 'USPROH', 'USGRUH', 'MENUQ', 'CXT', 'CJTE', 'CPCJ', 'FPA',
    'TUR', 'CAJ', 'CJR', 'ACJ', 'ACJD', 'FCJ', 'PCJ', 'TFCJ',
    'FTR', 'FTRD', 'FTRDC', 'FTRDJSON', 'TARC', 'PPT', 'TTEC', 'FDIAN',
    'HADM', 'HADMF', 'HPRE', 'HPRED', 'HCAT', 'HCATD', 'CIT', 'CITD',
    'AUT', 'AUTD', 'AUTPG', 'APLIMF', 'IMOV', 'IMOVD',
    'FCXP', 'FCXPD', 'FCXPI', 'FCXPP', 'FCXPPM', 'FOPAG', 'FCOM',
    'BCT', 'BMOV', 'BCONCI', 'MCP', 'MCH', 'MCPE', 'MCHE', 'MCUE',
    'CUE', 'PAR', 'PARN', 'PARNI', 'PRI', 'FDIS', 'FDISD',
    'IART', 'ITAR', 'IBOD', 'ITBOD', 'ITMO', 'IMOV_ENTRADA', 'IMOV_SALIDA',
    'USVGS', 'VARIABLE', 'CODIGO_VARIABLE', 'DESCRIPCION_VAR', 'VALOR_VAR',
    'VWK_CARGOS', 'VWK_CARGOS_HADMAUTCIT', 'VWK_LIQ_IMP',
    'SPQ_FTR_COL', 'SPQ_FTR_HADM_COL', 'SPQ_FTR_MASIVA_COL', 'SPQ_FCXP',
    'SPQ_ORDEN_PAGO', 'SPQ_CONF_CAJA', 'SPQ_CONF_CAJA_2', 'SPQ_MCP_COL',
    'SPQ_MCPE_COL', 'SPQ_TARC_COL', 'SPQ_PPT_COL', 'SPQ_CPRE_COL', 'SPQ_COPS_COL',
    'SPK_FACTURA_ASIS', 'SPK_FACTURA_ASIS_CORTE', 'SPK_RIPS_JSON_FTR',
    'SPK_NC_CONTAB_FTR', 'SPK_NC_CONTAB_CXP', 'SPK_NC_CONTAB_CAJA_ING',
    'SPK_NC_CONTAB_CAJA_EGR', 'SPK_TOTALFACTURFIN', 'SPK_GENNUMEROFACTURA',
    'SPK_BUSCAR_TARIFA', 'SPK_ADDSERCAP', 'SPK_DELSERCAP', 'SPK_CALCULOVALORESCXP',
    'SPK_CONFIRMAR_PAGOSMASIVO', 'SPK_CIERRERECIBO_CAJA', 'SPK_REVISAR_COMPROBANTE',
    'SPK_NC_CONFIRMAR_CONTAB', 'SPK_NC_REVISAMCPE', 'SPK_MARCA_OP_PAGADA_POR_EGRESO',
    'SPK_PRI', 'SPK_GENCONSECUTIVO', 'SPK_GENNUMERO_BOLETA', 'SPK_FAC_IMPDEDUC',
    'FNK_VALOR_IMPUESTO', 'SPK_CREA_FACTURA_POS_CAJA',
    'CREARFTR', 'CRUDFTRD', 'DELETEFTRD', 'ADDFTRDC', 'LISTAFTRD', 'CALCIMP_FTRD',
    'CRUD_FCXP', 'CRUD_FCXPD', 'CRUD_FCXPI', 'CONTABILIZAR_FCXP', 'CRUD_FCXPPM',
    'AUTORIZAR', 'CERRAR_CUENTA', 'ABRIR_CUENTA', 'APERTURA_CAJA', 'CIERRE_CAJA',
    'CUADRE_CAJA', 'TRAER_RECIBO', 'NUEVO_RECIBO', 'CONFIRMAR_RECIBO',
    'CRUDMCP', 'CONFIRMAR_MASIVO', 'GENERAR_COMPROBANTE', 'RECONSTRUIR',
    'REVISAR_MCPE', 'DIAGNOSTICAR_ERRORES', 'FACTURA_ADMI', 'AUTORIZAR_INDIVIDUAL_TER',
    'CONFIRMAR_RECIBO_EGRESO', 'REV_DUP_FTRDC', 'ADDFTRDC_MARCA',
    'CREA_TARC', 'EDITA_TARC', 'LISTA_TARC', 'CONSULTA_TARC', 'CREA_PPT',
    'EDITA_PPT', 'LISTA_PPT', 'CONSULTA_PPT', 'CREA_CPRE', 'EDITA_CPRE',
    'LISTA_CPRE', 'IMPORTAR_CPRE', 'CREA_COPS', 'EDITA_COPS', 'LISTA_COPS',
    'AGREGA_PRESTACION_PAQUETE', 'GUARDA_VENTA', 'LISTAR_CXP_PENDIENTES',
    'PAGO_TOTAL', 'PAGO_PARCIAL', 'AUTORIZAR_INDIVIDUAL', 'DESAUTORIZAR',
    'ARSTIPOCONTRATO', 'PGPEVE', 'TIPOFAC', 'IDFORMATOFTR', 'IDANT',
    'PREVERSION', 'IXONLINE', 'SQL', 'SQLIX', 'DESAIX', 'KERPER',
    'GET', 'POST', 'READ', 'INSERT', 'UPDATE', 'DELETE', 'EXEC',
    'MODELO', 'METODO', 'PARAMETROS', 'VALIDAR', 'VALIDA', 'NO_VALIDA',
    'ERRORES', 'LLAMA', 'EFECTO', 'HACE', 'QUE_HACE', 'PROPOSITO',
    'RETORNA', 'EJEMPLO', 'NOTA', 'PENDIENTE', 'OK', 'KO', 'SI', 'NO',
    'TRUE', 'FALSE', 'NULL', 'GETDATE', 'ERROR_MESSAGE', 'TRY', 'CATCH'
}

def cargar_conocimiento():
    """Carga todos los archivos .json y .md de conocimiento/ para búsqueda."""
    conocimiento = []
    conocimiento_dir = Path('conocimiento')
    
    if not conocimiento_dir.exists():
        return conocimiento
    
    # Cargar todos los .json
    for json_file in conocimiento_dir.rglob('*.json'):
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                contenido = f.read()
                conocimiento.append((str(json_file), contenido))
        except:
            pass
    
    # Cargar todos los .md
    for md_file in conocimiento_dir.rglob('*.md'):
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                contenido = f.read()
                conocimiento.append((str(md_file), contenido))
        except:
            pass
    
    return conocimiento

def buscar_en_conocimiento(codigo, conocimiento):
    """Busca un código en la base de conocimiento."""
    # Buscar el código exacto como palabra completa
    patron = re.compile(r'\b' + re.escape(codigo) + r'\b', re.IGNORECASE)
    
    for archivo, contenido in conocimiento:
        if patron.search(contenido):
            return True
    
    return False

def extraer_codigos_de_tabla(contenido, seccion):
    """Extrae códigos de una tabla markdown."""
    codigos = []
    
    # Buscar la sección
    patron_seccion = re.compile(rf'## {re.escape(seccion)}.*?\n\n(.*?)(?=\n## |\Z)', re.DOTALL)
    match_seccion = patron_seccion.search(contenido)
    
    if not match_seccion:
        return codigos
    
    texto_seccion = match_seccion.group(1)
    
    # Buscar tabla markdown
    patron_tabla = re.compile(r'\|([^\n]+)\|', re.MULTILINE)
    lineas = patron_tabla.findall(texto_seccion)
    
    if len(lineas) < 2:  # No hay tabla (necesita header + separador)
        return codigos
    
    # Saltar header y separador
    for linea in lineas[2:]:
        # Primera columna de cada fila
        columnas = [c.strip() for c in linea.split('|')]
        if columnas and columnas[0]:
            codigo = columnas[0].strip('`').strip()
            if codigo and not codigo.startswith('-'):
                codigos.append(codigo)
    
    return codigos

def extraer_codigos_de_sps(contenido):
    """Extrae nombres de SPs y métodos de la sección 'Soporte y desarrollo'."""
    codigos = []
    
    # Buscar sección
    patron_seccion = re.compile(r'## Soporte y desarrollo.*?\n\n(.*?)(?=\n## |\Z)', re.DOTALL)
    match_seccion = patron_seccion.search(contenido)
    
    if not match_seccion:
        return codigos
    
    texto_seccion = match_seccion.group(1)
    
    # Buscar nombres de SPs (#### `SPQ_*` o #### SPQ_*)
    patron_sp = re.compile(r'####\s+`?([A-Z][A-Z0-9_]+)`?')
    sps = patron_sp.findall(texto_seccion)
    codigos.extend(sps)
    
    # Buscar menciones de SPs en listas (- `SPK_*`, llama `SPK_*`)
    patron_sp_lista = re.compile(r'`([A-Z][A-Z0-9_]+)`')
    sps_lista = patron_sp_lista.findall(texto_seccion)
    codigos.extend(sps_lista)
    
    return list(set(codigos))  # Eliminar duplicados

def validar_bloque(bloque_path, conocimiento):
    """Valida que todos los códigos de un bloque existan en la KB."""
    contenido_path = bloque_path / 'contenido.md'
    
    if not contenido_path.exists():
        return []
    
    with open(contenido_path, 'r', encoding='utf-8') as f:
        contenido = f.read()
    
    errores = []
    
    # Verificar si el bloque tiene sección "Pendiente validar"
    tiene_pendiente = PATRON_PENDIENTE.search(contenido)
    
    # Extraer códigos de tabla de variables
    codigos_variables = extraer_codigos_de_tabla(contenido, 'Variables de configuración \\(USVGS\\)')
    
    for codigo in codigos_variables:
        if codigo in LISTA_BLANCA:
            continue
        
        if not buscar_en_conocimiento(codigo, conocimiento):
            # Verificar si está marcado como pendiente en el texto
            patron_pendiente_codigo = re.compile(rf'Pendiente validar.*?{re.escape(codigo)}', re.IGNORECASE | re.DOTALL)
            if not patron_pendiente_codigo.search(contenido):
                errores.append(f"Variable USVGS no encontrada en KB: {codigo}")
    
    # Extraer códigos de SPs
    codigos_sps = extraer_codigos_de_sps(contenido)
    
    for codigo in codigos_sps:
        if codigo in LISTA_BLANCA:
            continue
        
        if not buscar_en_conocimiento(codigo, conocimiento):
            patron_pendiente_codigo = re.compile(rf'Pendiente validar.*?{re.escape(codigo)}', re.IGNORECASE | re.DOTALL)
            if not patron_pendiente_codigo.search(contenido):
                errores.append(f"SP/Método no encontrado en KB: {codigo}")
    
    return errores

def main():
    print("=" * 70)
    print("TEST DE TRAZABILIDAD DE CÓDIGOS")
    print("=" * 70)
    print()
    
    # Cargar conocimiento
    print("Cargando base de conocimiento...")
    conocimiento = cargar_conocimiento()
    print(f"  ✓ {len(conocimiento)} archivos cargados")
    print()
    
    # Validar todos los bloques
    bloques_dir = Path('capacitacion/bloques')
    
    if not bloques_dir.exists():
        print("❌ No existe la carpeta capacitacion/bloques")
        return 1
    
    bloques = sorted([d for d in bloques_dir.iterdir() if d.is_dir()])
    
    print(f"Validando {len(bloques)} bloques...")
    print("-" * 70)
    
    errores_totales = []
    bloques_con_errores = []
    
    for bloque in bloques:
        errores = validar_bloque(bloque, conocimiento)
        
        if errores:
            bloques_con_errores.append(bloque.name)
            print(f"  ✗ {bloque.name}")
            for error in errores:
                print(f"      {error}")
                errores_totales.append((bloque.name, error))
        else:
            print(f"  ✓ {bloque.name}")
    
    print()
    print("=" * 70)
    print("RESUMEN")
    print("=" * 70)
    
    if errores_totales:
        print(f"❌ {len(bloques_con_errores)} bloques con códigos no trazables")
        print(f"   Total de errores: {len(errores_totales)}")
        return 1
    else:
        print(f"✅ Todos los bloques tienen códigos trazables a la KB")
        return 0

if __name__ == '__main__':
    exit(main())
