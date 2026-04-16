/* 
=============================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS EMPRESARIAL
  Motor:    SQL Server 2019+
  Versión:  2.0
  Fecha:    2026-03-17
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  DESCRIPCIÓN:
  Modelo relacional completo para el Sistema de Otorgamiento de Crédito
  de QUAC. Incluye 19 tablas distribuidas en
  4 grupos lógicos:
    - MAESTRAS (5)        — Entidades base del negocio
    - CONFIGURACIÓN (5)   — Parametrización de flujo, estados y reglas
    - TRANSACCIONALES (6) — Operaciones del proceso de crédito
    - AUDITORÍA (3)       — Trazabilidad inmutable y auditoría de cambios

  CONVENCIONES:
    - Nomenclatura 100% en español, PascalCase
    - PKs: Id<Entidad> INT/BIGINT IDENTITY(1,1)
    - FKs: Id<EntidadReferenciada>
    - Fechas: DATETIME2(3) para precisión de milisegundos
    - JSON: NVARCHAR(MAX) para payloads de servicios externos
    - Normalización: 3NF sin sobre-ingeniería

  ORDEN DE CREACIÓN:
    Las tablas se crean en orden de dependencia (maestras primero,
    luego configuración, transaccionales y auditoría al final). 
=============================================================================
*/


-- ═══════════════════════════════════════════════════════════════════════════
-- GRUPO 1: TABLAS MAESTRAS (5 tablas)
-- Entidades base que no dependen de tablas transaccionales.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 1.1  bodegas
-- Puntos físicos donde se originan solicitudes de crédito.
-- ─────────────────────────────────────────────────────────────────────────


-- ─────────────────────────────────────────────────────────────────────────
-- 1.2 kcrm_VendedoresExternos (vendedores tienda) y BERP_FABRICASOperadores (call center)
-- Personal que gestiona solicitudes en tienda física o call center.
-- ─────────────────────────────────────────────────────────────────────────


-- ─────────────────────────────────────────────────────────────────────────
-- 1.3  Clientes
-- Datos del cliente AISLADOS para el proceso de crédito.
-- 
-- NOTA IMPORTANTE: Esta tabla NO es la tabla de "Terceros" del ERP QUAC.
-- Mantiene una copia de los datos del cliente al momento del estudio
-- para garantizar aislamiento de auditoría. Los campos IdTerceroExterno
-- y NitTercero permiten la referencia cruzada con el sistema ERP
-- existente sin crear dependencia física (FK lógica, no física).
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE Clientes (
    IdCliente           INT IDENTITY(1,1)   NOT NULL,

    -- Referencia cruzada al ERP QUAC (FK lógica, NO física)
    IdTerceroExterno    BIGINT              NULL,       -- ID del tercero en el ERP QUAC
    NitTercero          VARCHAR(20)         NULL,       -- NIT/Cédula en el ERP, para búsqueda cruzada

    -- Datos de identificación
    TipoDocumento       CHAR(3)             NOT NULL,   -- CC, CE, PPT, TI
    NumeroDocumento     VARCHAR(20)         NOT NULL,
    PrimerNombre        NVARCHAR(100)       NOT NULL,
    SegundoNombre       NVARCHAR(100)       NULL,
    PrimerApellido      NVARCHAR(100)       NOT NULL,
    SegundoApellido     NVARCHAR(100)       NULL,

    -- Datos de contacto
    Correo              VARCHAR(150)        NULL,
    Celular             VARCHAR(20)         NULL,
    TelefonoFijo        VARCHAR(20)         NULL,

    -- Datos demográficos
    FechaNacimiento     DATE                NULL,
    Genero              CHAR(1)             NULL,       -- M, F, O
    DireccionResidencia NVARCHAR(250)       NULL,
    CiudadResidencia    NVARCHAR(100)       NULL,
    DepartamentoResidencia NVARCHAR(100)    NULL,

    -- Banderas de estado global (optimizan consultas sin JOINs a detalle)
    TieneCupoActivo         BIT             NOT NULL    DEFAULT 0,
    EstaBloqueado           BIT             NOT NULL    DEFAULT 0,
    TieneRegistroBiometrico BIT             NOT NULL    DEFAULT 0,
    FechaDesbloqueo         DATETIME2(3)    NULL,       -- Fin del período de enfriamiento (cooling-off)

    FechaCreacion       DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaActualizacion  DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_Clientes PRIMARY KEY (IdCliente),
    CONSTRAINT UQ_Clientes_Documento UNIQUE (TipoDocumento, NumeroDocumento),
    CONSTRAINT CK_Clientes_TipoDoc CHECK (TipoDocumento IN ('CC','CE','PPT','TI')),
    CONSTRAINT CK_Clientes_Genero CHECK (Genero IS NULL OR Genero IN ('M','F','O'))
);

-- Índices para búsqueda rápida en tienda
CREATE INDEX IX_Clientes_NumDoc ON Clientes(NumeroDocumento);
CREATE INDEX IX_Clientes_Celular ON Clientes(Celular) WHERE Celular IS NOT NULL;
CREATE INDEX IX_Clientes_TerceroExt ON Clientes(IdTerceroExterno) WHERE IdTerceroExterno IS NOT NULL;
CREATE INDEX IX_Clientes_NitTercero ON Clientes(NitTercero) WHERE NitTercero IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────
-- 1.4  KCRM_CadenaCreditos y QUAC_Multicomercios
-- Cupos de crédito otorgados a clientes.
-- Posibles mejoras con los campos EstadoActual, MotivoBloqueo, FechaCancelacion y ElegibleReactivacion
-- ─────────────────────────────────────────────────────────────────────────
    EstadoActual        VARCHAR(20)         NOT NULL,   -- ACTIVO, BLOQUEADO, CANCELADO
    MotivoBloqueo       VARCHAR(50)         NULL,       -- MORA, FRAUDE, SOLICITUD_CLIENTE
    FechaCancelacion    DATETIME2(3)        NULL,       -- Para regla "Renunció en los últimos XXX días"
    ElegibleReactivacion BIT                NOT NULL    DEFAULT 0,  -- Reactivación exprés


