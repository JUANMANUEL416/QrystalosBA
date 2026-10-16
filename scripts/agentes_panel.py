# -*- coding: utf-8 -*-
"""Panel de agentes: cada uno corre en local (Ollama) o en Cursor.

Un agente nuevo se suma a DEFINIDOS, o se registra en el JSON, y el panel lo muestra.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(ROOT, "config", "agentes.json")

DEFINIDOS = [
    {
        "id": "conocimiento",
        "nombre": "Conocimiento",
        "hace": "Alimenta la base: atiende la cola de handoffs, documenta el SP del día y cierra pendientes. Solo pregunta huecos.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "modos": ["normal"],
        "nota": "Único que escribe sps.json / proceso.json. En local completa métodos sin ficha; no pisa una ficha leída.",
    },
    {
        "id": "consultas",
        "nombre": "Consultas",
        "hace": "Responde desde la base (índice → ficha puntual). Si no alcanza, escala a Conocimiento por la cola.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "modos": ["normal", "soporte"],
        "nota": "Modo soporte: consulta formal en data/soporte-consultas/{id} con respuestaOficial. No reescribe la base.",
    },
    {
        "id": "requerimientos",
        "nombre": "Requerimientos",
        "hace": "REQ o necesidad: base primero, luego Qrystalos2 y documentación; dudas, cambio propuesto e impactos.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "modos": ["analisis", "comite", "contable"],
        "nota": "analisis = caso activo y dictamen; comite = solicitud de requerimiento; contable = validar contabilidad o comprobante errado.",
    },
    {
        "id": "prueba-req",
        "nombre": "Prueba req",
        "hace": "Contrasta una entrega del desarrollador: base, fuente, IXONLINE/SQL y la base de pruebas. Cierra en entrega o devolución.",
        "motor": "cursor",
        "motores": ["cursor"],
        "modeloLocal": "",
        "modos": ["prueba"],
        "nota": "Menú Soporte. Solo lectura en la base de pruebas. El documento lo arma la app al cerrar.",
    },
    {
        "id": "revisar-sql",
        "nombre": "Revisar SQL",
        "hace": "Valida estructura y sintaxis de un script y dictamina el cambio contra PREVERSION o la última cerrada.",
        "motor": "cursor",
        "motores": ["cursor"],
        "modeloLocal": "",
        "nota": "Herramienta, no agente de rol. La oficina arma la diferencia y los avisos estáticos. No ejecuta el script.",
    },
]

# Perfiles antiguos -> (rol, modo). Las llamadas viejas siguen funcionando.
ALIAS = {
    "documentar": ("conocimiento", "normal"),
    "analista": ("requerimientos", "analisis"),
    "solicitar": ("requerimientos", "comite"),
    "contabilidad": ("requerimientos", "contable"),
    "soporte-consultas": ("consultas", "soporte"),
    "prueba-req": ("prueba-req", "prueba"),
}
# Motivo del turno -> modo, cuando quien llama usa el rol nuevo sin modo.
MODO_POR_MOTIVO = {
    "solicitar-req": "comite",
    "contabilidad": "contable",
    "soporte-consulta-analisis": "soporte",
    "soporte-consulta-chat": "soporte",
    "prueba-req": "prueba",
    "prueba-req-chat": "prueba",
}
# Corredor local existente por rol/modo (agente_oficina usa los nombres viejos).
_LOCAL_LEGACY = {
    ("conocimiento", "normal"): "documentar",
    ("consultas", "normal"): "consultas",
    ("requerimientos", "analisis"): "analista",
}


def resolver(agente_id: str, motivo: str = "") -> tuple[str, str]:
    """Devuelve (rol, modo) para un id nuevo o viejo."""
    aid = (agente_id or "").strip()
    if aid in ALIAS:
        rol, modo = ALIAS[aid]
        base = next((d for d in DEFINIDOS if d["id"] == rol), {})
        por_motivo = MODO_POR_MOTIVO.get(motivo or "")
        return rol, por_motivo if por_motivo in (base.get("modos") or []) else modo
    base = next((d for d in DEFINIDOS if d["id"] == aid), None)
    modos = (base or {}).get("modos") or [""]
    modo = MODO_POR_MOTIVO.get(motivo or "", modos[0])
    if modo not in modos:
        modo = modos[0]
    return aid, modo


# Pasos de cada agente. El motor guardado manda: local (esta PC) o Cursor.
# Mockup, flujo y documento los arma la oficina; no tienen motor de pago.
SUBAGENTES = [
    {"id": "solicitar-proceso", "padre": "requerimientos", "modo": "comite", "orden": 1, "nombre": "Proceso", "hace": "Ubica proceso y control con el índice de la base (_indice_busqueda.json).", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-pantalla", "padre": "requerimientos", "modo": "comite", "orden": 3, "nombre": "Pantalla", "hace": "Solo si la base no cubre: mira en Qrystalos2 los caminos del control.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-fichas", "padre": "requerimientos", "modo": "comite", "orden": 2, "nombre": "Fichas", "hace": "Lee SOLO las fichas SP/METODO del control (línea indicada por el índice), nunca el sps.json entero.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-desaix", "padre": "requerimientos", "modo": "comite", "orden": 5, "nombre": "DESAIX", "hace": "Compara PREVERSION con la última cerrada solo si la ficha no alcanza.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-redaccion", "padre": "requerimientos", "modo": "comite", "orden": 7, "nombre": "Redacción", "hace": "Escribe análisis, alcance, criterios y recomendación.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-documentacion", "padre": "requerimientos", "modo": "comite", "orden": 4, "nombre": "Documentación", "hace": "Solo para huecos: qrystalos.documentacion (tablas, runbooks).", "motor": "cursor", "motores": ["cursor"]},
    {"id": "solicitar-escalar", "padre": "requerimientos", "modo": "comite", "orden": 6, "nombre": "Escalar hueco", "hace": "Lo que la base no tiene va como handoff a Conocimiento (conocimiento/handoffs/cola.json).", "motor": "cursor", "motores": ["cursor"]},
    {"id": "solicitar-entregables", "padre": "requerimientos", "modo": "comite", "orden": 8, "nombre": "Mockup, flujo y documento", "hace": "La oficina arma el HTML con el texto ya escrito.", "motor": "local", "motores": ["local"]},
    {"id": "solicitar-chat", "padre": "requerimientos", "modo": "comite", "orden": 9, "nombre": "Chat", "hace": "Responde una duda o regenera la propuesta.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-proceso", "padre": "consultas", "modo": "normal", "orden": 1, "nombre": "Proceso", "hace": "Busca en conocimiento/_indice_busqueda.json y abre solo esa ficha.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-fichas", "padre": "consultas", "modo": "normal", "orden": 2, "nombre": "Fichas", "hace": "Responde solo con fichas 'leido' de ese proceso; cita SP/METODO.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-respuesta", "padre": "consultas", "modo": "normal", "orden": 3, "nombre": "Respuesta", "hace": "Redacta la respuesta del chat.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-escalar", "padre": "consultas", "modo": "normal", "orden": 4, "nombre": "Escalar", "hace": "Si la ficha falta o no es 'leido': handoff a Conocimiento. No abre Qrystalos2.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "soporte-indice", "padre": "consultas", "modo": "soporte", "orden": 1, "nombre": "Índice y fichas", "hace": "Contrasta la pregunta con la base vía índice.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "soporte-respuesta", "padre": "consultas", "modo": "soporte", "orden": 2, "nombre": "Respuesta oficial", "hace": "Redacta respuestaOficial y responde el chat de la consulta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "soporte-escalar", "padre": "consultas", "modo": "soporte", "orden": 3, "nombre": "Escalar", "hace": "Hueco en la base: handoff a Conocimiento.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "prueba-base", "padre": "prueba-req", "modo": "prueba", "orden": 1, "nombre": "Base", "hace": "Contrasta el requerimiento con la ficha del control.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "prueba-fuente", "padre": "prueba-req", "modo": "prueba", "orden": 2, "nombre": "Fuente", "hace": "Revisa en Qrystalos2 el cambio que el desarrollador dice haber hecho.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "prueba-desaix", "padre": "prueba-req", "modo": "prueba", "orden": 3, "nombre": "IXONLINE/SQL", "hace": "Compara PREVERSION con la última cerrada.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "prueba-bd", "padre": "prueba-req", "modo": "prueba", "orden": 4, "nombre": "Base de pruebas", "hace": "Valida con SELECT en el servidor y la base elegidos.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "prueba-veredicto", "padre": "prueba-req", "modo": "prueba", "orden": 5, "nombre": "Veredicto", "hace": "Deja Aprobado o Rechazado en el chat y en meta.json.", "motor": "cursor", "motores": ["cursor"]},
        {"id": "conocimiento-cola", "padre": "conocimiento", "modo": "normal", "orden": 0, "nombre": "Cola de handoffs", "hace": "Atiende primero los handoffs para Conocimiento (alta → baja) y responde en la cola.", "motor": "cursor", "motores": ["cursor"]},
{"id": "documentar-proceso", "padre": "conocimiento", "modo": "normal", "orden": 1, "nombre": "Proceso", "hace": "Confirma el proceso de la tarea.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-fichas", "padre": "conocimiento", "modo": "normal", "orden": 2, "nombre": "Fichas", "hace": "Lee lo ya documentado para no pisarlo.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-script", "padre": "conocimiento", "modo": "normal", "orden": 3, "nombre": "Script del día", "hace": "Lee el procedimiento vigente y, si falta, PREVERSION.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-ficha", "padre": "conocimiento", "modo": "normal", "orden": 4, "nombre": "Escribir ficha", "hace": "Completa métodos que aún no tienen texto.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "conocimiento-pendientes", "padre": "conocimiento", "modo": "normal", "orden": 5, "nombre": "Pendientes", "hace": "Sin cola ni tarea: toma el pendiente abierto de mayor prioridad (pendientes.json ya viene ordenado).", "motor": "cursor", "motores": ["cursor"]},
    {"id": "analista-proceso", "padre": "requerimientos", "modo": "analisis", "orden": 1, "nombre": "Proceso", "hace": "Ubica proceso y control con el índice de la base (_indice_busqueda.json).", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-pantalla", "padre": "requerimientos", "modo": "analisis", "orden": 3, "nombre": "Pantalla", "hace": "Solo si la base no cubre: mira en Qrystalos2 los caminos del control.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-fichas", "padre": "requerimientos", "modo": "analisis", "orden": 2, "nombre": "Fichas", "hace": "Lee SOLO las fichas SP/METODO del control (línea indicada por el índice), nunca el sps.json entero.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-desaix", "padre": "requerimientos", "modo": "analisis", "orden": 5, "nombre": "DESAIX", "hace": "Compara PREVERSION con la última cerrada solo si la ficha no alcanza.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-redaccion", "padre": "requerimientos", "modo": "analisis", "orden": 7, "nombre": "Redacción", "hace": "Completa criterios, alcance y recomendación si están vacíos.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-documentacion", "padre": "requerimientos", "modo": "analisis", "orden": 4, "nombre": "Documentación", "hace": "Solo para huecos: qrystalos.documentacion (tablas, runbooks).", "motor": "cursor", "motores": ["cursor"]},
    {"id": "analista-escalar", "padre": "requerimientos", "modo": "analisis", "orden": 6, "nombre": "Escalar hueco", "hace": "Lo que la base no tiene va como handoff a Conocimiento (conocimiento/handoffs/cola.json).", "motor": "cursor", "motores": ["cursor"]},
    {"id": "analista-chat", "padre": "requerimientos", "modo": "analisis", "orden": 8, "nombre": "Chat", "hace": "Responde el chat del caso.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "revisar-estructura", "padre": "revisar-sql", "orden": 1, "nombre": "Estructura y sintaxis", "hace": "Lee los avisos estáticos ya calculados. No vuelve a parsear el script.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-diff", "padre": "revisar-sql", "orden": 2, "nombre": "Cambios", "hace": "Lee la diferencia PREVERSION contra la última cerrada, o el archivo local contra el catálogo.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-efectos", "padre": "revisar-sql", "orden": 3, "nombre": "Efectos", "hace": "Dice si el cambio se ve correcto y qué efectos nocivos puede tener.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-chat", "padre": "revisar-sql", "orden": 4, "nombre": "Chat", "hace": "Responde una pregunta sobre esta misma revisión.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-factura", "padre": "requerimientos", "modo": "contable", "orden": 1, "nombre": "Factura", "hace": "SPK_NC_CONTAB_FTR. Variantes de DIAN, anticipo de impuestos, tipo y modelo.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-caja", "padre": "requerimientos", "modo": "contable", "orden": 2, "nombre": "Caja", "hace": "Cobro SPK_NC_CONTAB_CAJA_ING, pago SPK_NC_CONTAB_CAJA_EGR. La clase del recibo elige el procedimiento.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cxc", "padre": "requerimientos", "modo": "contable", "orden": 3, "nombre": "Recaudo", "hace": "SPK_NC_CONTAB_CXC. Impuesto, descuento y puente según la variable.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cxp", "padre": "requerimientos", "modo": "contable", "orden": 4, "nombre": "Cuenta por pagar", "hace": "SPK_NC_CONTAB_CXP. Fecha contable y tipo según la clase de la CxP.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-notdbcrcxp", "padre": "requerimientos", "modo": "contable", "orden": 5, "nombre": "Nota de CxP", "hace": "SPK_NC_CONTAB_CXPFNT. Inventario ligado e IVA de la nota.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-notdbcr", "padre": "requerimientos", "modo": "contable", "orden": 6, "nombre": "Nota de factura", "hace": "SPK_NC_CONTAB_FNOT. Cuenta del concepto de la nota.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-inv", "padre": "requerimientos", "modo": "contable", "orden": 7, "nombre": "Inventario", "hace": "SPK_NC_CONTAB_INV. KMCOM por tipo de movimiento, centro y área.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-bmov", "padre": "requerimientos", "modo": "contable", "orden": 8, "nombre": "Bancos", "hace": "SPK_NC_CONTAB_BMOV. El comprobante es BMOV.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-rglo", "padre": "requerimientos", "modo": "contable", "orden": 9, "nombre": "Glosa", "hace": "SPK_CONTAB_FGLO. Aceptada y recuperación usan cuentas distintas.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-conci", "padre": "requerimientos", "modo": "contable", "orden": 10, "nombre": "Conciliación", "hace": "SPK_CONTAB_CONCI. El cuerpo aún no está en la carpeta: se baja y se ficha en el primer errado.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-rad", "padre": "requerimientos", "modo": "contable", "orden": 11, "nombre": "Radicación", "hace": "SPK_CONTAB_RADICACXC en cero. Con abonos, SPK_CONTAB_RADICACXC_1.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-nomina", "padre": "requerimientos", "modo": "contable", "orden": 12, "nombre": "Nómina", "hace": "SPK_NC_CONTAB_NOMINA. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-anticipos", "padre": "requerimientos", "modo": "contable", "orden": 13, "nombre": "Anticipos", "hace": "SPK_NC_CONTAB_ANTICIPO. Débito del tipo de anticipo o de la CxP ligada.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-ajdep", "padre": "requerimientos", "modo": "contable", "orden": 14, "nombre": "Depreciación", "hace": "SPK_APL_AJDEPRECIACION. Tipo por sede o IDCON_TCOM_DEPR.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-iact", "padre": "requerimientos", "modo": "contable", "orden": 15, "nombre": "Activo", "hace": "SPK_CONTAB_IACT. El cuerpo aún no está en la carpeta. No es la depreciación del mes.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cesiones", "padre": "requerimientos", "modo": "contable", "orden": 16, "nombre": "Cesiones", "hace": "SPK_CONTAB_FCES. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-legalizacion", "padre": "requerimientos", "modo": "contable", "orden": 17, "nombre": "Legalización", "hace": "SPK_CONTAB_FLEG. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-reversos", "padre": "requerimientos", "modo": "contable", "orden": 18, "nombre": "Reversos", "hace": "SPK_REVERSAR_MCP. REVCAJAING, REVCAJAEGR y REVNOTDBCR.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-manual", "padre": "requerimientos", "modo": "contable", "orden": 19, "nombre": "Manual", "hace": "No se reconstruye. Se corrige en Movimiento Diario.", "motor": "cursor", "motores": ["cursor"]},
]


def _leer() -> dict:
    try:
        with open(RUTA, encoding="utf-8") as fh:
            datos = json.load(fh)
        if isinstance(datos, dict):
            return datos
    except (OSError, json.JSONDecodeError):
        pass
    return {"agentes": []}


def _guardar(datos: dict) -> None:
    os.makedirs(os.path.dirname(RUTA), exist_ok=True)
    with open(RUTA, "w", encoding="utf-8") as fh:
        json.dump(datos, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def catalogo() -> list[dict]:
    """Definidos en código, más los registrados solo en el JSON."""
    guardados = {a.get("id"): a for a in (_leer().get("agentes") or []) if a.get("id")}
    vistos = set()
    salida = []
    for base in DEFINIDOS:
        prev = guardados.get(base["id"]) or {}
        motores = list(base.get("motores") or ["cursor"])
        motor = prev.get("motor") if prev.get("motor") in motores else base.get("motor") or motores[0]
        fila = dict(base)
        fila["motor"] = motor
        fila["motores"] = motores
        subs = subagentes_de(base["id"])
        fila["subagentes"] = subs
        fila["subagentesTotal"] = len(subs)
        salida.append(fila)
        vistos.add(base["id"])
    for extra in _leer().get("agentes") or []:
        aid = extra.get("id")
        if not aid or aid in vistos or not extra.get("nombre"):
            continue
        motores = list(extra.get("motores") or ["cursor"])
        motor = extra.get("motor") if extra.get("motor") in motores else (motores[0] if motores else "cursor")
        fila = dict(extra)
        fila["motor"] = motor
        fila["motores"] = motores
        fila["subagentes"] = []
        fila["subagentesTotal"] = 0
        salida.append(fila)
    return salida


def _motores_sub_guardados() -> dict:
    salida = {}
    for fila in _leer().get("subagentes") or []:
        if fila.get("id") and fila.get("motor") in ("local", "cursor"):
            salida[fila["id"]] = fila["motor"]
    return salida


def subagentes_de(padre: str, modo: str | None = None) -> list[dict]:
    """Pasos de un rol (y modo). Acepta ids viejos: subagentes_de("solicitar") = requerimientos/comite."""
    if padre in ALIAS:
        padre, modo = ALIAS[padre]
    guardados = _motores_sub_guardados()
    salida = []
    for base in SUBAGENTES:
        if base.get("padre") != padre:
            continue
        if modo and base.get("modo") and base.get("modo") != modo:
            continue
        motores = list(base.get("motores") or ["cursor"])
        motor = guardados.get(base["id"], base.get("motor"))
        if motor not in motores:
            motor = motores[0]
        fila = dict(base)
        fila["motor"] = motor
        fila["motores"] = motores
        salida.append(fila)
    salida.sort(key=lambda fila: (fila.get("modo") or "", fila.get("orden") or 0))
    return salida


def publicar_plan(agente_id: str, id_caso: str, modo: str | None = None) -> str:
    """Deja el plan de pasos para que el turno de Cursor haga solo los suyos, en orden."""
    from cursor_bot import caso_dir

    rol, modo_def = resolver(agente_id)
    subs = subagentes_de(rol, modo or modo_def)
    lineas = [
        f"Plan de este turno. Agente: {rol} · modo: {modo or modo_def}.",
        "Orden de fuentes: base (índice → ficha puntual) → Qrystalos2 → qrystalos.documentacion → DESAIX. Hueco → handoff a Conocimiento.",
        "Haga solo los pasos marcados en Cursor.",
        "Un paso en local lo resuelve la oficina o se limita a la ficha de ese proceso: no lo rehaga ni reescriba sus campos.",
        "",
    ]
    for fila in subs:
        lineas.append(f"- {fila['nombre']} ({fila['id']}): {fila['motor']}. {fila['hace']}")
    path = os.path.join(caso_dir(id_caso), "notas-subagentes.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lineas) + "\n")
    return path


def modelo_local() -> str:
    nombre = str(_leer().get("modeloLocal") or "").strip()
    return nombre or "qwen2.5-coder:7b"


def sincronizar_opencode(modelo: str) -> None:
    """OpenCode queda en el mismo modelo local. Si no hay config, no hace nada."""
    perfil = (os.environ.get("USERPROFILE") or "").strip()
    if not perfil:
        return
    ruta = os.path.join(perfil, ".config", "opencode", "opencode.json")
    if not os.path.isfile(ruta):
        return
    try:
        with open(ruta, encoding="utf-8") as fh:
            datos = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(datos, dict):
        return
    datos["model"] = "ollama/" + modelo
    ollama = datos.setdefault("provider", {}).setdefault("ollama", {})
    ollama["models"] = {
        modelo: {
            "name": "Qwen 2.5 Coder 7B" if modelo.endswith(":7b") else modelo,
            "limit": {"context": 4096, "output": 2048},
        }
    }
    with open(ruta, "w", encoding="utf-8") as fh:
        json.dump(datos, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def asignar_modelo(nombre: str) -> str:
    nombre = (nombre or "").strip()
    if not nombre or any(c.isspace() for c in nombre):
        raise ValueError("Escriba el nombre del modelo, por ejemplo qwen2.5-coder:7b.")
    datos = _leer()
    datos["modeloLocal"] = nombre
    _guardar(datos)
    sincronizar_opencode(nombre)
    return nombre


def motor_de(agente_id: str) -> str:
    agente_id = ALIAS.get(agente_id, (agente_id,))[0]
    for fila in catalogo():
        if fila["id"] == agente_id:
            return fila["motor"]
    return "cursor"


def _persistir(filas: list[dict]) -> None:
    definidos = {d["id"] for d in DEFINIDOS}
    agentes = []
    for fila in filas:
        if fila["id"] in definidos:
            agentes.append({"id": fila["id"], "motor": fila["motor"]})
        else:
            agentes.append({
                "id": fila["id"],
                "nombre": fila.get("nombre") or "",
                "hace": fila.get("hace") or "",
                "motor": fila["motor"],
                "motores": fila.get("motores") or ["cursor"],
                "modeloLocal": fila.get("modeloLocal") or "",
                "nota": fila.get("nota") or "",
            })
    datos = _leer()
    datos["agentes"] = agentes
    _guardar(datos)


def asignar(agente_id: str, motor: str) -> dict:
    motor = (motor or "").strip().lower()
    sub = next((fila for fila in SUBAGENTES if fila["id"] == agente_id), None)
    if sub:
        if motor not in (sub.get("motores") or []):
            raise ValueError("Ese paso no corre en " + motor + ".")
        datos = _leer()
        items = [fila for fila in (datos.get("subagentes") or []) if fila.get("id") != agente_id]
        items.append({"id": agente_id, "motor": motor})
        datos["subagentes"] = items
        _guardar(datos)
        return next(fila for fila in subagentes_de(sub["padre"]) if fila["id"] == agente_id)
    filas = catalogo()
    encontrada = next((fila for fila in filas if fila["id"] == agente_id), None)
    if not encontrada:
        raise ValueError("Ese agente no está en el panel.")
    if motor not in (encontrada.get("motores") or []):
        raise ValueError("Ese agente todavía no puede correr en " + motor + ".")
    encontrada["motor"] = motor
    _persistir(filas)
    return encontrada


def registrar(agente: dict) -> dict:
    """Suma un agente que no está en DEFINIDOS. El panel lo lista al recargar."""
    aid = (agente.get("id") or "").strip()
    nombre = (agente.get("nombre") or "").strip()
    if not aid or not nombre:
        raise ValueError("El agente necesita id y nombre.")
    if any(d["id"] == aid for d in DEFINIDOS):
        raise ValueError("Ese agente ya está definido en el código.")
    motores = [m for m in (agente.get("motores") or ["cursor"]) if m in ("local", "cursor")] or ["cursor"]
    motor = agente.get("motor") if agente.get("motor") in motores else motores[0]
    datos = _leer()
    items = [a for a in (datos.get("agentes") or []) if a.get("id") != aid]
    items.append({
        "id": aid,
        "nombre": nombre,
        "hace": agente.get("hace") or "",
        "motor": motor,
        "motores": motores,
        "modeloLocal": agente.get("modeloLocal") or "",
        "nota": agente.get("nota") or "",
    })
    datos["agentes"] = items
    _guardar(datos)
    return next(fila for fila in catalogo() if fila["id"] == aid)


def lanzar(agente_id: str, id_caso: str, motivo: str, turno: str = "analizar") -> dict:
    """Acepta el rol nuevo o el perfil viejo. Mantiene los corredores que ya existían."""
    rol, modo = resolver(agente_id, motivo)
    if rol == "requerimientos" and modo == "comite":
        import agente_solicitud

        return agente_solicitud.lanzar(id_caso, turno)
    subs = subagentes_de(rol, modo)
    legacy_local = _LOCAL_LEGACY.get((rol, modo))
    if subs:
        motores = {fila["motor"] for fila in subs}
        if motores == {"local"} and legacy_local:
            import agente_oficina

            return agente_oficina.lanzar(legacy_local, id_caso, motivo)
        publicar_plan(rol, id_caso, modo)
        from cursor_bot import lanzar_bot

        return lanzar_bot(id_caso, motivo)
    motor = motor_de(rol)
    if motor == "local":
        if legacy_local:
            import agente_oficina

            return agente_oficina.lanzar(legacy_local, id_caso, motivo)
        return {
            "ok": False,
            "error": "sin_local",
            "detalle": "Este agente está marcado local, pero su corredor todavía no existe. Cámbielo a Cursor en el panel de agentes.",
        }
    from cursor_bot import lanzar_bot

    return lanzar_bot(id_caso, motivo)
