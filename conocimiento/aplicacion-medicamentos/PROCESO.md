# Aplicación de medicamentos

Consulta externa → Aplicación de medicamentos (`/ce/aplim`).

Sirve para el ciclo en el que un paciente recibe un medicamento en el servicio (por ejemplo una aplicación ambulatoria), no para la venta de mostrador ni para la entrada de custodia.

## Qué hace la persona

1. Abre **Aplicaciones** y busca o crea el ciclo del paciente: servicio, plan, tercero y autorización.
2. En el ciclo abre cada fecha. Ahí está la cita, la vía, la cantidad y si ya se aplicó.
3. Si el evento lleva insumos, los ve en el detalle. Esos insumos pueden pedir una solicitud a farmacia. La existencia baja cuando farmacia dispensa, no en esta pantalla.
4. Con permiso de agenda, programa o reprograma la cita.
5. Si la institución usa seguimiento AUTE y la variable está en SI, registra las gestiones del paciente en **Seguimiento**.

## Qué queda guardado

- El ciclo es `APLI`.
- Cada fecha es `APLIM`.
- Cada insumo es `APLIMF`. Si ya fue a farmacia, trae el número de solicitud.
- La bitácora del evento es `APLIMG`.
- El seguimiento AUTE es `APLIS`.

## Dónde sigue

Si el insumo debe salir de bodega, el camino es **Dispensación**. Si el medicamento es del paciente y no del hospital, el camino es **Custodia**.