-- ─────────────────────────────────────────────────────────────────────────
-- 1.5  BERP_FABRICASOrigenes
-- Catálogo de canales de originación de solicitudes.
-- Agregar campo activo para permitir deshabilitar canales.
-- ─────────────────────────────────────────────────────────────────────────


-- ═══════════════════════════════════════════════════════════════════════════
-- GRUPO 2: TABLAS DE CONFIGURACIÓN (5 tablas)
-- Parametrizan el flujo, estados, pasos y reglas de negocio.
-- Permiten modificar el comportamiento del sistema sin tocar código.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 2.1  FasesEstudio
-- Las 7 fases macro del proceso de otorgamiento de crédito.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE FasesEstudio (
    IdFase              INT IDENTITY(1,1)   NOT NULL,
    Codigo              VARCHAR(30)         NOT NULL,
    Nombre              NVARCHAR(100)       NOT NULL,
    OrdenEjecucion      INT                 NOT NULL,   -- Secuencia: 1, 2, 3...
    Descripcion         NVARCHAR(500)       NULL,
    Activa              BIT                 NOT NULL    DEFAULT 1,

    CONSTRAINT PK_FasesEstudio PRIMARY KEY (IdFase),
    CONSTRAINT UQ_FasesEstudio_Codigo UNIQUE (Codigo),
    CONSTRAINT UQ_FasesEstudio_Orden UNIQUE (OrdenEjecucion)
);

