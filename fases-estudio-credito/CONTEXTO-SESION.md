# Contexto de continuidad — Análisis de Fases del Estudio de Crédito

> **Última actualización:** 2026-04-08
> **Estado:** En proceso — ajustes al plan de trabajo

---

## Qué se está haciendo

Se está construyendo el **documento de análisis arquitectónico del nuevo flujo de estudio de crédito QUAC**, que mapea fases, actores, servicios y un plan de trabajo para la implementación.

El documento vive en dos formatos:
- **Markdown (fuente):** `docs/analisis/ANALISIS-FASES-ESTUDIO-CREDITO.md`
- **HTML (visual interactivo):** `docs/analisis/fases-estudio-credito/index.html`

El HTML sigue el estilo visual de `fabricas-git/index.html` (Plus Jakarta Sans + JetBrains Mono, sidebar fija, tablas con hover, badges de colores, callouts).

---

## Estructura actual del documento

1. **Contexto y objetivo** — qué es, 3 canales (Web, Externos, Tienda)
2. **Vista general del flujo** — diagrama visual con cajas y flechas SVG
3. **Matriz de responsabilidades por fase** — 13 fases como cards `<details>` colapsables
4. **Módulo Fábrica de Créditos** — visión general (diseño detallado pospuesto)
5. **Puntos de delegación al cliente** — qué puede hacer el cliente desde su celular
6. **Mapa de servicios consolidado** — KPIs (15 existen, 4 por construir, 2 parciales, 22 campos nuevos)
7. **Alternativa Truora** — como reemplazo/complemento de Rekognition + lógica propia
8. **Escenarios del prototipo** — 11 escenarios mapeados
9. **Plan de trabajo** — ← **sección en discusión / pendiente de rehacer**

---

## Decisiones tomadas en esta sesión

### Sobre el plan de trabajo

El plan original era muy genérico ("Fundamentos", "Validaciones automáticas", etc.) y revolvía responsabilidades. Se iteró varias veces y el usuario dio feedback importante:

1. **No organizar por disciplina** (Front/Back/BD) sino por **producto** o módulo. Un mismo equipo trabaja APIs, BD y pantallas del mismo producto.

2. **No mencionar cosas puntuales que pueden variar:** nada de `credit_request`, `SigmaApiErpQuac`, `SBERP_*`, nombres de tablas o SPs. El plan debe describir *qué* se necesita, no *cómo* se llama internamente hoy.

3. **Arquitectura del trabajo aclarada por el usuario:**
   - **QuacOne (Tienda)** — Front MFE + Back .NET + **SQL Server como fuente de verdad del crédito**. Aquí viven los servicios del flujo.
   - **Preaprobado.quac.co (Web)** — Front + Back Laravel + **MySQL operativo** (logs, sesiones, estado de navegación del cliente). Consume los servicios de QuacOne. Tiene servicios utilitarios propios: logs, integración Rekognition/Truora.
   - **Modelo de datos (SQL Server)** — Fuente de verdad, pertenece al equipo QuacOne pero es transversal.

4. **Socializaciones obligatorias** antes de implementar módulos complejos (Fábrica, Portal cliente, UBICA) con el equipo que los va a usar.

5. **Algunos módulos se diseñan al llegar a su sprint**, no antes: Fábrica, Portal cliente, UBICA. Se genera un `ANALISIS-MODULO-*.md` al iniciar cada sprint.

6. **Las 13 fases pueden agruparse en 7 fases "de negocio"** para comunicación/planeación (los 13 son los *pasos* dentro de las fases):

   | Fase | Pasos que agrupa | Descripción |
   |---|---|---|
   | **F1 Identificación** | Paso 1 (documento) + Paso 2 (elegibilidad) | Quién es el cliente, ¿puede continuar? |
   | **F2 Consentimiento legal** | Paso 4 (T&C + token) | Firma electrónica vinculante |
   | **F3 Datos del cliente** | Paso 3 (datos tercero/OCR) + Paso 9 (dirección) | Captura de información |
   | **F4 Estudio de crédito** | Pasos 5, 6, 7, 8 (antecedentes, Preselecta, FOSYGA, cupo) | Motor de decisión |
   | **F5 Verificación de identidad documental** | Paso 10 (fotos + selfie + match) | Prueba de vida — delegable al cliente |
   | **F6 Verificación UBICA** | Paso 12 (UBICA + llamada IA) | Verificación de contacto — delegable al cliente |
   | **F7 Activación de cupo** | Paso 13 (token correo + activación) | Cierre exitoso |

   La **Fábrica** no es una fase del flujo lineal sino un **módulo transversal** al que se deriva cuando algo falla en F4, F5 o F6.

---

## Feedback pendiente de aplicar (lo que quedó abierto)

El usuario no quedó satisfecho con el plan presentado. Quiere que se rehaga teniendo en cuenta que el trabajo debe distribuirse así:

1. **Mockups del módulo de Solicitudes** — el que usa el vendedor en tienda. Corresponde al prototipo en `prototipo/` y **no se ha afinado aún**. Los mockups deben ser **aprobados por el equipo de cartera o la coordinadora del proceso**.

