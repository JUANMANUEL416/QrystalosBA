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
        "id": "solicitar",
        "nombre": "Solicitud de requerimiento",
        "hace": "Analiza la necesidad, genera documento, mockup y flujo, y atiende el chat de ajustes.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "qwen2.5-coder:7b",
    },
    {
        "id": "consultas",
        "nombre": "Consultas",
        "hace": "Responde preguntas de un proceso con la base de conocimiento.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "nota": "En local responde con la ficha del proceso. No reescribe la base.",
    },
    {
        "id": "documentar",
        "nombre": "Documentar",
        "hace": "Lee el procedimiento del día y escribe la ficha en la base.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "nota": "En local completa métodos que aún no tienen ficha. No pisa una ficha ya leída.",
    },
    {
        "id": "analista",
        "nombre": "Analista de negocio",
        "hace": "Caso activo: activar, analizar el requerimiento, criterios y chat del dictamen.",
        "motor": "cursor",
        "motores": ["local", "cursor"],
        "modeloLocal": "",
        "nota": "En local llena campos vacíos y responde el chat. No sustituye un análisis ya escrito ni arma el dictamen HTML.",
    },
    {
        "id": "revisar-sql",
        "nombre": "Revisar SQL",
        "hace": "Valida estructura y sintaxis de un script y dictamina el cambio contra PREVERSION o la última cerrada.",
        "motor": "cursor",
        "motores": ["cursor"],
        "modeloLocal": "",
        "nota": "La oficina arma la diferencia y los avisos estáticos. El dictamen de lógica corre en Cursor. No ejecuta el script.",
    },
    {
        "id": "contabilidad",
        "nombre": "Contabilidad",
        "hace": "Recibe un comprobante errado, lo entrega al subagente de su procedencia y responde procedimiento, variable y corrección.",
        "motor": "cursor",
        "motores": ["cursor"],
        "modeloLocal": "",
        "nota": "No reabre el caso. La ficha de cada procedencia está en conocimiento/contabilidad/procedencias. Si la variante no está escrita, se lee el procedimiento una vez y se anota ahí.",
    },
    {
        "id": "soporte-consultas",
        "nombre": "Consultas soporte",
        "hace": "Contrasta la pregunta con conocimiento/, redacta respuestaOficial y responde en el chat de la consulta.",
        "motor": "cursor",
        "motores": ["cursor"],
        "modeloLocal": "",
        "nota": "Carpeta data/soporte-consultas/{id}. No dictamen HTML de analista.",
    },
]