-- Datos semilla: las 7 fases del flujo
INSERT INTO FasesEstudio (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
    ('IDENTIFICACION',          'Identificación del Cliente',       1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
    ('DATOS_CLIENTE',           'Datos del Cliente',                2, 'Captura o actualización de datos personales y de contacto'),
    ('CONSENTIMIENTO_LEGAL',    'Consentimiento Legal',             3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
    ('VALIDACIONES_RIESGO',     'Validaciones de Riesgo',           4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
    ('LIMITE_CREDITO',          'Límite de Crédito',                5, 'Cálculo y presentación del cupo preaprobado'),
    ('VERIFICACION_IDENTIDAD',  'Verificación de Identidad',        6, 'Biometría facial, OCR de documento, prueba de vida'),
    ('ACTIVACION',              'Activación del Cupo',              7, 'Validación UBICA, activación automática o gestión manual Call Center');
GO


-- ─────────────────────────────────────────────────────────────────────────
-- 2.2  PasosEstudio
-- Los 13 pasos individuales del flujo. Cada paso pertenece a una fase.
-- Contiene flags de automatización y orquestación.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE PasosEstudio (
    IdPaso              INT IDENTITY(1,1)   NOT NULL,
    IdFase              INT                 NOT NULL,
    Codigo              VARCHAR(40)         NOT NULL,
    Nombre              NVARCHAR(150)       NOT NULL,
    OrdenEnFase         INT                 NOT NULL,   -- Orden dentro de la fase
    OrdenGlobal         INT                 NOT NULL,   -- Orden absoluto (1 a 13)
    Actor               VARCHAR(30)         NOT NULL    DEFAULT 'SISTEMA',
    ServicioExterno     VARCHAR(50)         NULL,       -- Servicio que se invoca (ej. PRESELECTA, UBICA)
    EsAutomatico        BIT                 NOT NULL    DEFAULT 1,   -- ¿Se ejecuta auto al completar el anterior?
    RequiereIntervencion BIT                NOT NULL    DEFAULT 0,   -- ¿Intervención manual en caso de fallo?
    TiempoTimeoutSeg    INT                 NULL,       -- Timeout en segundos para servicios externos
    Descripcion         NVARCHAR(500)       NULL,
    Activo              BIT                 NOT NULL    DEFAULT 1,

    CONSTRAINT PK_PasosEstudio PRIMARY KEY (IdPaso),
    CONSTRAINT UQ_PasosEstudio_Codigo UNIQUE (Codigo),
    CONSTRAINT UQ_PasosEstudio_OrdenGlobal UNIQUE (OrdenGlobal),
    CONSTRAINT FK_PasosEstudio_Fase FOREIGN KEY (IdFase) REFERENCES FasesEstudio(IdFase),
    CONSTRAINT CK_PasosEstudio_Actor CHECK (Actor IN ('ASESOR','SISTEMA','CLIENTE','CALL_CENTER'))
);

CREATE INDEX IX_PasosEstudio_Fase ON PasosEstudio(IdFase);

-- Datos semilla: los 13 pasos del flujo
INSERT INTO PasosEstudio (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, ServicioExterno, EsAutomatico, RequiereIntervencion, TiempoTimeoutSeg, Descripcion) VALUES
    -- Fase 1: Identificación (3 pasos)
    (1, 'INGRESO_DOCUMENTO',        'Ingreso de Documento',             1,  1,  'ASESOR',       NULL,                   0, 0, NULL,   'El asesor digita el número de documento del cliente'),
    (1, 'VALIDAR_EXISTENCIA',       'Validar Existencia del Cliente',   2,  2,  'SISTEMA',      'ERP_QUAC',             1, 0, 30,     'Verifica si el cliente existe en el sistema ERP'),
    (1, 'VALIDAR_CUPO_BLOQUEO',     'Validar Cupo Activo / Bloqueo',   3,  3,  'SISTEMA',      'CORE_CREDITO',         1, 0, 30,     'Verifica cupo activo, bloqueos, mora, cancelaciones recientes'),
    -- Fase 2: Datos del Cliente (1 paso)
    (2, 'CAPTURA_DATOS',            'Captura de Datos Personales',      1,  4,  'ASESOR',       NULL,                   0, 0, NULL,   'Captura o actualización de datos personales, correo, celular, dirección'),
    -- Fase 3: Consentimiento Legal (2 pasos)
    (3, 'CONSENTIMIENTO_DATOS',     'Autorización Tratamiento Datos',   1,  5,  'CLIENTE',      NULL,                   0, 0, NULL,   'El cliente acepta términos y autoriza tratamiento de datos personales'),
    (3, 'TOKENIZACION',             'Envío y Validación de Token OTP',  2,  6,  'SISTEMA',      'OTP_PROVIDER',         1, 0, 120,    'Envío de OTP por WhatsApp/Email y validación del código'),
    -- Fase 4: Validaciones de Riesgo (4 pasos)
    (4, 'VALIDAR_LISTAS',           'Validar Listas Restrictivas',      1,  7,  'SISTEMA',      'LISTAS_RESTRICTIVAS',  1, 0, 30,     'Consulta en listas de antecedentes penales y judiciales'),
    (4, 'CONSULTAR_BURO',           'Consultar Buró de Crédito',        2,  8,  'SISTEMA',      'BURO_CREDITO',         1, 0, 60,     'Consulta de historial crediticio y score en centrales de riesgo'),
    (4, 'EVALUAR_PRESELECTA',       'Evaluación Preselecta',            3,  9,  'SISTEMA',      'PRESELECTA',           1, 0, 60,     'Motor de decisión Preselecta para determinar viabilidad'),
    (4, 'VALIDAR_FOSYGA',           'Validar FOSYGA / ADRES',          4, 10,  'SISTEMA',      'FOSYGA',               1, 0, 30,     'Verificación estado de seguridad social (cotizante/beneficiario/pensionado)'),
    -- Fase 5: Límite de Crédito (1 paso)
    (5, 'CALCULAR_CUPO',            'Cálculo del Cupo Preaprobado',     1, 11,  'SISTEMA',      'MOTOR_CUPO',           1, 0, 30,     'Cálculo del límite de crédito basado en reglas de negocio y score'),
    -- Fase 6: Verificación de Identidad (1 paso)
    (6, 'VERIFICACION_BIOMETRICA',  'Verificación Biométrica',          1, 12,  'SISTEMA',      'BIOMETRIA',            1, 1, 120,    'Captura facial, prueba de vida, OCR de documento, comparación biométrica'),
    -- Fase 7: Activación (1 paso)
    (7, 'ACTIVACION_CUPO',          'Activación del Cupo',              1, 13,  'SISTEMA',      'UBICA',                1, 1, 60,     'Validación UBICA de contactabilidad y activación automática o derivación a Call Center');
GO


-- ─────────────────────────────────────────────────────────────────────────
-- 2.3  CatalogoEstados
-- Todos los estados posibles de un estudio de crédito.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE CatalogoEstados (
    IdEstado            INT IDENTITY(1,1)   NOT NULL,
    Codigo              VARCHAR(40)         NOT NULL,
    Nombre              NVARCHAR(100)       NOT NULL,
    Grupo               VARCHAR(20)         NOT NULL,   -- INICIAL, PROCESO, TERMINAL
    EsTerminal          BIT                 NOT NULL    DEFAULT 0,
    PermitePausa        BIT                 NOT NULL    DEFAULT 0,  -- ¿Se puede pausar desde este estado?
    Descripcion         NVARCHAR(500)       NULL,
    Activo              BIT                 NOT NULL    DEFAULT 1,

    CONSTRAINT PK_CatalogoEstados PRIMARY KEY (IdEstado),
    CONSTRAINT UQ_CatalogoEstados_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_CatalogoEstados_Grupo CHECK (Grupo IN ('INICIAL','PROCESO','TERMINAL'))
);

-- Datos semilla: 11 estados del sistema
INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('BORRADOR',            'Borrador',                         'INICIAL',  0, 0, 'Solicitud iniciada, documento ingresado pero aún sin procesar'),
    ('EN_PROGRESO',         'En Progreso',                      'PROCESO',  0, 1, 'Estudio en ejecución activa de pasos automáticos'),
    ('PAUSADO',             'Pausado',                          'PROCESO',  0, 0, 'Cliente se retiró de la tienda; estudio en espera de reanudación'),
    ('PENDIENTE_OTP',       'Pendiente Validación OTP',         'PROCESO',  0, 1, 'Esperando que el cliente valide el token de seguridad'),
    ('PENDIENTE_BIOMETRIA', 'Pendiente Biometría',              'PROCESO',  0, 1, 'Esperando captura y validación biométrica'),
    ('PENDIENTE_CALL',      'Pendiente Gestión Call Center',    'PROCESO',  0, 0, 'Derivado a call center por fallo en automatización (UBICA, biometría)'),
    ('CUPO_PREAPROBADO',    'Cupo Preaprobado',                 'PROCESO',  0, 1, 'Cupo calculado exitosamente, pendiente verificación de identidad'),
    ('APROBADO',            'Aprobado y Activado',              'TERMINAL', 1, 0, 'Cupo activado exitosamente, disponible para uso'),
    ('RECHAZADO',           'Rechazado',                        'TERMINAL', 1, 0, 'Solicitud rechazada por alguna validación (listas, preselecta, biometría, etc.)'),
    ('EXPIRADO',            'Expirado',                         'TERMINAL', 1, 0, 'Solicitud expirada por inactividad (configurable, default 90 días)'),
    ('CANCELADO_CLIENTE',   'Cancelado por el Cliente',         'TERMINAL', 1, 0, 'El cliente solicitó cancelar el proceso voluntariamente');
GO


-- ─────────────────────────────────────────────────────────────────────────
-- 2.4  TransicionesEstado
-- Máquina de estados: define las transiciones VÁLIDAS entre estados.
-- Cualquier transición no registrada aquí es inválida por diseño.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE TransicionesEstado (
    IdTransicion        INT IDENTITY(1,1)   NOT NULL,
    IdEstadoOrigen      INT                 NOT NULL,
    IdEstadoDestino     INT                 NOT NULL,
    RequiereMotivo      BIT                 NOT NULL    DEFAULT 0,
    Descripcion         NVARCHAR(200)       NULL,
    Activa              BIT                 NOT NULL    DEFAULT 1,

    CONSTRAINT PK_TransicionesEstado PRIMARY KEY (IdTransicion),
    CONSTRAINT FK_Transiciones_Origen FOREIGN KEY (IdEstadoOrigen) REFERENCES CatalogoEstados(IdEstado),
    CONSTRAINT FK_Transiciones_Destino FOREIGN KEY (IdEstadoDestino) REFERENCES CatalogoEstados(IdEstado),
    CONSTRAINT UQ_Transiciones_OrigenDestino UNIQUE (IdEstadoOrigen, IdEstadoDestino)
);

-- Datos semilla: transiciones válidas del flujo
-- (Los IDs asumen el orden de inserción de CatalogoEstados: 1=BORRADOR, 2=EN_PROGRESO, etc.)
INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion) VALUES
    -- Desde BORRADOR
    (1,  2,  0, 'Iniciar procesamiento del estudio'),
    (1, 11, 0, 'Cancelación voluntaria antes de iniciar'),
    -- Desde EN_PROGRESO
    (2,  3,  0, 'Cliente se retira, pausar estudio'),
    (2,  4,  0, 'Paso de tokenización: esperar OTP'),
    (2,  5,  0, 'Paso biométrico: esperar captura'),
    (2,  6,  1, 'Fallo automático: derivar a call center'),
    (2,  7,  0, 'Cupo calculado exitosamente'),
    (2,  8,  0, 'Todas las validaciones aprobadas, cupo activado'),
    (2,  9,  1, 'Rechazado por validación de riesgo'),
    (2, 11, 0, 'Cancelación voluntaria durante el proceso'),
    -- Desde PAUSADO
    (3,  2,  0, 'Cliente regresa, reanudar estudio desde IdPasoActual'),
    (3, 10, 0, 'Estudio expiró por inactividad'),
    (3, 11, 0, 'Cancelación voluntaria mientras pausado'),
    -- Desde PENDIENTE_OTP
    (4,  2,  0, 'OTP validado exitosamente, continuar flujo'),
    (4,  3,  0, 'Cliente se retira, pausar'),
    (4,  9,  1, 'OTP fallido, intentos agotados'),
    -- Desde PENDIENTE_BIOMETRIA
    (5,  2,  0, 'Biometría validada exitosamente, continuar flujo'),
    (5,  3,  0, 'Cliente se retira, pausar'),
    (5,  6,  1, 'Biometría fallida, derivar a call center / fábrica'),
    (5,  9,  1, 'Biometría rechazada definitivamente'),
    -- Desde PENDIENTE_CALL
    (6,  2,  0, 'Call center resuelve exitosamente, continuar flujo'),
    (6,  8,  0, 'Call center aprueba y activa directamente'),
    (6,  9,  1, 'Call center rechaza la solicitud'),
    -- Desde CUPO_PREAPROBADO
    (7,  2,  0, 'Continuar a verificación de identidad'),
    (7,  3,  0, 'Cliente se retira, pausar'),
    (7, 11, 0, 'Cancelación voluntaria con cupo preaprobado');
GO


-- ─────────────────────────────────────────────────────────────────────────
-- 2.5  ConfiguracionReglasNegocio
-- Parámetros configurables del sistema. Permiten ajustar comportamiento
-- sin modificar código fuente. Soportan vigencia temporal.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE ConfiguracionReglasNegocio (
    IdRegla             INT IDENTITY(1,1)   NOT NULL,
    Codigo              VARCHAR(50)         NOT NULL,
    Nombre              NVARCHAR(150)       NOT NULL,
    Valor               NVARCHAR(500)       NOT NULL,   -- Valor del parámetro (se interpreta según TipoDato)
    TipoDato            VARCHAR(20)         NOT NULL    DEFAULT 'INT',
    Categoria           VARCHAR(30)         NOT NULL,   -- ENFRIAMIENTO, OTP, BIOMETRIA, RIESGO, GENERAL
    Descripcion         NVARCHAR(500)       NULL,
    VigenciaDesde       DATE                NOT NULL    DEFAULT GETDATE(),
    VigenciaHasta       DATE                NULL,       -- NULL = vigente indefinidamente
    FechaCreacion       DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaActualizacion  DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_ConfigReglasNegocio PRIMARY KEY (IdRegla),
    CONSTRAINT UQ_ConfigReglasNegocio_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_ConfigReglas_TipoDato CHECK (TipoDato IN ('INT','DECIMAL','BOOL','TEXT','JSON'))
);

-- Datos semilla: reglas de negocio iniciales
INSERT INTO ConfiguracionReglasNegocio (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_ENFRIAMIENTO',           'Días de Enfriamiento por Rechazo',         '90',       'INT',      'ENFRIAMIENTO', 'Días que un cliente rechazado debe esperar para solicitar nuevamente'),
    ('DIAS_EXPIRACION_ESTUDIO',     'Días de Expiración del Estudio',           '90',       'INT',      'GENERAL',      'Días de inactividad antes de que un estudio expire automáticamente'),
    ('INTENTOS_OTP_MAX',            'Intentos Máximos de OTP',                  '3',        'INT',      'OTP',          'Número máximo de intentos de validación OTP antes de bloqueo temporal'),
    ('VIGENCIA_OTP_SEG',            'Vigencia del Token OTP (segundos)',        '300',      'INT',      'OTP',          'Tiempo de vida del token OTP en segundos (default 5 min)'),
    ('BLOQUEO_OTP_HORAS',           'Horas de Bloqueo por OTP Fallidos',       '24',       'INT',      'OTP',          'Horas de bloqueo después de exceder intentos máximos de OTP'),
    ('INTENTOS_BIOMETRIA_MAX',      'Intentos Máximos de Biometría',           '3',        'INT',      'BIOMETRIA',    'Número máximo de intentos biométricos antes de derivar a fábrica'),
    ('UMBRAL_MATCH_FACIAL',         'Umbral de Coincidencia Facial (%)',        '85.00',    'DECIMAL',  'BIOMETRIA',    'Porcentaje mínimo de coincidencia facial para aprobación automática'),
    ('DIAS_CANCELACION_REACTIV',    'Días Desde Cancelación para Reactivación', '365',     'INT',      'GENERAL',      'Días desde cancelación voluntaria tras los cuales se permite reactivación');
GO


-- ═══════════════════════════════════════════════════════════════════════════
-- GRUPO 3: TABLAS TRANSACCIONALES (6 tablas)
-- Registros operativos del proceso de originación de crédito.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 3.1  EstudiosCredito
-- TABLA CENTRAL que orquesta todo el flujo de otorgamiento.
-- Cada registro representa un estudio/solicitud de crédito individual.
-- El campo IdPasoActual actúa como CURSOR para pausa/reanudación.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE EstudiosCredito (
    IdEstudio           BIGINT IDENTITY(1,1) NOT NULL,
    IdCliente           INT                 NOT NULL,
    IdAsesor            INT                 NULL,       -- Asesor que gestiona (NULL si es canal web)
    IdTienda            INT                 NULL,       -- Tienda de origen (NULL si es web/call)
    IdCanal             INT                 NOT NULL,   -- Canal de originación
    IdEstadoActual      INT                 NOT NULL,   -- Estado actual de la máquina de estados
    IdPasoActual        INT                 NULL,       -- CURSOR: último paso ejecutado (para pausa/reanudación)

    -- Resultado
    MotivoRechazo       NVARCHAR(200)       NULL,       -- Razón textual si fue rechazado
    CupoPreaprobado     DECIMAL(18,2)       NULL,       -- Monto del cupo preaprobado

    -- Banderas de proceso
    EsPreaprobado       BIT                 NOT NULL    DEFAULT 0,
    EsReactivacion      BIT                 NOT NULL    DEFAULT 0,  -- ¿Es reactivación de cupo cancelado?
    RequiereCallCenter  BIT                 NOT NULL    DEFAULT 0,  -- ¿Se derivó a call center?

    -- Control temporal
    FechaInicio         DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaUltimaActividad DATETIME2(3)       NOT NULL    DEFAULT GETDATE(),
    FechaFinalizacion   DATETIME2(3)        NULL,       -- NULL mientras esté en progreso
    FechaPausa          DATETIME2(3)        NULL,       -- Fecha en que se pausó (NULL si no pausado)

    FechaCreacion       DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaActualizacion  DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_EstudiosCredito PRIMARY KEY (IdEstudio),
    CONSTRAINT FK_EstudiosCredito_Cliente FOREIGN KEY (IdCliente) REFERENCES Clientes(IdCliente),
    CONSTRAINT FK_EstudiosCredito_Asesor FOREIGN KEY (IdAsesor) REFERENCES Asesores(IdAsesor),
    CONSTRAINT FK_EstudiosCredito_Tienda FOREIGN KEY (IdTienda) REFERENCES Tiendas(IdTienda),
    CONSTRAINT FK_EstudiosCredito_Canal FOREIGN KEY (IdCanal) REFERENCES CanalesOrigen(IdCanal),
    CONSTRAINT FK_EstudiosCredito_Estado FOREIGN KEY (IdEstadoActual) REFERENCES CatalogoEstados(IdEstado),
    CONSTRAINT FK_EstudiosCredito_Paso FOREIGN KEY (IdPasoActual) REFERENCES PasosEstudio(IdPaso)
);

CREATE INDEX IX_EstudiosCredito_Cliente ON EstudiosCredito(IdCliente);
CREATE INDEX IX_EstudiosCredito_Estado ON EstudiosCredito(IdEstadoActual);
CREATE INDEX IX_EstudiosCredito_Asesor ON EstudiosCredito(IdAsesor) WHERE IdAsesor IS NOT NULL;
CREATE INDEX IX_EstudiosCredito_Tienda ON EstudiosCredito(IdTienda) WHERE IdTienda IS NOT NULL;
CREATE INDEX IX_EstudiosCredito_FechaInicio ON EstudiosCredito(FechaInicio);
-- Índice compuesto para validar "Estudio activo en los últimos 90 días"
CREATE INDEX IX_EstudiosCredito_ClienteFecha ON EstudiosCredito(IdCliente, FechaInicio) INCLUDE (IdEstadoActual);
-- Índice para cola de call center
CREATE INDEX IX_EstudiosCredito_CallCenter ON EstudiosCredito(RequiereCallCenter, IdEstadoActual) WHERE RequiereCallCenter = 1;


-- ─────────────────────────────────────────────────────────────────────────
-- 3.2  RetosSeguridad
-- OTP, tokenización y retos de verificación de seguridad.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE RetosSeguridad (
    IdReto              BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdCliente           INT                 NOT NULL,   -- Redundancia controlada para consultas rápidas
    CanalEnvio          VARCHAR(20)         NOT NULL,   -- WHATSAPP, EMAIL, SMS
    HashToken           VARCHAR(256)        NOT NULL,   -- Hash del token (NUNCA texto plano por seguridad)
    FechaEnvio          DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaExpiracion     DATETIME2(3)        NOT NULL,
    FechaValidacion     DATETIME2(3)        NULL,       -- NULL si aún no se ha validado
    NumeroIntentos      INT                 NOT NULL    DEFAULT 0,
    Exitoso             BIT                 NOT NULL    DEFAULT 0,

    CONSTRAINT PK_RetosSeguridad PRIMARY KEY (IdReto),
    CONSTRAINT FK_RetosSeguridad_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_RetosSeguridad_Cliente FOREIGN KEY (IdCliente) REFERENCES Clientes(IdCliente),
    CONSTRAINT CK_RetosSeguridad_Canal CHECK (CanalEnvio IN ('WHATSAPP','EMAIL','SMS'))
);

-- Índice para regla de "Bloqueo 24h por intentos fallidos"
CREATE INDEX IX_RetosSeguridad_ClienteFecha ON RetosSeguridad(IdCliente, FechaEnvio);
CREATE INDEX IX_RetosSeguridad_Estudio ON RetosSeguridad(IdEstudio);


-- ─────────────────────────────────────────────────────────────────────────
-- 3.3  EvaluacionesRiesgo
-- Resultados de listas restrictivas, buró, Preselecta, FOSYGA.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE EvaluacionesRiesgo (
    IdEvaluacion        BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdPaso              INT                 NULL,       -- Paso que generó esta evaluación
    TipoEvaluacion      VARCHAR(30)         NOT NULL,   -- LISTAS, BURO, PRESELECTA, FOSYGA

    -- Resultados clave (desnormalizados para consulta rápida)
    CoincidenciaListasRestrictivas BIT      NOT NULL    DEFAULT 0,  -- 1 = tiene antecedentes
    ScoreBuro           INT                 NULL,
    ViablePreselecta    BIT                 NULL,
    EsPensionado        BIT                 NULL,       -- Mayor de 75 años
    TieneSeguridadSocial BIT               NULL,       -- Cotizante activo en FOSYGA/ADRES

    -- Resultado general
    Resultado           VARCHAR(20)         NOT NULL,   -- APROBADO, RECHAZADO, PENDIENTE, ERROR
    MotivoResultado     NVARCHAR(200)       NULL,

    FechaEvaluacion     DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_EvaluacionesRiesgo PRIMARY KEY (IdEvaluacion),
    CONSTRAINT FK_EvaluacionesRiesgo_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_EvaluacionesRiesgo_Paso FOREIGN KEY (IdPaso) REFERENCES PasosEstudio(IdPaso),
    CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (TipoEvaluacion IN ('LISTAS','BURO','PRESELECTA','FOSYGA')),
    CONSTRAINT CK_EvaluacionesRiesgo_Resultado CHECK (Resultado IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR'))
);

CREATE INDEX IX_EvaluacionesRiesgo_Estudio ON EvaluacionesRiesgo(IdEstudio);
CREATE INDEX IX_EvaluacionesRiesgo_Tipo ON EvaluacionesRiesgo(TipoEvaluacion, Resultado);


-- ─────────────────────────────────────────────────────────────────────────
-- 3.4  RegistrosBiometria
-- Biometría facial, OCR de documento, prueba de vida.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE RegistrosBiometria (
    IdBiometria         BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdTransaccionProveedor VARCHAR(100)     NULL,       -- ID de transacción del proveedor biométrico
    TipoVerificacion    VARCHAR(20)         NOT NULL,   -- ONBOARDING (nueva), AUTENTICACION (selfie vs almacenada)

    -- Resultados
    PruebaVidaAprobada  BIT                 NOT NULL    DEFAULT 0,
    PorcentajeCoincidencia DECIMAL(5,2)     NULL,       -- % de match facial
    EstadoOCR           VARCHAR(20)         NULL,       -- OK, DATOS_NO_COINCIDEN, DOC_INVALIDO

    NumeroIntentos      INT                 NOT NULL    DEFAULT 1,
    EstadoProceso       VARCHAR(20)         NOT NULL,   -- EXITOSO, FALLIDO, REVISION_MANUAL

    FechaRegistro       DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_RegistrosBiometria PRIMARY KEY (IdBiometria),
    CONSTRAINT FK_RegistrosBiometria_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT CK_RegistrosBiometria_Tipo CHECK (TipoVerificacion IN ('ONBOARDING','AUTENTICACION')),
    CONSTRAINT CK_RegistrosBiometria_Estado CHECK (EstadoProceso IN ('EXITOSO','FALLIDO','REVISION_MANUAL'))
);

CREATE INDEX IX_RegistrosBiometria_Estudio ON RegistrosBiometria(IdEstudio);


-- ─────────────────────────────────────────────────────────────────────────
-- 3.5  ValidacionesContactabilidad
-- Resultado de validación UBICA, clasificación Grupo A (auto) / B (manual).
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE ValidacionesContactabilidad (
    IdValidacion        BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    ScoreUbica          VARCHAR(30)         NULL,       -- OK_UBICA_CEL, SIN_INFO, INCONSISTENTE, etc.
    EsActivacionAutomatica BIT              NOT NULL    DEFAULT 0, -- Grupo A = auto, Grupo B = manual

    -- Gestión manual (Call Center)
    EstadoVerificacionManual VARCHAR(20)    NULL,       -- PENDIENTE, CONFIRMADO, RECHAZADO
    IdAsesorCallCenter  INT                 NULL,       -- Operador de call center que gestionó
    ComentariosAgente   NVARCHAR(500)       NULL,

    FechaVerificacion   DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_ValidacionesContactabilidad PRIMARY KEY (IdValidacion),
    CONSTRAINT FK_ValidContact_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_ValidContact_Asesor FOREIGN KEY (IdAsesorCallCenter) REFERENCES Asesores(IdAsesor),
    CONSTRAINT CK_ValidContact_EstadoManual CHECK (
        EstadoVerificacionManual IS NULL OR
        EstadoVerificacionManual IN ('PENDIENTE','CONFIRMADO','RECHAZADO')
    )
);

CREATE INDEX IX_ValidContact_Estudio ON ValidacionesContactabilidad(IdEstudio);
-- Índice para cola de gestión manual en call center
CREATE INDEX IX_ValidContact_Pendientes ON ValidacionesContactabilidad(EstadoVerificacionManual)
    WHERE EstadoVerificacionManual = 'PENDIENTE';


-- ─────────────────────────────────────────────────────────────────────────
-- 3.6  ConsentimientosLegales ya esxiste en terceros, ideal usar esta tabla 
-- tambien para unirlo al estudio de credito y asi tener toda la trazabilidad
-- Registro de aceptación de términos, autorizaciones y consentimientos.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE ConsentimientosLegales (
    IdConsentimiento    BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdCliente           INT                 NOT NULL,
    TipoConsentimiento  VARCHAR(40)         NOT NULL,   -- TRATAMIENTO_DATOS, TERMINOS_CREDITO, CONSULTA_CENTRALES
    VersionDocumento    VARCHAR(20)         NULL,       -- Versión del documento legal aceptado (ej. v2.3)
    Aceptado            BIT                 NOT NULL    DEFAULT 0,
    DireccionIP         VARCHAR(45)         NULL,       -- IPv4 o IPv6 del dispositivo
    UserAgent           NVARCHAR(500)       NULL,       -- Navegador / dispositivo
    FechaAceptacion     DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_ConsentimientosLegales PRIMARY KEY (IdConsentimiento),
    CONSTRAINT FK_Consentimientos_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_Consentimientos_Cliente FOREIGN KEY (IdCliente) REFERENCES Clientes(IdCliente)
);

CREATE INDEX IX_Consentimientos_Estudio ON ConsentimientosLegales(IdEstudio);
CREATE INDEX IX_Consentimientos_Cliente ON ConsentimientosLegales(IdCliente);


-- ═══════════════════════════════════════════════════════════════════════════
-- GRUPO 4: TABLAS DE AUDITORÍA (3 tablas)
-- Trazabilidad inmutable, auditoría de cambios y logging de servicios.
-- REGLA FUNDAMENTAL: los registros en estas tablas NUNCA se modifican
-- ni eliminan. Son de solo INSERT.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────
-- 4.1  HistorialEstados
-- MÁQUINA DE ESTADOS INMUTABLE.
-- Cada cambio de estado del estudio genera exactamente un registro.
-- Permite reconstruir la línea de tiempo completa: cuándo, quién, cómo, por qué.
-- NUNCA se UPDATE ni DELETE en esta tabla.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE HistorialEstados (
    IdHistorial         BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdEstadoAnterior    INT                 NULL,       -- NULL para el primer estado (BORRADOR)
    IdEstadoNuevo       INT                 NOT NULL,
    IdPasoRelacionado   INT                 NULL,       -- Paso que provocó el cambio (si aplica)

    -- Quién y por qué
    IdUsuarioAccion     INT                 NULL,       -- IdAsesor o ID de sistema
    TipoUsuario         VARCHAR(20)         NOT NULL    DEFAULT 'SISTEMA',
    MotivoTransicion    NVARCHAR(500)       NULL,       -- Motivo o descripción del cambio

    FechaTransicion     DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_HistorialEstados PRIMARY KEY (IdHistorial),
    CONSTRAINT FK_HistEstados_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_HistEstados_EstAnterior FOREIGN KEY (IdEstadoAnterior) REFERENCES CatalogoEstados(IdEstado),
    CONSTRAINT FK_HistEstados_EstNuevo FOREIGN KEY (IdEstadoNuevo) REFERENCES CatalogoEstados(IdEstado),
    CONSTRAINT FK_HistEstados_Paso FOREIGN KEY (IdPasoRelacionado) REFERENCES PasosEstudio(IdPaso),
    CONSTRAINT CK_HistEstados_TipoUsr CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CALL_CENTER'))
);

-- Índice para reconstruir la línea de tiempo de un estudio
CREATE INDEX IX_HistEstados_Estudio ON HistorialEstados(IdEstudio, FechaTransicion);
-- Índice para dashboards y métricas: ¿cuántos estudios pasaron a estado X en fecha Y?
CREATE INDEX IX_HistEstados_EstadoFecha ON HistorialEstados(IdEstadoNuevo, FechaTransicion);


-- ─────────────────────────────────────────────────────────────────────────
-- 4.2  AuditoriaCambiosDatos
-- REGISTRO DE CAMBIOS EN DATOS MUTABLES.
-- Si el cliente cambia correo, celular o dirección DURANTE un estudio
-- de crédito, se registra: valor anterior, valor nuevo, estudio vinculado.
-- Permite saber exactamente qué datos tenía el cliente en cada momento.
-- NUNCA se UPDATE ni DELETE en esta tabla.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE AuditoriaCambiosDatos (
    IdAuditoria         BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NULL,       -- Estudio en curso al momento del cambio (NULL si fuera de estudio)
    IdCliente           INT                 NOT NULL,
    NombreTabla         VARCHAR(50)         NOT NULL,   -- Tabla donde ocurrió el cambio (ej. 'Clientes')
    NombreCampo         VARCHAR(50)         NOT NULL,   -- Campo modificado (ej. 'Correo', 'Celular')
    ValorAnterior       NVARCHAR(500)       NULL,       -- Valor antes del cambio
    ValorNuevo          NVARCHAR(500)       NULL,       -- Valor después del cambio

    IdUsuarioAccion     INT                 NULL,       -- Quién realizó el cambio
    TipoUsuario         VARCHAR(20)         NOT NULL    DEFAULT 'SISTEMA',

    FechaCambio         DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),

    CONSTRAINT PK_AuditoriaCambiosDatos PRIMARY KEY (IdAuditoria),
    CONSTRAINT FK_AuditCambios_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_AuditCambios_Cliente FOREIGN KEY (IdCliente) REFERENCES Clientes(IdCliente)
);

-- Índice para historial de cambios de un cliente
CREATE INDEX IX_AuditCambios_Cliente ON AuditoriaCambiosDatos(IdCliente, FechaCambio);
-- Índice para cambios asociados a un estudio específico
CREATE INDEX IX_AuditCambios_Estudio ON AuditoriaCambiosDatos(IdEstudio) WHERE IdEstudio IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────
-- 4.3  RegistroServiciosExternos
-- PAYLOAD COMPLETO DE REQUEST/RESPONSE.
-- Almacena cada invocación a servicios externos (buró, biometría, UBICA,
-- OTP, Preselecta, FOSYGA, etc.) con los payloads JSON completos.
-- Fundamental para auditoría, debugging y resolución de disputas.
-- NUNCA se UPDATE ni DELETE en esta tabla.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE RegistroServiciosExternos (
    IdRegistro          BIGINT IDENTITY(1,1) NOT NULL,
    IdEstudio           BIGINT              NOT NULL,
    IdPaso              INT                 NULL,       -- Paso que disparó la invocación

    NombreServicio      VARCHAR(50)         NOT NULL,   -- PRESELECTA, BURO, UBICA, BIOMETRIA, OTP, FOSYGA, etc.
    URLEndpoint         NVARCHAR(500)       NULL,       -- URL del servicio invocado
    MetodoHTTP          VARCHAR(10)         NULL,       -- GET, POST, PUT

    -- Payloads completos en JSON
    PayloadRequest      NVARCHAR(MAX)       NULL,       -- Request enviado al servicio externo
    PayloadResponse     NVARCHAR(MAX)       NULL,       -- Response recibido del servicio externo
    CodigoHTTPRespuesta INT                 NULL,       -- 200, 400, 500, etc.

    -- Resultado interpretado
    ResultadoInterpretado VARCHAR(20)       NOT NULL,   -- EXITOSO, FALLIDO, TIMEOUT, ERROR
    MensajeError        NVARCHAR(500)       NULL,       -- Mensaje de error si aplica

    -- Métricas de rendimiento
    DuracionMs          INT                 NULL,       -- Tiempo de respuesta en milisegundos
    FechaInvocacion     DATETIME2(3)        NOT NULL    DEFAULT GETDATE(),
    FechaRespuesta      DATETIME2(3)        NULL,

    CONSTRAINT PK_RegServiciosExternos PRIMARY KEY (IdRegistro),
    CONSTRAINT FK_RegServExt_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
    CONSTRAINT FK_RegServExt_Paso FOREIGN KEY (IdPaso) REFERENCES PasosEstudio(IdPaso),
    CONSTRAINT CK_RegServExt_Resultado CHECK (ResultadoInterpretado IN ('EXITOSO','FALLIDO','TIMEOUT','ERROR'))
);

-- Índice para ver todas las llamadas de un estudio (timeline de servicios)
CREATE INDEX IX_RegServExt_Estudio ON RegistroServiciosExternos(IdEstudio, FechaInvocacion);
-- Índice para monitoreo operativo: ¿cuántos errores por servicio?
CREATE INDEX IX_RegServExt_Servicio ON RegistroServiciosExternos(NombreServicio, ResultadoInterpretado, FechaInvocacion);
-- Índice para análisis de rendimiento
CREATE INDEX IX_RegServExt_Duracion ON RegistroServiciosExternos(NombreServicio, DuracionMs) WHERE DuracionMs IS NOT NULL;


-- ═══════════════════════════════════════════════════════════════════════════
-- RESUMEN DEL MODELO
-- ═══════════════════════════════════════════════════════════════════════════
/*
  ┌──────────────────────────────────────────────────────────────────────┐
  │ GRUPO 1 - MAESTRAS (5 tablas)                                       │
  ├──────────────────────────────────────────────────────────────────────┤
  │  1. Tiendas                       — Puntos físicos de venta         │
  │  2. Asesores                      — Personal que gestiona           │
  │  3. Clientes                      — Datos aislados para crédito     │
  │  4. ProductosCredito              — Cupos otorgados                 │
  │  5. CanalesOrigen                 — Catálogo de canales             │
  ├──────────────────────────────────────────────────────────────────────┤
  │ GRUPO 2 - CONFIGURACIÓN (5 tablas)                                  │
  ├──────────────────────────────────────────────────────────────────────┤
  │  6. FasesEstudio                  — 7 fases macro del proceso       │
  │  7. PasosEstudio                  — 13 pasos con orquestación       │
  │  8. CatalogoEstados               — 11 estados posibles             │
  │  9. TransicionesEstado            — Transiciones válidas            │
  │ 10. ConfiguracionReglasNegocio    — Parámetros configurables        │
  ├──────────────────────────────────────────────────────────────────────┤
  │ GRUPO 3 - TRANSACCIONALES (6 tablas)                                │
  ├──────────────────────────────────────────────────────────────────────┤
  │ 11. EstudiosCredito               — Tabla central del proceso       │
  │ 12. RetosSeguridad                — OTP y tokenización              │
  │ 13. EvaluacionesRiesgo            — Listas, buró, Preselecta       │
  │ 14. RegistrosBiometria            — Biometría facial, OCR           │
  │ 15. ValidacionesContactabilidad   — UBICA, activación auto/manual   │
  │ 16. ConsentimientosLegales        — Aceptación de términos          │
  ├──────────────────────────────────────────────────────────────────────┤
  │ GRUPO 4 - AUDITORÍA (3 tablas)                                      │
  ├──────────────────────────────────────────────────────────────────────┤
  │ 17. HistorialEstados              — Timeline inmutable de estados   │
  │ 18. AuditoriaCambiosDatos         — Log de cambios mutables         │
  │ 19. RegistroServiciosExternos     — Request/Response servicios ext  │
  └──────────────────────────────────────────────────────────────────────┘

  TOTAL: 19 tablas | ~35 índices | ~25 CHECK constraints
  Motor: SQL Server 2019+ | Normalización: 3NF
  
  ARQUITECTURA DE TRAZABILIDAD:
  • Inmutable:  HistorialEstados (quién, cuándo, cómo, por qué)
  • Mutable:    AuditoriaCambiosDatos (valor viejo → nuevo, vinculado a estudio)
  • Servicios:  RegistroServiciosExternos (Request + Response JSON completo)
  • Pausa:      EstudiosCredito.IdPasoActual (cursor de reanudación)
  • Cooling:    Clientes.FechaDesbloqueo + ConfiguracionReglasNegocio.DIAS_ENFRIAMIENTO
*/