2. **Resumir el flujo en 7 fases** (F1-F7 descritas arriba) en lugar de hablar de 13 pasos como bloques planos.

3. **Mockups del módulo de Fábricas** — cuando el proceso de verificación u otro debe ser revisado por un operador, pasa al módulo Fábricas. Hay que construir estos mockups.

4. **Portal web (preaprobado.quac.co)** — para solicitud de cupo autogestionada, con la opción de que el cliente sepa en qué fase del estudio va y, si está en una fase que él puede atender, que la resuelva desde ahí (subir de nuevo una foto que le solicitaron, tokenizar el correo, etc.).

5. **Back en .NET (QuacOne)** — inventario de servicios requeridos para los módulos **Solicitudes** y **Fábricas**.

6. **Back del portal Preaprobado** — lo que se requiere para el módulo web.

7. **Modelo de datos** — debe **validarse desde el inicio** para poder crear los SPs y los servicios de Solicitudes y Fábricas. **No es un sprint al final, es una tarea temprana y continua.**

8. **Construcción del front puede adelantarse y simular con mocks** — no tiene que esperar al back. Los mockups deben ser aprobados antes.

### Crítica del usuario al plan anterior
- "No quedó contento con el trabajo que propones, sigue siendo poco real"
- "Ni tu ejecutarias el plan así"
- "Hay cosas que pones en las semanas finales que se pueden hacer el primer mes"
- "Nadie presenta un plan así" (refiriéndose al preámbulo "El plan se organiza por producto, no por disciplina...")
- El plan debe usar **el estándar real** para presentar un plan de trabajo, no explicaciones metodológicas previas.

---

## Próximos pasos

1. **Rehacer la sección 9 (Plan de trabajo)** del HTML con esta nueva estructura:
   - Frentes de trabajo paralelos (no sprints lineales):
     - **Mockups** (Solicitudes + Fábricas) → aprobación cartera/coordinación
     - **Modelo de datos** (desde el inicio, continuo)
     - **Back QuacOne (.NET)** — inventario y construcción de servicios para Solicitudes y Fábricas
     - **Back Preaprobado (Laravel)** — orquestador web + servicios utilitarios
     - **Front Solicitudes** (MFE tienda) — puede adelantarse con mocks
     - **Front Fábricas** (MFE operador) — puede adelantarse con mocks
     - **Front Preaprobado** (web cliente) — puede adelantarse con mocks
   - Sin preámbulo metodológico, directo al plan.
   - Sin mencionar nombres internos de tablas, SPs, proyectos específicos.
   - Realista: tareas que pueden ir en paralelo desde el primer mes deben estar al principio.

2. **Posiblemente actualizar el diagrama de la sección 2** para mostrar las 7 fases agrupando los 13 pasos (confirmar con el usuario antes de tocar esto).

3. **Actualizar también el markdown fuente** (`ANALISIS-FASES-ESTUDIO-CREDITO.md`) con los mismos cambios — durante la sesión se modificó solo el HTML, el markdown quedó desactualizado en la sección del plan.

---

## Estado de archivos

| Archivo | Estado |
|---|---|
| `docs/analisis/ANALISIS-FASES-ESTUDIO-CREDITO.md` | Completo hasta sección 8. Plan de sección 9 **desactualizado** (versión vieja por sprints genéricos) |
| `docs/analisis/fases-estudio-credito/index.html` | Completo con diagrama visual mejorado y Truora. Plan de sección 9 **pendiente de rehacer** según el feedback |
| `fabricas-git/index.html` | Archivo de referencia de estilo visual (no se modifica) |
| `prototipo/prototipo-flujo-tienda.html` | Prototipo interactivo con 13 pasos y 11 escenarios — no afinado, pendiente de aprobación |

---

## Notas importantes del proyecto (de CLAUDE.md)

- **Idioma:** todo en español (interacción, código, documentos)
- **Proyecto:** Fábricas de Crédito QUAC — refactorización del flujo de solicitud
- **Coordinador:** Francisco Lizcanor
- **Equipo mencionado:** Leo (BD), Backend, Frontend, Coordinador
- **Volumen real del embudo:** 5,000-10,000 solicitudes/mes, solo ~13% resultan viables
- **Decisión sobre Fábrica:** rediseño desde cero, el FabricasQuacMFE actual no sirve como base
- **Decisión sobre comunicación con cliente:** activa (SMS/WhatsApp con link) + portal web pasivo

---

## Cómo retomar

1. Leer este documento.
2. Leer `docs/analisis/ANALISIS-FASES-ESTUDIO-CREDITO.md` secciones 1-8 para contexto del flujo.
3. Abrir el HTML en el navegador para ver el estado visual actual: `docs/analisis/fases-estudio-credito/index.html`.
4. **Rehacer sección 9 del HTML** siguiendo el feedback del usuario listado arriba en "Próximos pasos".
5. Propagar los cambios al markdown fuente.
