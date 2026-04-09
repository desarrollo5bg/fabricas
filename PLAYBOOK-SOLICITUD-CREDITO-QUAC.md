# Playbook — Solicitud de Crédito QUAC

> **Versión:** 0.1 (borrador inicial)
> **Fecha:** 2026-04-09
> **Audiencia:** Encargada de procesos de crédito, equipo de crédito, equipo de cartera
> **Propósito:** Explicar cómo queremos que funcione el proceso de solicitud de crédito QUAC en los dos canales (tienda física y preaprobado.quac.co), cuál es el ciclo de vida de un estudio, y cómo se gestionan los casos que requieren validación humana en la fábrica de créditos.
> **Estado:** Borrador para revisión. Hay decisiones marcadas como `[POR DEFINIR]` y `[PROPUESTA]` que necesitan tu validación.

---

## Índice

1. [Panorama general](#1-panorama-general)
2. [Conceptos clave](#2-conceptos-clave)
3. [La ficha de estudio](#3-la-ficha-de-estudio)
4. [Flujo en tienda física](#4-flujo-en-tienda-física)
5. [Flujo en canal web (preaprobado.quac.co)](#5-flujo-en-canal-web-preaprobadoquacco)
6. [Ciclo de vida del estudio](#6-ciclo-de-vida-del-estudio)
7. [Validación humana en la Fábrica de Créditos](#7-validación-humana-en-la-fábrica-de-créditos)

---

## 1. Panorama general

QUAC permite que un cliente solicite un cupo de crédito para financiar sus compras en las tiendas aliadas. Hoy este proceso se hace principalmente en tienda física con intervención de un asesor, y en menor medida desde el portal web `preaprobado.quac.co` donde el cliente se autogestiona.

**El objetivo de este playbook** es explicar cómo queremos que funcione ese proceso, definir claramente qué es un estudio de crédito, cómo se captura la información en cada canal, qué reglas aplican cuando un estudio se queda a medias, y cómo la Fábrica de Créditos interviene cuando un caso requiere revisión humana.

### Canales

Existen **dos canales principales** por los que un cliente puede solicitar cupo:

| Canal                         | Quién guía el proceso              | Ritmo esperado                                                             | Contexto                                                                                            |
| ----------------------------- | ---------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Tienda física**             | Un cajero/asesor frente al cliente | Rápido — el cliente quiere salir con su cupo activado para pagar su compra | Presión por cerrar rápido. El cliente tiene su documento físico en la mano. El asesor captura todo. |
| **Web (preaprobado.quac.co)** | El cliente se autogestiona         | Más relajado — el cliente puede tomarse su tiempo                          | Menos fricción inicial para no perder al cliente. Menos datos al principio, más después.            |

Ambos canales **terminan en el mismo resultado**: un cupo aprobado y activado en el sistema. Lo que cambia es **cómo y en qué orden** se captura la información.

> **Nota:** Existe también un tercer canal ("Externos", donde un asesor de campo busca clientes y registra desde su celular). Ese canal **no está cubierto en este playbook** por ahora — se atenderá en un documento aparte. `[POR DEFINIR]` si después se integra aquí o queda independiente.

---

## 2. Conceptos clave

Antes de entrar al detalle del flujo, hay cuatro conceptos que tenemos que dejar bien claros porque todo el playbook se construye sobre ellos.

### 2.1 Pre-estudio vs. Estudio

Esta es la distinción más importante del documento.

| Concepto        | Qué es                                                                                                                                                                       | Cuándo ocurre                                                                           |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Pre-estudio** | El proceso de preparación: identificar al cliente, capturar sus datos básicos, hacer que firme T&C y tokenice su celular. Es armar la "ficha" para poder iniciar el estudio. | Desde que el cliente dice "quiero cupo" hasta el momento antes de consultar Preselecta. |
| **Estudio**     | El proceso de evaluación crediticia propiamente dicho: Preselecta, antecedentes, FOSYGA, verificación de identidad, UBICA, activación.                                       | Desde que se consulta Preselecta hasta que el cupo se activa o el estudio se cierra.    |

**¿Por qué separar?** Porque el estudio **nace cuando Preselecta responde**. Antes de eso no hay un registro formal de crédito, solo una intención del cliente que puede abandonarse sin consecuencias. Esto tiene implicaciones prácticas:

- Un cliente que entra a la tienda, digita su documento y se va sin continuar **no deja un estudio fallido** en nuestras estadísticas. Deja un registro de "intento" en un log, pero no inflar los números de rechazos.
- Un cliente que completa el pre-estudio pero cuyo Preselecta retorna "no viable" **sí genera un estudio** (que nace ya cerrado con estado `cerrado_no_viable`).

### 2.2 Ficha de estudio

La **ficha** es el conjunto de información necesaria para ejecutar un estudio completo. Es la misma en ambos canales — lo que cambia es **cuándo y en qué orden se captura** cada dato. La ficha completa se describe en la [sección 3](#3-la-ficha-de-estudio).

### 2.3 Estado global vs. paso actual

Un estudio tiene **dos dimensiones de estado** que no hay que confundir:

| Dimensión         | Qué responde                             | Ejemplo                                                                         |
| ----------------- | ---------------------------------------- | ------------------------------------------------------------------------------- |
| **Estado global** | ¿En qué "buzón" vive el estudio?         | `activo` o `cerrado` (con 5 sub-estados) |
| **Paso actual**   | Dentro del flujo, ¿dónde quedó la aguja? | `pendiente dirección`, `pendiente foto frontal`, `esperando UBICA`, etc.        |

El paso actual solo tiene sentido mientras el estudio está `activo`. En estado `cerrado`, el paso queda congelado como "último punto alcanzado antes del cierre".

**Ejemplo:** un cliente en la tienda tuvo que salir de urgencia y dejó su estudio justo cuando le iban a pedir la dirección. El estado de su estudio es:

- Estado global: `activo`
- Situación: `esperando cliente`
- Paso actual: `pendiente dirección`

Si vuelve en 24 horas, el sistema lo reconoce, le pide un OTP al celular que ya había tokenizado, y lo deja continuar exactamente en "pendiente dirección" sin re-hacer nada de lo anterior.

### 2.4 Ciclo de vida del estudio

El ciclo de vida se explica en detalle en la [sección 6](#6-ciclo-de-vida-del-estudio). Por ahora basta decir que un estudio tiene un inicio (Preselecta) y termina en alguno de los 5 sub-estados de `cerrado`. Mientras no se cierre, el estudio sigue `activo` (aunque su situación puede cambiar: en interacción, esperando cliente, en fábrica, esperando servicio). Un cliente puede tener muchos estudios a lo largo de su vida con QUAC, pero **solo uno puede estar `activo` a la vez**.

---

## 3. La ficha de estudio

La ficha es el conjunto de información que QUAC necesita para decidir si aprueba o no un cupo a un cliente. Es la misma ficha en ambos canales — lo que cambia es el orden en que se captura cada dato y cuánta fricción se mete al cliente en cada paso.

### 3.1 Contenido de la ficha

Todos los campos son obligatorios para que el estudio pueda ejecutarse. Lo que cambia entre canales es el momento y la forma de captura.

| #   | Categoría            | Campo                                    | ¿Obligatorio?               | ¿Cómo se obtiene?                               |
| --- | -------------------- | ---------------------------------------- | --------------------------- | ----------------------------------------------- |
| 1   | **Identificación**   | Tipo de documento                        | ✅                          | Ingreso manual                                  |
| 2   | **Identificación**   | Número de documento                      | ✅                          | Ingreso manual                                  |
| 3   | **Datos personales** | Nombres                                  | ✅                          | OCR (preferido) o manual                        |
| 4   | **Datos personales** | Apellidos                                | ✅                          | OCR (preferido) o manual                        |
| 5   | **Datos personales** | Género                                   | ✅                          | OCR (preferido) o manual                        |
| 6   | **Datos personales** | Fecha de nacimiento                      | ✅                          | OCR (preferido) o manual                        |
| 7   | **Documento**        | Fecha de expedición                      | ✅                          | OCR del frente o manual                         |
| 8   | **Documento**        | Ciudad de expedición                     | ✅                          | OCR del **reverso** o manual                    |
| 9   | **Contacto**         | Celular                                  | ✅                          | Manual + verificación OTP                       |
| 10  | **Contacto**         | Correo electrónico                       | ✅                          | Manual + verificación OTP                       |
| 11  | **Residencia**       | Departamento                             | ✅                          | Manual (lista desplegable DANE)                 |
| 12  | **Residencia**       | Ciudad                                   | ✅                          | Manual (lista desplegable DANE)                 |
| 13  | **Residencia**       | Dirección                                | ✅                          | Manual                                          |
| 14  | **Evidencia**        | Foto frontal del documento               | ✅                          | Cámara del asesor o cámara del cliente vía link |
| 15  | **Evidencia**        | Foto posterior del documento             | ✅                          | Cámara del asesor o cámara del cliente vía link |
| 16  | **Evidencia**        | Selfie (prueba de vida)                  | ✅                          | Cámara del asesor o cámara del cliente vía link |
| 17  | **Autorizaciones**   | Aceptación T&C                           | ✅                          | Checkbox + firma electrónica (token celular)    |
| 18  | **Autorizaciones**   | Aceptación política tratamiento de datos | ✅                          | Checkbox + firma electrónica (token celular)    |
| 19  | **Autorizaciones**   | Token de celular (firma electrónica)     | ✅                          | OTP por SMS/WhatsApp                            |
| 20  | **Verificaciones**   | Consulta de antecedentes                 | ✅                          | Automática (servicio externo)                   |
| 21  | **Verificaciones**   | Consulta Preselecta                      | ✅                          | Automática (DataCrédito)                        |
| 22  | **Verificaciones**   | Consulta FOSYGA                          | Condicional (edad ≥ X años) | Automática (ADRES)                              |
| 23  | **Verificaciones**   | Consulta UBICA                           | ✅                          | Automática (TransUnion)                         |
| 24  | **Verificaciones**   | Token de correo electrónico              | ✅                          | OTP por correo                                  |

### 3.2 Orden de captura — Tienda física

En tienda el cliente está presente con su documento. El asesor puede capturar todo de una pasada.

```
PRE-ESTUDIO
├── 1. Identificación (tipo + número de documento)
├── 2. Validación de documento (¿puede iniciar o tiene uno activo?)
├── 3. Datos del cliente — TODO JUNTO en una pantalla
│   • Opción A: OCR del documento (frontal + posterior) + completar celular y correo
│   • Opción B: Ingreso manual de todos los campos
│   • Se crea/actualiza el tercero en el sistema
├── 4. Aceptación de T&C + Política de tratamiento de datos
└── 5. Token celular (firma electrónica) + código del asesor

ESTUDIO
├── 6. Consulta de antecedentes
├── 7. Consulta Preselecta ← ESTUDIO NACE AQUÍ
├── 8. Consulta FOSYGA (si aplica)
├── 9. Cupo preaprobado
├── 10. Dirección del cliente
├── 11. Verificación de identidad documental (fotos + selfie + match facial)
├── 12. Verificación UBICA + OTP correo
└── 13. Activación de cupo
```

### 3.3 Orden de captura — Canal web

En web la prioridad es **no perder al cliente por fricción inicial**. Se pide lo mínimo para avanzar y se completa lo demás cuando el cliente ya está comprometido con el proceso.

```
PRE-ESTUDIO
├── 1. Identificación (tipo + número de documento)
├── 2. Validación de documento (¿puede iniciar o tiene uno activo?)
├── 3. Datos básicos — SOLO LO MÍNIMO
│   • Nombres, apellidos
│   • Celular
│   • Correo
│   (todavía NO se pide género, fechas, ciudad expedición, dirección)
├── 4. Aceptación de T&C + Política de tratamiento de datos
├── 5. Token celular (firma electrónica)
└── 6. Foto frontal + posterior del documento (OCR)
    • Se extraen automáticamente: fecha expedición, género, fecha nacimiento
    • El cliente confirma los datos extraídos

ESTUDIO
├── 7. Consulta de antecedentes
├── 8. Consulta Preselecta ← ESTUDIO NACE AQUÍ
├── 9. Consulta FOSYGA (si aplica)
├── 10. Cupo preaprobado
├── 11. Dirección del cliente (ahora sí, cuando ya se sabe que es viable)
├── 12. Verificación de identidad documental (selfie + match facial)
│   • Las fotos del documento ya se tomaron en el paso 6
├── 13. Verificación UBICA + OTP correo
└── 14. Activación de cupo
```

> **Diferencia clave:** en tienda los datos del documento (fecha exp, género, etc.) se capturan **antes** de Preselecta junto con el resto. En web, se capturan **durante la fase de fotos** vía OCR, también antes de Preselecta pero en un momento distinto del flujo. **En ambos casos Preselecta recibe los mismos datos**, solo cambia cuándo los recibimos.

---

## 4. Flujo en tienda física

El flujo en tienda lo guía el cajero/asesor. El cliente está frente al asesor con su documento físico en la mano, normalmente porque quiere pagar una compra con el cupo y necesita que se active rápido.

### 4.1 Actores

- **Cajero/Asesor:** quien opera el sistema (QuacOne). Captura datos, guía al cliente, toma decisiones cuando hay dudas.
- **Cliente:** entrega el documento, responde preguntas, recibe OTP en su celular, se toma la selfie cuando se requiere.

### 4.2 Paso a paso narrativo

**Paso 1 — El cliente pide cupo.**
El cajero abre el módulo de solicitudes en QuacOne y crea un nuevo estudio.

**Paso 2 — Identificación.**
El cajero digita tipo + número de documento. El sistema consulta si el cliente ya existe, si tiene cupo activo, si tiene un estudio en curso, si tiene cartera morosa, etc. Según la respuesta, el flujo se ramifica:

| Respuesta del sistema                                  | Qué hace el asesor                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------------- |
| Cliente nuevo                                          | Continúa al paso 3 (captura completa de datos)                      |
| Cliente existente sin cupo                             | Continúa al paso 3 (confirmar/actualizar datos)                     |
| Cliente con cupo activo                                | Le avisa al cliente: "ya tienes cupo vigente" y cierra              |
| Cliente con cartera morosa                             | Le avisa al cliente: "debes normalizar tu cartera primero" y cierra |
| Cliente con estudio en curso (en otra tienda o en web) | Retoma el estudio desde donde quedó (ver paso 9)                    |
| Cliente con cupo cancelado + datos coincidentes        | Camino rápido de reactivación (ver sección 8.4)                     |

**Paso 3 — Captura de datos.**
El cajero tiene dos opciones:

- **OCR:** toma fotos del documento (frontal y posterior) con la cámara del punto de venta. El sistema extrae automáticamente nombres, apellidos, género, fecha de expedición, fecha de nacimiento, ciudad de expedición. El cajero completa lo que falta (celular, correo). El cliente verifica que los datos extraídos estén correctos.
- **Manual:** el cajero digita todos los datos uno a uno.

El cliente acepta verbalmente los T&C y la política de tratamiento de datos, que se muestran en pantalla. El asesor marca los checkboxes.

**Paso 4 — Tokenización del celular (firma electrónica).**
El cajero ingresa su código de asesor (para trazabilidad de quién atendió al cliente). El sistema envía un OTP al celular del cliente. El cliente dicta el código al cajero, que lo ingresa. Si no llega, puede reenviar por SMS, WhatsApp o llamada.

> **En este punto termina el pre-estudio.** La información está completa para poder consultar Preselecta.

**Paso 5 — Consulta de antecedentes.**
El sistema consulta en background antecedentes judiciales, disciplinarios y fiscales. Si hay antecedentes vigentes → estudio se cierra como `cerrado_no_viable` con mensaje genérico al cliente. Si no hay → continúa.

**Paso 6 — Consulta Preselecta.** 🎯 **Aquí nace el estudio.**
El sistema consulta DataCrédito/Preselecta. Posibles respuestas:

- **No viable** → estudio `cerrado_no_viable`. Mensaje genérico al cliente.
- **Viable** → continúa al paso 7.
- **Viable 2** → continúa al paso 7 pero pasando por FOSYGA (mayores de cierta edad).

**Paso 7 — FOSYGA (condicional).**
Solo si la respuesta es "Viable 2" o si el cliente tiene más de `[POR DEFINIR]` años. Se valida que el cliente cotice en salud. Si no cotiza → `cerrado_no_viable`. Si sí cotiza → continúa.

**Paso 8 — Cupo preaprobado.**
El sistema calcula y muestra el cupo preaprobado. El cajero le informa al cliente el monto. El cliente confirma que quiere continuar.

**Paso 9 — Dirección del cliente.**
El cajero captura departamento, ciudad y dirección de residencia.

**Paso 10 — Verificación de identidad documental (biometría).**
El cajero tiene dos opciones:

- **Con cámara del punto de venta:** toma la selfie del cliente frente al cajero.
- **Con link al celular del cliente:** le envía un enlace por SMS/WhatsApp para que el cliente tome la selfie desde su propio celular (útil si hay cola en la caja).

El sistema valida: que la selfie sea una persona real (liveness), que el rostro coincida con la foto del documento (match facial ≥ `[POR DEFINIR]`%), que las fotos del documento no sean una fotocopia ni estén alteradas.

**Si falla 2 veces** → el caso se deriva a la **Fábrica de Créditos** para revisión humana (ver sección 7). El estudio sigue `activo` pero su situación cambia a _en fábrica_ (esperando operador). El cajero puede seguir atendiendo otros clientes; el cliente recibe una notificación cuando haya resolución.

**Paso 11 — Verificación UBICA.**
El sistema consulta UBICA/TransUnion para confirmar que el celular y correo del cliente son consistentes con su historial. Si todo está OK → continúa. Si hay inconsistencia → el caso puede derivarse a Fábrica o intentar una llamada de verificación con IA.

**Paso 12 — Token de correo.**
El sistema envía un OTP al correo del cliente. El cliente dicta el código al cajero.

**Paso 13 — Activación del cupo.**
El sistema activa el cupo de crédito. El cliente recibe confirmación por SMS y correo. **Estudio en estado `cerrado_exitoso`**.

### 4.3 Lo que ve el cajero en cada momento

`[POR DEFINIR]` Aquí irá una referencia al mockup del módulo Solicitudes cuando esté afinado. Por ahora, conceptualmente, el cajero ve:

- Una "mesa de estudios": cola de solicitudes en curso + botón para iniciar una nueva.
- Cada estudio como una card con nombre del cliente, paso actual, tiempo transcurrido, estado.
- Al abrir un estudio: el formulario de la fase en que se encuentra.

---

## 5. Flujo en canal web (preaprobado.quac.co)

En el canal web el cliente se autogestiona. No hay un asesor al lado. El objetivo es que el cliente termine su estudio con la menor fricción posible, manteniendo la seguridad y la captura de la información necesaria.

### 5.1 Entrada al portal

Cuando un cliente ingresa a `preaprobado.quac.co`, lo primero que ve es una pantalla que le pregunta su tipo + número de documento. El sistema entonces decide qué mostrar:

| Situación del cliente                              | Qué hace el portal                                                                                                   |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Primera vez** (no existe en el sistema)          | Inicia flujo de registro nuevo (ver 5.2)                                                                             |
| **Cliente con estudio activo** (cualquier situación) | "Tenemos un estudio en curso tuyo. Vamos a retomarlo." → OTP al celular registrado → retoma en paso exacto (ver 5.3) |
| **Cliente con cupo activo**                        | "Ya tienes cupo vigente. Para consultarlo usa la app QUAC." Fin.                                                     |
| **Cliente con cartera morosa**                     | "Debes normalizar tu cartera antes de pedir otro cupo." Fin.                                                         |
| **Cliente con estudio cerrado no viable reciente** | "Por el momento no puedes solicitar cupo. Podrás intentar de nuevo después de `[POR DEFINIR]` meses." Fin.           |

### 5.2 Flujo para cliente nuevo

**Paso 1 — Identificación.**
El cliente digita tipo + número de documento.

**Paso 2 — Datos básicos mínimos.**
El portal pide **solo**: nombres, apellidos, celular, correo. Nada más por ahora. Esto reduce la fricción inicial.

**Paso 3 — T&C + tokenización del celular.**
El cliente marca los checkboxes de T&C y política de tratamiento de datos. El sistema envía OTP al celular. El cliente lo ingresa. **Esta es su firma electrónica.**

**Paso 4 — Fotos del documento (OCR).**
El portal le pide al cliente que tome foto frontal y posterior de su documento con la cámara del celular o la webcam. El sistema extrae: fecha de expedición, género, fecha de nacimiento, ciudad de expedición. El cliente confirma o corrige los datos extraídos.

**¿Qué pasa si el cliente no puede/quiere tomar fotos?** `[POR DEFINIR]` — propuesta: ofrecer ingreso manual como fallback. Pero implica más fricción y más errores.

> **Fin del pre-estudio.** La ficha tiene los datos mínimos necesarios para Preselecta.

**Paso 5 — Consulta de antecedentes (automático).**
Loader en pantalla mientras el sistema consulta. Resultado: continuar o cerrar.

**Paso 6 — Consulta Preselecta.** 🎯 **Nace el estudio.**
Loader. Resultado:

- No viable → pantalla amable: "Por el momento no puedes acceder a un cupo. Podrás intentar de nuevo más adelante." Estudio cerrado.
- Viable → continúa.

**Paso 7 — FOSYGA (condicional).**
Igual que en tienda, solo si aplica por edad.

**Paso 8 — Cupo preaprobado.**
Pantalla con el monto y condiciones. "¿Quieres continuar para activarlo?"

**Paso 9 — Dirección del cliente.**
Formulario con campos de residencia.

**Paso 10 — Prueba de vida (selfie).**
El cliente se toma una selfie con la cámara del celular. El sistema hace face liveness + match con la foto del documento. Si falla 2 veces → derivado a Fábrica.

**Paso 11 — Verificación UBICA (automático).**
Loader.

**Paso 12 — Token de correo.**
OTP al correo. El cliente lo ingresa.

**Paso 13 — Activación del cupo.**
Pantalla de éxito con el cupo activado. "Ya puedes usar tu cupo en las tiendas aliadas."

### 5.3 Retomar un estudio en curso (OTP)

**`[PROPUESTA]`** Este es el mecanismo para continuar un estudio `activo` en cualquiera de sus situaciones (esperando cliente, en fábrica, etc.):

1. Cliente ingresa a `preaprobado.quac.co` y digita su documento.
2. Sistema detecta que tiene un estudio en curso.
3. Sistema muestra: _"Hola, tenemos un estudio tuyo en curso iniciado el 8 de abril. Te vamos a enviar un código al celular que registraste para continuar."_
4. Envía OTP al celular que ya fue tokenizado.
5. Cliente ingresa el OTP.
6. **Sistema retoma el estudio en el paso exacto donde se quedó.** Ejemplo: si quedó en "pendiente dirección", lo lleva directo a esa pantalla sin re-hacer nada de lo anterior.

**¿Qué pasa si el cliente perdió el celular?** Debe ir a una tienda física para actualizar su celular, o llamar a la Fábrica de Créditos. No hay recovery por correo en este portal porque el único vínculo seguro es el celular.

**¿Cuánto dura la sesión?** La sesión dura lo que dure la interacción activa (`[PROPUESTA]` máximo 30 minutos ligado a la regla de 30 min del estudio). Si se va, pierde sesión. Al volver, nuevo OTP.

### 5.4 ¿Qué ve el cliente sobre su estudio?

**`[PROPUESTA]`** El cliente solo ve:

- Que tiene un estudio activo (si es el caso)
- La fecha en que lo inició
- En qué paso está ("Pendiente dirección", "En verificación de fotos", etc.)
- Acciones pendientes si aplican ("Sube nuevamente la foto de tu documento", "Espera nuestra revisión")

**No ve:**

- Histórico de estudios anteriores
- Motivos específicos de rechazos
- Score crediticio
- Datos internos del sistema

**Razón:** simplicidad, compliance, y porque el portal es una herramienta para "terminar algo", no un portal de cliente con histórico completo (eso vive en la app QUAC aparte).

---

## 6. Ciclo de vida del estudio

El estudio es la entidad central del proceso. Tiene una vida que empieza en Preselecta y termina cuando se cierra. A lo largo de su vida pasa por solo **dos estados globales**: activo o cerrado.

### 6.1 Solo dos estados globales

```
     ┌─────────┐              ┌─────────┐
     │ ACTIVO  │  ─────────▶  │ CERRADO │  (5 sub-estados)
     └─────────┘              └─────────┘
```

Un estudio nace **activo** (cuando Preselecta responde) y termina en alguno de los 5 sub-estados de **cerrado**.

> **¿Por qué solo dos estados?** "Estar esperando al cliente que volvió a salir del portal", "estar en la bandeja de un operador de fábrica" o "estar esperando la respuesta de un servicio externo" **no son estados globales distintos** — son _situaciones_ dentro de `activo`. El estudio sigue vivo mientras no se haya cerrado formalmente.

### 6.2 Situaciones dentro de "activo"

Un estudio activo siempre tiene dos datos asociados: el **paso actual** (dónde quedó la aguja) y una **situación** que indica de qué se depende para avanzar.

| Situación             | Qué significa                                                                                | Quién debe actuar         |
| --------------------- | -------------------------------------------------------------------------------------------- | ------------------------- |
| `en_interaccion`      | Alguien está trabajándolo ahora mismo (cliente en el portal, asesor en tienda)              | Cliente / Asesor          |
| `esperando_cliente`   | El cliente se fue y debe volver a continuar (abandonó el flujo o se le pidió foto nueva)    | Cliente                   |
| `en_fabrica`          | Un operador humano debe revisar el caso (fotos, UBICA, etc.)                                | Operador de Fábrica       |
| `esperando_servicio`  | El sistema está consultando un servicio externo (UBICA, FOSYGA, Preselecta) y esperando     | Sistema / servicio externo |

Estas situaciones pueden cambiar varias veces durante la vida del estudio (ej: _en_interaccion → esperando_servicio → en_interaccion → en_fabrica → esperando_cliente → en_interaccion_). Todas siguen siendo **activo**. Lo que importa para cerrar el estudio no es la situación actual sino el **tiempo transcurrido** y el **paso en que está**.

### 6.3 Cuándo se cierra un estudio

Un estudio deja de estar activo (y pasa a cerrado) por alguna de estas causas:

| Causa de cierre                                                             | Resultado                |
| --------------------------------------------------------------------------- | ------------------------ |
| El cupo se activa en el paso final                                          | `cerrado_exitoso`        |
| Una verificación automática rechaza (Preselecta, antecedentes, FOSYGA)      | `cerrado_no_viable`      |
| Un operador de fábrica rechaza manualmente                                  | `cerrado_rechazado`      |
| Se detecta inconsistencia grave (CC mal creada, suplantación, etc.)         | `cerrado_inconsistencia` |
| Pasa demasiado tiempo sin avanzar `[REGLA POR DEFINIR]`                     | `cerrado_expirado`       |

### 6.4 Cuándo debe expirar un estudio — Preguntas clave

> **Este bloque es el que más necesita definición.**
> La regla de expiración (cuándo pasar de `activo` a `cerrado_expirado`) debe depender de la combinación entre **el paso actual del estudio** y **el tiempo transcurrido** desde la última interacción significativa. No podemos cerrar todos los estudios con la misma regla porque algunos pasos son rápidos (un OTP debe llegar en segundos) y otros son lentos (la fábrica puede tomar días).

**Propuesta inicial de matriz** (por validar):

| Paso / situación del estudio                                    | Tiempo sin avance          | Acción propuesta                                          |
| --------------------------------------------------------------- | -------------------------- | --------------------------------------------------------- |
| Esperando servicio externo (UBICA, FOSYGA, Preselecta)          | > 1 min                    | Reintentar. Si falla 3 veces, derivar a fábrica.          |
| En interacción con cliente (portal web)                         | > 30 min                   | Situación cambia a `esperando_cliente`. Sigue activo.     |
| Esperando cliente                                               | > 24 h                     | `[POR DEFINIR]` — ¿notificación al cliente por SMS?        |
| Esperando cliente                                               | > 7 días                   | `[POR DEFINIR]` — ¿cerrar por expiración?                  |
| En fábrica (esperando operador)                                 | > 24 h                     | `[POR DEFINIR]` — ¿alerta al supervisor?                   |
| En fábrica                                                      | > 72 h                     | `[POR DEFINIR]` — ¿escalar? ¿cerrar?                       |
| Cualquier paso                                                  | > 30 / 60 / 90 días        | Cierre absoluto por expiración, sin importar el paso.     |

**Preguntas clave para cerrar este punto:**

1. **¿Hay un tiempo máximo absoluto de vida de un estudio?** Desde que nace (Preselecta responde) hasta que se cierra automáticamente por expiración, sin importar en qué paso esté. _Propuesta: 30 días. ¿Te sirve?_
2. **¿El contador se mide desde la creación del estudio o desde la última interacción del cliente?** Ejemplo: si un estudio nació el día 1 y el cliente interactuó por última vez el día 5, y hoy es día 10 → ¿llevamos 10 días o 5 días?
3. **¿Los tiempos deben ser distintos según el paso actual?** Por ejemplo, un estudio esperando dirección vs uno esperando foto vs uno en fábrica. ¿Cada uno con su propio TTL, o todos con el mismo?
4. **¿Cuánto tiempo puede esperar la fábrica a que un operador tome un caso?** ¿Hay un SLA interno (ej: 24h) que debemos respetar? ¿Qué pasa si se sobrepasa: notifica al supervisor o cierra?
5. **¿Se debe notificar al cliente antes de expirar el estudio?** Ejemplo: un SMS a los 5 días recordándole que puede retomar, y a los 7 días avisándole que va a expirar. ¿O se cierra silenciosamente?
6. **¿Un estudio expirado puede reactivarse?** Si el cliente vuelve después de que expiró, ¿se le obliga a empezar un estudio nuevo (más probable) o se le permite retomar el viejo con OTP?
7. **¿Debemos diferenciar "expirado por cliente" vs "expirado por fábrica"?** El motivo del cierre puede importar para métricas: no es lo mismo que el cliente no volvió a que la fábrica no resolvió a tiempo.

### 6.5 Unicidad del estudio vivo

Un cliente puede tener **muchos** estudios en su historia. Pero **solo uno** puede estar en estado `activo` a la vez, sin importar en qué situación esté (en interacción, esperando cliente, en fábrica, etc.). Si intenta iniciar uno nuevo mientras tiene otro activo, el sistema lo detecta y lo redirige a retomar el que ya tiene.

### 6.6 Transición entre canales

Un estudio **no pertenece a un canal**. Vive en el backend. Un cliente puede iniciar en tienda y continuar en web (o viceversa) siempre y cuando el sistema pueda autenticarlo (OTP al celular).

Ejemplo típico: el asesor en tienda dice "está congestionada la caja, te mando un link y terminas en tu celular". El cliente recibe el link, entra a `preaprobado.quac.co`, digita su documento, recibe OTP al celular que ya tokenizó en tienda, y retoma el estudio en el paso donde quedó. La situación del estudio cambió de _en interacción con asesor_ a _en interacción con cliente_ — sigue siendo el mismo estudio activo.

---

## 7. Validación humana en la Fábrica de Créditos

La Fábrica de Créditos es el equipo humano que revisa los casos que el sistema no pudo aprobar automáticamente. No es un canal de solicitud, es un **módulo de gestión de excepciones**.

### 7.1 ¿Cuándo un estudio va a Fábrica?

Un estudio se deriva a Fábrica cuando ocurre alguna de estas situaciones:

| Motivo                                                                   | ¿En qué paso del flujo? |
| ------------------------------------------------------------------------ | ----------------------- |
| Fotos del documento no pasan validación automática (2 intentos fallidos) | Verificación documental |
| Match facial entre selfie y documento por debajo del umbral (2 intentos) | Verificación documental |
| Suplantación detectada por Rekognition (foto en base de fraudes)         | Verificación documental |
| FOSYGA sin información o timeout                                         | FOSYGA                  |
| UBICA inconsistente con antigüedad del celular baja                      | UBICA                   |
| UBICA — posible suplantación detectada por llamada                       | UBICA                   |
| Detección de fotomontaje o documento falsificado                         | Verificación documental |

Cuando esto pasa, el estudio sigue `activo` pero su situación cambia a _en fábrica_ y el paso actual queda registrado como "En revisión manual — motivo: [X]".

### 7.2 Qué ve el operador de Fábrica

`[POR DEFINIR]` El mockup detallado del módulo de Fábrica se trabajará en una sesión aparte. Por ahora, el concepto:

- **Bandeja de casos:** el operador ve una cola de estudios derivados, ordenados por tiempo de espera (más viejos primero) o por prioridad.
- **Detalle del caso:** al abrir un caso, ve toda la información del cliente recopilada hasta ahora, más el motivo específico de derivación.
- **Fotos con checklist:** si el motivo son las fotos, ve la foto frontal, foto posterior y selfie, cada una con un checklist de validaciones:
  - ✓ Etiquetas válidas (es un documento real)
  - ✓ No es fotocopia ni foto de pantalla
  - ✓ Rostro visible (para la frontal)
  - ✓ Imagen nítida
  - ✓ Texto legible
  - ✓ Match facial con selfie (si aplica)
- **Acciones por foto:** el operador puede marcar cada foto como:
  - **Aprobada** → cumple los requisitos
  - **Rechazada — repetir** → solicitar al cliente que suba una nueva
  - **Rechazada — fraude** → el documento presenta irregularidades graves
- **Historial de fotos del cliente:** el operador puede ver fotos de otros estudios del mismo cliente para comparar (ej: la selfie de un estudio anterior vs la actual).

### 7.3 Comunicación con el cliente

Cuando el operador marca "repetir foto", el cliente recibe una notificación:

- **SMS/WhatsApp:** _"Tu solicitud de cupo QUAC necesita tu atención. Entra a preaprobado.quac.co para continuar."_
- **En el portal web:** cuando el cliente entra (con OTP), ve claramente qué foto debe repetir y un botón para subirla.

El cliente sube la foto → el estudio vuelve a la bandeja del operador → el operador revisa → aprueba o rechaza.

### 7.4 Resolución del caso

El operador puede:

- **Aprobar** → el estudio vuelve a estado `activo` y continúa en el paso siguiente del flujo.
- **Rechazar** → el estudio pasa a `cerrado_rechazado` con el motivo. Se notifica al cliente.
- **Solicitar información adicional** → el cliente recibe una notificación y puede responder desde el portal.

### 7.5 Tiempo de resolución esperado

`[POR DEFINIR]` Tiempo objetivo para resolución en Fábrica. Propuesta: 24-48h.

---

## Anexo A — Glosario

- **Cliente:** persona que solicita el cupo de crédito.
- **Tercero:** registro del cliente en el sistema (datos personales, documento, contacto).
- **Cupo:** monto de crédito aprobado que el cliente puede usar en las tiendas aliadas.
- **Pre-estudio:** etapa previa al estudio formal. Captura información para poder consultar Preselecta.
- **Estudio:** proceso de evaluación crediticia completo. Nace cuando Preselecta arroja un resultado.
- **Preselecta:** motor de decisión crediticia de DataCrédito que evalúa la viabilidad del cliente.
- **FOSYGA / ADRES:** sistema colombiano de seguridad social en salud. Se consulta para verificar cotización en casos condicionales.
- **UBICA:** servicio de TransUnion que verifica datos de contacto históricos del cliente.
- **Rekognition:** servicio de AWS que hace reconocimiento facial y validación de imágenes.
- **OCR:** extracción automática de texto de imágenes (usado para leer datos del documento).
- **Prueba de vida / Liveness:** validación biométrica de que el cliente es una persona real en tiempo real.
- **Match facial:** comparación entre la selfie del cliente y la foto del documento.
- **Token:** código temporal (OTP) enviado por SMS, WhatsApp o correo para verificar identidad.
- **Firma electrónica:** el OTP del celular en el momento de aceptar T&C funciona como firma electrónica vinculante.
- **Fábrica de Créditos:** equipo humano que revisa casos que el sistema no pudo aprobar automáticamente.

---

---

**Fin del playbook v0.1.**