# Pasos de cada agente. El motor guardado manda: local (esta PC) o Cursor.
# Mockup, flujo y documento los arma la oficina; no tienen motor de pago.
SUBAGENTES = [
    {"id": "solicitar-proceso", "padre": "solicitar", "orden": 1, "nombre": "Proceso", "hace": "Ubica el proceso y el control en la base.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-pantalla", "padre": "solicitar", "orden": 2, "nombre": "Pantalla", "hace": "Mira en Qrystalos2 si el camino ya existe.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-fichas", "padre": "solicitar", "orden": 3, "nombre": "Fichas", "hace": "Lee los procedimientos documentados de ese control.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-desaix", "padre": "solicitar", "orden": 4, "nombre": "DESAIX", "hace": "Compara PREVERSION con la última cerrada solo si la ficha no alcanza.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-redaccion", "padre": "solicitar", "orden": 5, "nombre": "Redacción", "hace": "Escribe análisis, alcance, criterios y recomendación.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "solicitar-entregables", "padre": "solicitar", "orden": 6, "nombre": "Mockup, flujo y documento", "hace": "La oficina arma el HTML con el texto ya escrito.", "motor": "local", "motores": ["local"]},
    {"id": "solicitar-chat", "padre": "solicitar", "orden": 7, "nombre": "Chat", "hace": "Responde una duda o regenera la propuesta.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-proceso", "padre": "consultas", "orden": 1, "nombre": "Proceso", "hace": "Ubica el proceso en el índice.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-fichas", "padre": "consultas", "orden": 2, "nombre": "Fichas", "hace": "Responde con la ficha de ese proceso.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "consultas-respuesta", "padre": "consultas", "orden": 3, "nombre": "Respuesta", "hace": "Redacta la respuesta del chat.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-proceso", "padre": "documentar", "orden": 1, "nombre": "Proceso", "hace": "Confirma el proceso de la tarea.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-fichas", "padre": "documentar", "orden": 2, "nombre": "Fichas", "hace": "Lee lo ya documentado para no pisarlo.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-script", "padre": "documentar", "orden": 3, "nombre": "Script del día", "hace": "Lee el procedimiento vigente y, si falta, PREVERSION.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "documentar-ficha", "padre": "documentar", "orden": 4, "nombre": "Escribir ficha", "hace": "Completa métodos que aún no tienen texto.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-proceso", "padre": "analista", "orden": 1, "nombre": "Proceso", "hace": "Ubica el proceso del caso.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-pantalla", "padre": "analista", "orden": 2, "nombre": "Pantalla", "hace": "Inventaría los caminos del control en Qrystalos2.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-fichas", "padre": "analista", "orden": 3, "nombre": "Fichas", "hace": "Usa los métodos documentados de ese control.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-desaix", "padre": "analista", "orden": 4, "nombre": "DESAIX", "hace": "Compara PREVERSION con la última cerrada si hay que releer el script.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-redaccion", "padre": "analista", "orden": 5, "nombre": "Redacción", "hace": "Completa criterios, alcance y recomendación si están vacíos.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "analista-chat", "padre": "analista", "orden": 6, "nombre": "Chat", "hace": "Responde el chat del caso.", "motor": "cursor", "motores": ["local", "cursor"]},
    {"id": "revisar-estructura", "padre": "revisar-sql", "orden": 1, "nombre": "Estructura y sintaxis", "hace": "Lee los avisos estáticos ya calculados. No vuelve a parsear el script.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-diff", "padre": "revisar-sql", "orden": 2, "nombre": "Cambios", "hace": "Lee la diferencia PREVERSION contra la última cerrada, o el archivo local contra el catálogo.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-efectos", "padre": "revisar-sql", "orden": 3, "nombre": "Efectos", "hace": "Dice si el cambio se ve correcto y qué efectos nocivos puede tener.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "revisar-chat", "padre": "revisar-sql", "orden": 4, "nombre": "Chat", "hace": "Responde una pregunta sobre esta misma revisión.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-factura", "padre": "contabilidad", "orden": 1, "nombre": "Factura", "hace": "SPK_NC_CONTAB_FTR. Variantes de DIAN, anticipo de impuestos, tipo y modelo.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-caja", "padre": "contabilidad", "orden": 2, "nombre": "Caja", "hace": "Cobro SPK_NC_CONTAB_CAJA_ING, pago SPK_NC_CONTAB_CAJA_EGR. La clase del recibo elige el procedimiento.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cxc", "padre": "contabilidad", "orden": 3, "nombre": "Recaudo", "hace": "SPK_NC_CONTAB_CXC. Impuesto, descuento y puente según la variable.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cxp", "padre": "contabilidad", "orden": 4, "nombre": "Cuenta por pagar", "hace": "SPK_NC_CONTAB_CXP. Fecha contable y tipo según la clase de la CxP.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-notdbcrcxp", "padre": "contabilidad", "orden": 5, "nombre": "Nota de CxP", "hace": "SPK_NC_CONTAB_CXPFNT. Inventario ligado e IVA de la nota.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-notdbcr", "padre": "contabilidad", "orden": 6, "nombre": "Nota de factura", "hace": "SPK_NC_CONTAB_FNOT. Cuenta del concepto de la nota.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-inv", "padre": "contabilidad", "orden": 7, "nombre": "Inventario", "hace": "SPK_NC_CONTAB_INV. KMCOM por tipo de movimiento, centro y área.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-bmov", "padre": "contabilidad", "orden": 8, "nombre": "Bancos", "hace": "SPK_NC_CONTAB_BMOV. El comprobante es BMOV.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-rglo", "padre": "contabilidad", "orden": 9, "nombre": "Glosa", "hace": "SPK_CONTAB_FGLO. Aceptada y recuperación usan cuentas distintas.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-conci", "padre": "contabilidad", "orden": 10, "nombre": "Conciliación", "hace": "SPK_CONTAB_CONCI. El cuerpo aún no está en la carpeta: se baja y se ficha en el primer errado.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-rad", "padre": "contabilidad", "orden": 11, "nombre": "Radicación", "hace": "SPK_CONTAB_RADICACXC en cero. Con abonos, SPK_CONTAB_RADICACXC_1.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-nomina", "padre": "contabilidad", "orden": 12, "nombre": "Nómina", "hace": "SPK_NC_CONTAB_NOMINA. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-anticipos", "padre": "contabilidad", "orden": 13, "nombre": "Anticipos", "hace": "SPK_NC_CONTAB_ANTICIPO. Débito del tipo de anticipo o de la CxP ligada.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-ajdep", "padre": "contabilidad", "orden": 14, "nombre": "Depreciación", "hace": "SPK_APL_AJDEPRECIACION. Tipo por sede o IDCON_TCOM_DEPR.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-iact", "padre": "contabilidad", "orden": 15, "nombre": "Activo", "hace": "SPK_CONTAB_IACT. El cuerpo aún no está en la carpeta. No es la depreciación del mes.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-cesiones", "padre": "contabilidad", "orden": 16, "nombre": "Cesiones", "hace": "SPK_CONTAB_FCES. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-legalizacion", "padre": "contabilidad", "orden": 17, "nombre": "Legalización", "hace": "SPK_CONTAB_FLEG. El cuerpo aún no está en la carpeta.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-reversos", "padre": "contabilidad", "orden": 18, "nombre": "Reversos", "hace": "SPK_REVERSAR_MCP. REVCAJAING, REVCAJAEGR y REVNOTDBCR.", "motor": "cursor", "motores": ["cursor"]},
    {"id": "contab-manual", "padre": "contabilidad", "orden": 19, "nombre": "Manual", "hace": "No se reconstruye. Se corrige en Movimiento Diario.", "motor": "cursor", "motores": ["cursor"]},
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


def subagentes_de(padre: str) -> list[dict]:
    guardados = _motores_sub_guardados()
    salida = []
    for base in SUBAGENTES:
        if base.get("padre") != padre:
            continue
        motores = list(base.get("motores") or ["cursor"])
        motor = guardados.get(base["id"], base.get("motor"))
        if motor not in motores:
            motor = motores[0]
        fila = dict(base)
        fila["motor"] = motor
        fila["motores"] = motores
        salida.append(fila)
    salida.sort(key=lambda fila: fila.get("orden") or 0)
    return salida


def publicar_plan(agente_id: str, id_caso: str) -> str:
    """Deja el plan de motores para que el turno de Cursor haga solo sus pasos."""
    from cursor_bot import caso_dir

    subs = subagentes_de(agente_id)
    lineas = [
        "Plan de este turno.",
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
    """Si hay subagentes, manda el motor de cada paso. Si no, el del agente."""
    subs = subagentes_de(agente_id)
    if subs and agente_id == "solicitar":
        import agente_solicitud

        return agente_solicitud.lanzar(id_caso, turno)
    if subs:
        motores = {fila["motor"] for fila in subs}
        if motores == {"local"}:
            import agente_oficina

            return agente_oficina.lanzar(agente_id, id_caso, motivo)
        publicar_plan(agente_id, id_caso)
        from cursor_bot import lanzar_bot

        return lanzar_bot(id_caso, motivo)
    motor = motor_de(agente_id)
    if motor == "local":
        if agente_id in ("consultas", "documentar", "analista"):
            import agente_oficina

            return agente_oficina.lanzar(agente_id, id_caso, motivo)
        return {
            "ok": False,
            "error": "sin_local",
            "detalle": "Este agente está marcado local, pero su corredor todavía no existe. Cámbielo a Cursor en el panel de agentes.",
        }
    from cursor_bot import lanzar_bot

    return lanzar_bot(id_caso, motivo)
