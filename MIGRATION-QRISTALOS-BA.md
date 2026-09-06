# Migración local: Quatec → Qrystalos BA / Local migration

## Español
Tras hacer pull de este cambio:

1. Renombrar la carpeta local `Qrys.Quatec` → `QrystalosBA` (ej. `C:\\DevQuasar\\Qrystalos\\QrystalosBA`).
2. Renombrar la base SQLite `data/quatec.db` → `data/qrystalos_ba.db` (o dejar que la app cree una nueva).
3. Esperar **localStorage fresco**: las claves `qrys_quatec_*` pasan a `qrystalos_ba_*`; limpie datos del sitio en el navegador si ve estado antiguo.
4. Scripts: `scripts/servir-qrystalos-ba.py`, `scripts/qrystalos_ba_db.py`; hooks `.cursor/hooks/sync-chat-qrystalos-ba.*`.

No cambiar: Qrystalos2, qrystalos.documentacion, ni el nombre del repo GitHub.

## English
After pulling this change:

1. Rename local folder `Qrys.Quatec` → `QrystalosBA` (e.g. `C:\\DevQuasar\\Qrystalos\\QrystalosBA`).
2. Rename SQLite DB `data/quatec.db` → `data/qrystalos_ba.db` (or let the app create a fresh one).
3. Expect **fresh localStorage**: keys `qrys_quatec_*` → `qrystalos_ba_*`; clear site data if you see stale state.
4. Scripts: `scripts/servir-qrystalos-ba.py`, `scripts/qrystalos_ba_db.py`; hooks `.cursor/hooks/sync-chat-qrystalos-ba.*`.

Do not change: Qrystalos2, qrystalos.documentacion, or the GitHub repo name.
