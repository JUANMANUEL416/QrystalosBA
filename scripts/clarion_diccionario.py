# -*- coding: utf-8 -*-
"""Arma el catálogo de tablas desde los .clw generados por los 4 diccionarios Clarion.

Los .dct de C:\\DEV11.1\\KrystalosCol_2024.04 son binarios. La declaración legible
(nombre SQL, rótulo de pantalla y campos) está en la región «File Declaration»
de cada .clw. Se cruza con el catálogo físico de qrystalos.documentacion.

Salida: conocimiento/diccionario/
Uso: python scripts/clarion_diccionario.py
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT_CLARION = Path(r"C:\DEV11.1\KrystalosCol_2024.04")
ROOT_BA = Path(r"C:\DevQuasar\Qrystalos\QrystalosBA")
ROOT_DOC = Path(r"C:\DevQuasar\Qrystalos\qrystalos.documentacion")
OUT = ROOT_BA / "conocimiento" / "diccionario"

DCT_NOMBRE = {
    "Krystalos2024_04.dct": "principal",
    "krys2_2024_04.dct": "krys2",
    "Krys3_2024_04.dct": "krys3",
    "KPresup2024_04.dct": "presupuesto",
}

FILE_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\s+FILE,DRIVER\('([^']*)'",
)
FIELD_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\s+"
    r"(CSTRING|STRING|BYTE|SHORT|USHORT|LONG|ULONG|DECIMAL|PDECIMAL|"
    r"DATE|TIME|REAL|SREAL|BFLOAT|MEMO|BLOB|BOOL|GROUP)\b(.*)$",
    re.IGNORECASE,
)
NAME_RE = re.compile(r"NAME\('([^']*)'\)")
PRE_RE = re.compile(r"PRE\(([A-Za-z_][A-Za-z0-9_]*)\)")
IDX_ROW_RE = re.compile(r"`([A-Za-z_][A-Za-z0-9_]*)`\s*\|\s*([^|\n]+)")


def leer(path: Path) -> str:
    return path.read_text(encoding="cp1252", errors="replace")


def apps_por_diccionario() -> dict[str, str]:
    """Nombre de .app (sin extensión) → id de diccionario (principal, krys2…)."""
    mapa: dict[str, str] = {}
    needles = {nombre.encode("ascii"): clave for nombre, clave in DCT_NOMBRE.items()}
    for app in ROOT_CLARION.glob("*.app"):
        data = app.read_bytes()
        for raw, clave in needles.items():
            if raw in data:
                mapa[app.stem] = clave
                break
    return mapa


def dueno_app(stem: str, apps_largas: list[str]) -> str | None:
    for app in apps_largas:
        if stem == app or (stem.startswith(app) and stem[len(app) :].isdigit()):
            return app
    return None


def tablas_sql() -> set[str]:
    text = (ROOT_DOC / "tablas.rpt").read_text(encoding="utf-8-sig", errors="replace")
    nombres = set()
    for linea in text.splitlines():
        partes = linea.split()
        if len(partes) >= 2 and partes[0].lower() == "dbo" and partes[1] != "TABLE_NAME":
            nombres.add(partes[1].upper())
    return nombres


def columnas_sql() -> dict[str, list[dict]]:
    text = (ROOT_DOC / "columnas_por_tabla.rpt").read_text(encoding="utf-8-sig", errors="replace")
    por_tabla: dict[str, list[dict]] = defaultdict(list)
    vistos: dict[str, set[str]] = defaultdict(set)
    for linea in text.splitlines():
        partes = linea.split()
        if len(partes) < 4 or partes[0].lower() != "dbo":
            continue
        if partes[1] == "TABLE_NAME" or partes[2] == "COLUMN_NAME":
            continue
        tabla, campo, tipo = partes[1].upper(), partes[2].upper(), partes[3].lower()
        longitud = partes[4] if len(partes) >= 5 and partes[4] not in {"-", "NULL"} else ""
        if not longitud.lstrip("-").isdigit():
            longitud = ""
        if campo in vistos[tabla]:
            continue
        vistos[tabla].add(campo)
        tipo_sql = f"{tipo}({longitud})" if longitud and tipo in {"varchar", "nvarchar", "char", "nchar"} else tipo
        por_tabla[tabla].append({"campo": campo, "tipoSql": tipo_sql})
    return por_tabla


def descripciones_indice() -> dict[str, str]:
    text = (ROOT_DOC / "INDICE_TABLAS.md").read_text(encoding="utf-8", errors="replace")
    out: dict[str, str] = {}
    for nombre, desc in IDX_ROW_RE.findall(text):
        desc = " ".join(desc.split())
        if not desc or desc == "-" or desc.startswith("["):
            continue
        out.setdefault(nombre.upper(), desc)
    return out


def fichas() -> set[str]:
    carpeta = ROOT_DOC / "tablas"
    return {p.stem.upper() for p in carpeta.glob("*.md")}


def parse_region(texto: str) -> list[dict]:
    ini = texto.find("!region File Declaration")
    if ini < 0:
        return []
    fin = texto.find("!endregion", ini)
    if fin < 0:
        fin = len(texto)
    tablas = []
    actual = None
    en_registro = False
    profundidad = 0
    for linea in texto[ini:fin].splitlines():
        cruda = linea.rstrip()
        recortada = cruda.strip()
        mfile = FILE_RE.match(recortada)
        if mfile and "FILE,DRIVER" in recortada:
            if actual:
                tablas.append(actual)
            etiqueta, driver = mfile.group(1), mfile.group(2).upper()
            nombre_m = NAME_RE.search(recortada)
            pre_m = PRE_RE.search(recortada)
            desc = recortada.split("!", 1)[1].strip() if "!" in recortada else ""
            sql = nombre_m.group(1).strip() if nombre_m else ""
            if sql.upper().startswith("DBO."):
                sql = sql[4:]
            actual = {
                "etiqueta": etiqueta,
                "driver": driver,
                "nombre": sql.upper() if sql else "",
                "canonica": etiqueta.upper() == sql.upper() if sql else False,
                "prefijo": pre_m.group(1).upper() if pre_m else "",
                "descripcion": " ".join(desc.split()),
                "campos": [],
            }
            en_registro = False
            profundidad = 0
            continue
        if actual is None:
            continue
        if not en_registro:
            if recortada.upper().startswith("RECORD") and "RECORD" in recortada.upper():
                en_registro = True
                profundidad = 1
            continue
        if recortada.upper() == "END":
            profundidad -= 1
            if profundidad <= 0:
                en_registro = False
            continue
        mcampo = FIELD_RE.match(recortada)
        if not mcampo:
            continue
        nombre, tipo, resto = mcampo.group(1), mcampo.group(2).upper(), mcampo.group(3)
        if tipo == "GROUP":
            profundidad += 1
            continue
        rotulo = resto.split("!", 1)[1].strip() if "!" in resto else ""
        externo = NAME_RE.search(resto)
        campo = (externo.group(1) if externo else nombre).upper()
        if any(c["campo"] == campo for c in actual["campos"]):
            continue
        tipo_clarion = (tipo + resto.split("!")[0].strip()).strip()
        actual["campos"].append(
            {
                "campo": campo,
                "rotulo": " ".join(rotulo.split()),
                "tipoClarion": " ".join(tipo_clarion.split()),
            }
        )
    if actual:
        tablas.append(actual)
    return tablas


def main() -> None:
    apps = apps_por_diccionario()
    apps_largas = sorted(apps, key=len, reverse=True)
    sql_tablas = tablas_sql()
    sql_columnas = columnas_sql()
    indice_doc = descripciones_indice()
    con_ficha = fichas()

    # nombre SQL -> acumulado
    acum: dict[str, dict] = {}
    otras = []
    regiones = 0
    for clw in ROOT_CLARION.glob("*.clw"):
        texto = leer(clw)
        if "!region File Declaration" not in texto:
            continue
        regiones += 1
        app = dueno_app(clw.stem, apps_largas)
        dic = apps.get(app, "") if app else ""
        for tabla in parse_region(texto):
            if tabla["driver"] != "MSSQL" or not tabla["nombre"]:
                if tabla["nombre"] or tabla["etiqueta"]:
                    otras.append(tabla["driver"])
                continue
            nombre = tabla["nombre"]
            prev = acum.get(nombre)
            if prev is None:
                acum[nombre] = {
                    "nombre": nombre,
                    "descripcion": tabla["descripcion"],
                    "prefijo": tabla["prefijo"],
                    "diccionarios": {dic} if dic else set(),
                    "campos": list(tabla["campos"]),
                    "canonica": tabla["canonica"],
                }
                continue
            if dic:
                prev["diccionarios"].add(dic)
            if not prev["prefijo"] and tabla["prefijo"]:
                prev["prefijo"] = tabla["prefijo"]
            # La declaración cuyo nombre Clarion coincide con la tabla SQL
            # es la ficha; el alias («Alias Afiliados») no la reemplaza.
            if tabla["canonica"] and not prev["canonica"]:
                prev["canonica"] = True
                prev["campos"] = list(tabla["campos"])
                if tabla["prefijo"]:
                    prev["prefijo"] = tabla["prefijo"]
                if tabla["descripcion"]:
                    prev["descripcion"] = tabla["descripcion"]
            elif tabla["canonica"] == prev["canonica"]:
                if len(tabla["campos"]) > len(prev["campos"]):
                    prev["campos"] = list(tabla["campos"])
                if tabla["descripcion"] and (
                    not prev["descripcion"]
                    or (
                        not tabla["descripcion"].lower().startswith("alias")
                        and (
                            prev["descripcion"].lower().startswith("alias")
                            or len(tabla["descripcion"]) > len(prev["descripcion"])
                        )
                    )
                ):
                    prev["descripcion"] = tabla["descripcion"]

    OUT.mkdir(parents=True, exist_ok=True)
    previas: dict[str, dict] = {}
    indice_previo = OUT / "indice.json"
    if indice_previo.exists():
        cargado = json.loads(indice_previo.read_text(encoding="utf-8"))
        for fila_previa in cargado.get("tablas", []):
            previas[str(fila_previa.get("nombre", "")).upper()] = fila_previa
    indice = []
    lineas_campos = []
    for nombre in sorted(set(acum) | sql_tablas):
        clarion = acum.get(nombre)
        columnas = sql_columnas.get(nombre, [])
        en_sql = nombre in sql_tablas
        en_clarion = clarion is not None
        desc = ""
        prefijo = ""
        dics: list[str] = []
        campos_c: list[dict] = []
        if clarion:
            desc = clarion["descripcion"]
            prefijo = clarion["prefijo"]
            dics = sorted(x for x in clarion["diccionarios"] if x)
            campos_c = clarion["campos"]
        if not desc:
            desc = indice_doc.get(nombre, "")
        vistos = set()
        campos_out = []
        for campo in campos_c:
            sqlc = next((c for c in columnas if c["campo"] == campo["campo"]), None)
            vistos.add(campo["campo"])
            campos_out.append(
                {
                    "campo": campo["campo"],
                    "rotulo": campo["rotulo"],
                    "tipoClarion": campo["tipoClarion"],
                    "tipoSql": sqlc["tipoSql"] if sqlc else "",
                }
            )
        for col in columnas:
            if col["campo"] in vistos:
                continue
            campos_out.append(
                {
                    "campo": col["campo"],
                    "rotulo": "",
                    "tipoClarion": "",
                    "tipoSql": col["tipoSql"],
                }
            )
        anterior = previas.get(nombre)
        if anterior and anterior.get("origen") == "lectura-sp" and anterior.get("descripcion") and not desc:
            desc = anterior["descripcion"]
        fila = {
            "nombre": nombre,
            "descripcion": desc,
            "tipo": "vista" if nombre.startswith("VWK") else "tabla",
            "prefijo": prefijo,
            "diccionarios": dics,
            "enSql": en_sql,
            "enClarion": en_clarion,
            "ficha": nombre in con_ficha,
            "campos": len(campos_out),
        }
        if anterior and anterior.get("origen") == "lectura-sp":
            fila["origen"] = "lectura-sp"
            if anterior.get("procesoId"):
                fila["procesoId"] = anterior["procesoId"]
            if anterior.get("etiquetaPendiente"):
                fila["etiquetaPendiente"] = True
        indice.append(fila)
        for campo in campos_out:
            lineas_campos.append(
                json.dumps({"tabla": nombre, **campo}, ensure_ascii=False)
            )

    ya = {f["nombre"] for f in indice}
    for nombre, anterior in previas.items():
        if nombre in ya or anterior.get("origen") != "lectura-sp":
            continue
        fila = dict(anterior)
        fila["tipo"] = "vista" if nombre.startswith("VWK") else fila.get("tipo") or "tabla"
        indice.append(fila)
    indice.sort(key=lambda f: f["nombre"])

    por_dic = defaultdict(list)
    for app, dic in sorted(apps.items()):
        por_dic[dic].append(app)

    def cuenta(pred):
        return sum(1 for f in indice if pred(f))

    resumen = {
        "generado": datetime.now().replace(microsecond=0).isoformat(),
        "fuenteClarion": str(ROOT_CLARION),
        "nota": "Los .dct son binarios. Las descripciones salen del comentario de cada FILE/campo en los .clw generados.",
        "regionesLeidas": regiones,
        "aplicacionesPorDiccionario": {k: sorted(v) for k, v in por_dic.items()},
        "tablas": len(indice),
        "enClarionYSql": cuenta(lambda f: f["enClarion"] and f["enSql"]),
        "soloClarion": cuenta(lambda f: f["enClarion"] and not f["enSql"]),
        "soloSql": cuenta(lambda f: f["enSql"] and not f["enClarion"]),
        "conRotuloClarion": cuenta(lambda f: f["enClarion"] and bool(f["descripcion"])),
        "conFicha": cuenta(lambda f: f["ficha"]),
        "vistas": cuenta(lambda f: f.get("tipo") == "vista"),
        "campos": len(lineas_campos),
        "declaracionesNoMssql": len(otras),
    }
    (OUT / "indice.json").write_text(
        json.dumps({"resumen": {k: resumen[k] for k in resumen if k != "aplicacionesPorDiccionario"}, "tablas": indice}, ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )
    (OUT / "campos.jsonl").write_text("\n".join(lineas_campos) + "\n", encoding="utf-8")
    (OUT / "diccionarios.json").write_text(
        json.dumps(
            {
                "generado": resumen["generado"],
                "diccionarios": [
                    {
                        "id": clave,
                        "archivo": archivo,
                        "aplicaciones": sorted(por_dic.get(clave, [])),
                    }
                    for archivo, clave in DCT_NOMBRE.items()
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (OUT / "resumen.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: resumen[k] for k in resumen if k != "aplicacionesPorDiccionario"}, ensure_ascii=False, indent=2))
    for clave, lista in sorted(por_dic.items()):
        print(f"{clave}: {len(lista)} apps")


if __name__ == "__main__":
    main()
