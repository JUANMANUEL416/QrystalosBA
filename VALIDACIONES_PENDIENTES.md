# Validaciones Pendientes en Base de Pruebas

Este documento lista elementos que no se pudieron confirmar completamente en la base de conocimiento (`conocimiento/`) y requieren validación en la base de pruebas del usuario.

## Variables de Configuración

### DEINVNODESER
- **Bloque:** tipos-de-articulo-itar, articulos-iart, servicios-ser, articulo-por-bodega-idxb
- **Descripción:** Define artículos que NO generan servicio al crear
- **Valor:** Pendiente validar
- **Acción requerida:** Verificar en USVGS de la base de pruebas qué valor tiene esta variable y qué tipos de artículo excluye de la generación automática de servicios (SER)

## Ejemplos de Tipos de Artículo

Los siguientes tipos de artículo se documentaron basándose en el contexto del sector salud (IPS/hospital en Colombia), pero deben verificarse contra los tipos configurados en la base de pruebas:

1. **Medicamentos** (loteo + vencimiento + IVA)
   - Ejemplos: analgésicos, antibióticos, antiinflamatorios
   - Validar: ¿El PRECNS es "MED"? ¿Qué otros prefijos se usan?

2. **Dispositivos médicos** (solo loteo)
   - Ejemplos: jeringas, equipos de venoclisis, sondas
   - Validar: ¿Existe este tipo? ¿Cuál es su PRECNS?

3. **Material médico-quirúrgico** (sin loteo ni vencimiento)
   - Ejemplos: instrumental quirúrgico, equipos
   - Validar: ¿Existe este tipo? ¿Cuál es su configuración?

4. **Reactivos de laboratorio** (loteo + vencimiento)
   - Ejemplos: reactivos químicos, kits de diagnóstico
   - Validar: ¿Existe este tipo? ¿Maneja IVA?

5. **Insumos de nutrición** (loteo + vencimiento)
   - Ejemplos: suplementos nutricionales, fórmulas enterales
   - Validar: ¿Existe este tipo? ¿Cuál es su PRECNS?

6. **Papelería y aseo** (sin loteo ni vencimiento)
   - Ejemplos: papel, jabones, desinfectantes
   - Validar: ¿Existe este tipo? ¿Maneja IVA?

## Ilustraciones Generadas

Las ilustraciones se generan con IA (Gemini/OpenAI) usando prompts endurecidos que:
- ✅ Incluyen contexto: "hospital inventory management system (IPS/hospital Colombia)"
- ✅ Especifican: "pharmacy warehouse, medications, medical devices, surgical supplies"
- ✅ Prohiben: "flags, language symbols, weapons, ammunition, military items"

**Acción requerida:** Al generar documentos, verificar que las ilustraciones reflejen el contexto de salud (farmacia/almacén hospitalario) y NO contengan elementos fuera de contexto.

## Proceso de Validación

1. **Acceder a la base de pruebas** del usuario
2. **Revisar USVGS** (`/conf/usvgs`) para:
   - Variable DEINVNODESER: valor y efecto
   - Otras variables de inventario no documentadas
3. **Revisar ITAR** (`/inv/conf/itar`) para:
   - Tipos de artículo configurados
   - Prefijos (PRECNS) usados
   - Configuración de loteo/vencimiento/IVA por tipo
4. **Actualizar documentación** con los valores reales
5. **Actualizar bloques** de capacitación con ejemplos validados

---

**Nota:** Los valores marcados como "habitual" en las tablas de variables son los códigos más comunes según la base de conocimiento, pero cada institución puede configurar los propios.
