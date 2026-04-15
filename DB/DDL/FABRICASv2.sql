/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS V2
  Motor:    SQL Server 2019+
  Versión:  2.3
  Fecha:    2026-04-13
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  ESTRUCTURA DEL SCRIPT:
  ─────────────────────────────────────────────────────────────────────────────
  1. TABLAS DE CONFIGURACIÓN (6 tablas)      → Parametrización del flujo
  2. MODIFICACIÓN DE TABLAS EXISTENTES        → ALTER TABLE a tablas prod.
  3. TABLAS TRANSACCIONALES (7 tablas)        → Operaciones del proceso
  4. TABLAS DE AUDITORÍA (3 tablas)           → Trazabilidad inmutable
  5. PARCHES V2.2 — SENIOR ARCHITECT AUDIT    → Tablas y columnas de fraude/escalamiento
  6. DATOS SEMILLA (SEEDS)                    → Catálogos iniciales
  7. PARCHES V2.3 — GESTIÓN DE FOTOGRAFÍAS    → Ciclo de vida de fotos, revisión, re-carga
  
  NOTAS:
  - Las tablas QUAC.dbo.terceros, QUAC.dbo.bodegas, PRUEBASBD.dbo.kcrm_VendedoresExternos,
    QUAC.dbo.BERP_FABRICASOperadores y QUAC.dbo.KCRM_CadenaCreditos YA EXISTEN
  - Solo se les añaden columnas necesarias mediante ALTER TABLE
  - Las nuevas tablas mantienen coherencia de tipos con las existentes
  
  CAMBIOS v2.1:
  - G-DB-01: Nueva tabla CatalogoCanalesOrigen + FK desde EstudiosCredito.IdCanal
  - G-DB-02: FK física de EstudiosCredito.NitTercero → TercerosFabricas.NitTercero
  - G-DB-03: Ampliación CHECK TipoEvaluacion (ANTECEDENTES, UBICA añadidos)
  - G-DB-04: Columna EstadoUbica en ValidacionesContactabilidad
  - G-DB-05: Columnas NumeroReenvios y UltimoReenvio en RetosSeguridad
  - G-DB-06: Columnas EmailCliente y EmailUbica en EstudiosCredito
  - G-DB-07: Columnas SlugPasoWeb y FechaUltimoAbandono en EstudiosCredito
  - G-DB-08: Columnas OCR en RegistrosBiometria
  - G-DB-09: Columna TipoFirma en ConsentimientosLegales
  - GT-04: Columnas EsCupoExpress y TipoCierre en EstudiosCredito
  - GT-05: Columnas de dirección capturada en EstudiosCredito
  - GT-08: Nueva tabla EvidenciasFabrica

  CAMBIOS v2.2 — Senior Architect Audit (2026-04-10):
  - SA-01: Nueva tabla CatalogoMotivosEscalamiento (catálogo tipificado de razones)
  - SA-02: Nueva tabla EscalamientosFabrica (trazabilidad completa para asesor)
  - SA-03: Nueva tabla LogValidacionesOTP (log granular de intentos, INSERT-ONLY)
  - SA-04: Nueva tabla HistorialDatosSensibles (mutaciones email/cel con contexto)
  - SA-05: Nueva tabla AlertasFraude (registro inmutable de alertas, INSERT-ONLY)
  - SA-06: Nueva tabla CatalogoReglasFraude (tipificación de reglas de detección)
  - SA-07: EstudiosCredito +ClaveIdempotencia +VersionFila +EliminadoLogico +IdCorrelacion +IdEscalamientoActivo
  - SA-08: HistorialEstados +IdCorrelacion
  - SA-09: RetosSeguridad +DireccionEnvio
  - SA-10: ValidacionesContactabilidad +IdAlertaFraude +FK
  - SA-11: CatalogoEstados: estados REVISION_FABRICA y BLOQUEADO_FRAUDE + 6 transiciones

  CAMBIOS v2.3 — Gestión de Fotografías / Módulo de Revisión (2026-04-13):
  - PH-01: Nueva tabla CatalogoTiposFotografia (catálogo de los 3 tipos obligatorios)
  - PH-02: Nueva tabla FotografiasEstudio (ciclo de vida individual de cada foto)
  - PH-03: Nueva tabla RevisionesFotografia (decisiones de revisión, INSERT-ONLY)
  - PH-04: Nueva tabla SolicitudesRecarga (links de re-carga enviados al cliente)
  - PH-05: Nueva tabla HistorialFotografias (auditoría completa de cambios, INSERT-ONLY)
  - PH-06: ALTER EstudiosCredito +FotografiasAprobadas +EstadoRevisionFotos
  - PH-07: ALTER RegistrosBiometria +IdFotografiaFrontal +IdFotografiaReverso +IdFotografiaSelfie
  - PH-08: Estados PENDIENTE_FOTOS + FOTOS_EN_REVISION + transiciones
  - PH-09: ConfiguracionReglasNegocio: parámetros de foto (vigencia link, reintentos)
  - PH-10: Seeds para todos los catálogos de fotografía
================================================================================
*/

-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 1: TABLAS DE CONFIGURACIÓN (MAQUINA DE ESTADOS)
-- ==============================================================================
-- Estas tablas definen el flujo, estados y reglas de negocio.
-- Se crean desde cero ya que no existen en el sistema actual.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.1 FasesEstudio: Las 7 fases macro del proceso de otorgamiento
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'FasesEstudio') AND type in (N'U'))
BEGIN
    CREATE TABLE FasesEstudio (
        IdFase              INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(30)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        OrdenEjecucion      INT                 NOT NULL,
        Descripcion         NVARCHAR(500)       NULL,
        Activa              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_FasesEstudio PRIMARY KEY (IdFase),
        CONSTRAINT UQ_FasesEstudio_Codigo UNIQUE (Codigo),
        CONSTRAINT UQ_FasesEstudio_Orden UNIQUE (OrdenEjecucion)
    );
    PRINT '✓ Tabla FasesEstudio creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.2 PasosEstudio: Los 13 pasos individuales del flujo
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'PasosEstudio') AND type in (N'U'))
BEGIN
    CREATE TABLE PasosEstudio (
        IdPaso              INT IDENTITY(1,1)   NOT NULL,
        IdFase              INT                 NOT NULL,
        Codigo              VARCHAR(40)         NOT NULL,
        Nombre              NVARCHAR(150)       NOT NULL,
        OrdenEnFase         INT                 NOT NULL,
        OrdenGlobal         INT                 NOT NULL,
        Actor               VARCHAR(30)         NOT NULL DEFAULT 'SISTEMA',
        ServicioExterno     VARCHAR(50)         NULL,
        EsAutomatico        BIT                 NOT NULL DEFAULT 1,
        RequiereIntervencion BIT                NOT NULL DEFAULT 0,
        TiempoTimeoutSeg    INT                 NULL,
        Descripcion         NVARCHAR(500)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_PasosEstudio PRIMARY KEY (IdPaso),
        CONSTRAINT UQ_PasosEstudio_Codigo UNIQUE (Codigo),
        CONSTRAINT UQ_PasosEstudio_OrdenGlobal UNIQUE (OrdenGlobal),
        CONSTRAINT FK_PasosEstudio_Fase FOREIGN KEY (IdFase) REFERENCES FasesEstudio(IdFase),
        CONSTRAINT CK_PasosEstudio_Actor CHECK (Actor IN ('ASESOR','SISTEMA','CLIENTE','CALL_CENTER'))
    );
    
    CREATE INDEX IX_PasosEstudio_Fase ON PasosEstudio(IdFase);
    PRINT '✓ Tabla PasosEstudio creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.3 CatalogoEstados: Todos los estados posibles del estudio
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CatalogoEstados') AND type in (N'U'))
BEGIN
    CREATE TABLE CatalogoEstados (
        IdEstado            INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(40)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Grupo               VARCHAR(20)         NOT NULL,
        EsTerminal          BIT                 NOT NULL DEFAULT 0,
        PermitePausa        BIT                 NOT NULL DEFAULT 0,
        Descripcion         NVARCHAR(500)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_CatalogoEstados PRIMARY KEY (IdEstado),
        CONSTRAINT UQ_CatalogoEstados_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoEstados_Grupo CHECK (Grupo IN ('INICIAL','PROCESO','TERMINAL'))
    );
    PRINT '✓ Tabla CatalogoEstados creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.4 TransicionesEstado: Máquina de estados - transiciones válidas
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'TransicionesEstado') AND type in (N'U'))
BEGIN
    CREATE TABLE TransicionesEstado (
        IdTransicion        INT IDENTITY(1,1)   NOT NULL,
        IdEstadoOrigen      INT                 NOT NULL,
        IdEstadoDestino     INT                 NOT NULL,
        RequiereMotivo      BIT                 NOT NULL DEFAULT 0,
        Descripcion         NVARCHAR(200)       NULL,
        Activa              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_TransicionesEstado PRIMARY KEY (IdTransicion),
        CONSTRAINT FK_Transiciones_Origen FOREIGN KEY (IdEstadoOrigen) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT FK_Transiciones_Destino FOREIGN KEY (IdEstadoDestino) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT UQ_Transiciones_OrigenDestino UNIQUE (IdEstadoOrigen, IdEstadoDestino)
    );
    PRINT '✓ Tabla TransicionesEstado creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.5 ConfiguracionReglasNegocio: Parámetros configurables del sistema
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ConfiguracionReglasNegocio') AND type in (N'U'))
BEGIN
    CREATE TABLE ConfiguracionReglasNegocio (
        IdRegla             INT IDENTITY(1,1)   PRIMARY KEY,
        Codigo              VARCHAR(50)         NOT NULL,
        Nombre              NVARCHAR(150)       NOT NULL,
        Valor               NVARCHAR(500)      NOT NULL,
        TipoDato            VARCHAR(20)         NOT NULL DEFAULT 'INT',
        Categoria           VARCHAR(30)         NOT NULL,
        Descripcion         NVARCHAR(500)      NULL,
        VigenciaDesde       DATE                NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        VigenciaHasta       DATE                NULL,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT UQ_ConfigReglasNegocio_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_ConfigReglas_TipoDato CHECK (TipoDato IN ('INT','DECIMAL','BOOL','TEXT','JSON'))
    );
    PRINT '✓ Tabla ConfiguracionReglasNegocio creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.6 CatalogoCanalesOrigen: Catálogo de canales por los que ingresa el cliente
--     G-DB-01: Tabla dominio para EstudiosCredito.IdCanal
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CatalogoCanalesOrigen') AND type in (N'U'))
BEGIN
    CREATE TABLE CatalogoCanalesOrigen (
        IdCanal             INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(20)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Descripcion         NVARCHAR(300)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT SYSDATETIME(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_CatalogoCanalesOrigen PRIMARY KEY (IdCanal),
        CONSTRAINT UQ_CatalogoCanalesOrigen_Codigo UNIQUE (Codigo)
    );
    PRINT '✓ Tabla CatalogoCanalesOrigen creada';
END
GO


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: MODIFICACIÓN DE TABLAS EXISTENTES (ALTER TABLE)
-- ==============================================================================
-- Se añaden columnas a las tablas que ya existen en producción.
-- Estas mejoras permiten integrar la nueva arquitectura de fábricas.

-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1 Nueva Tabla: TercerosFabricas — Fuente de Verdad para Clientes
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Tabla propia del proceso fábricas que actúa como fuente de verdad
-- para los datos de clientes. Se integra con terceros mediante NIT como FK.
-- Estrategia: Leer de terceros para validar existencia, escribir en esta tabla
-- para el proceso de originación. Sincronización inversa hacia terceros según
-- reglas de negocio (no se altera la estructura de terceros).

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.TercerosFabricas') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.TercerosFabricas (
        IdTerceroFabricas       INT IDENTITY(1,1) NOT NULL,
        NitTercero              VARCHAR(20) NOT NULL,
        NombreTercero           VARCHAR(200) NULL,
        EstadoTercero           VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
        TieneCupoActivo        BIT NOT NULL DEFAULT 0,
        EstaBloqueadoFabricas  BIT NOT NULL DEFAULT 0,
        MotivoBloqueo          VARCHAR(100) NULL,
        FechaBloqueo           DATETIME2 NULL,
        FechaDesbloqueo        DATETIME2 NULL,
        TieneRegistroBiometrico BIT NOT NULL DEFAULT 0,
        FechaRegistroBiometrico DATETIME2 NULL,
        PuntajeCredito         DECIMAL(5,2) NULL,
        FechaUltimaEvaluacion  DATETIME2 NULL,
        FechaCreacion          DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        FechaModificacion      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT PK_TercerosFabricas PRIMARY KEY CLUSTERED (IdTerceroFabricas),
        CONSTRAINT UQ_TercerosFabricas_Nit UNIQUE (NitTercero),
        CONSTRAINT FK_TercerosFabricas_Terceros FOREIGN KEY (NitTercero)
            REFERENCES QUAC.dbo.terceros (nit) ON UPDATE NO ACTION ON DELETE NO ACTION
    );
    
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Nit ON dbo.TercerosFabricas (NitTercero);
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Estado ON dbo.TercerosFabricas (EstadoTercero, EstaBloqueadoFabricas);
    
    PRINT '✓ Tabla TercerosFabricas creada exitosamente';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 2.2 Modificar QUAC.dbo.KCRM_CadenaCreditos: Añadir estados de fábricas
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Agregar campos de estado, motivo de bloqueo y fecha de cancelación
-- para soportar la máquina de estados del proceso de crédito.

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'EstadoActualFabricas')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD EstadoActualFabricas VARCHAR(20) NULL;
    PRINT '✓ Columna EstadoActualFabricas añadida a KCRM_CadenaCreditos';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD MotivoBloqueoFabricas VARCHAR(50) NULL;
    PRINT '✓ Columna MotivoBloqueoFabricas añadida a KCRM_CadenaCreditos';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD FechaCancelacionFabricas DATETIME2 NULL;
    PRINT '✓ Columna FechaCancelacionFabricas añadida a KCRM_CadenaCreditos';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD ElegibleReactivacion BIT NOT NULL DEFAULT 0;
    PRINT '✓ Columna ElegibleReactivacion añadida a KCRM_CadenaCreditos';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 2.3 Modificar QUAC.dbo.BERP_FABRICASOperadores: Añadir campos de control
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Agregar campos para control de estados y trazabilidad.

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.BERP_FABRICASOperadores') AND name = 'Activo')
BEGIN
    ALTER TABLE QUAC.dbo.BERP_FABRICASOperadores ADD Activo BIT NOT NULL DEFAULT 1;
    PRINT '✓ Columna Activo añadida a BERP_FABRICASOperadores';
END
GO


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: TABLAS TRANSACCIONALES
-- ==============================================================================
-- Estas tablas registran las operaciones del proceso de originación de crédito.
-- Dependen de las tablas de configuración creadas anteriormente.

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.1 EstudiosCredito: Tabla central que orquesta el flujo
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND type in (N'U'))
BEGIN
    CREATE TABLE EstudiosCredito (
        IdEstudio               BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Referencia al cliente (terceros)
        NitTercero              VARCHAR(20)         NOT NULL,
        
        -- Referencias a entidades existentes
        IdTienda               INT                 NULL,       -- FK a QUAC.dbo.bodegas.id
        IdAsesor               INT                 NULL,       -- FK a BERP_FABRICASOperadores.idOperadorFabrica
        IdCanal                INT                 NULL,       -- FK a CatalogoCanalesOrigen.IdCanal (G-DB-01)
        
        -- Estado de la máquina de estados
        IdEstadoActual          INT                 NOT NULL,   -- FK a CatalogoEstados
        IdPasoActual            INT                 NULL,       -- FK a PasosEstudio (cursor de reanudación)
        
        -- Resultado del estudio
        MotivoRechazo           NVARCHAR(200)       NULL,
        CupoPreaprobado        DECIMAL(18,2)      NULL,
        
        -- Banderas de proceso
        EsPreaprobado          BIT                 NOT NULL DEFAULT 0,
        EsReactivacion         BIT                 NOT NULL DEFAULT 0,
        RequiereCallCenter     BIT                 NOT NULL DEFAULT 0,
        
        -- Tipo de cierre y cupo express (GT-04)
        EsCupoExpress          BIT                 NOT NULL DEFAULT 0,
        TipoCierre             VARCHAR(20)         NULL,
        
        -- Datos de contacto del cliente capturados en el flujo (G-DB-06)
        EmailCliente           NVARCHAR(200)       NULL,   -- Email propio declarado por el cliente
        EmailUbica             NVARCHAR(200)       NULL,   -- Email retornado por el servicio UBICA
        
        -- Punto de reanudación del flujo web (G-DB-07)
        SlugPasoWeb            VARCHAR(50)         NULL,   -- Identificador del paso web para reanudar sesión
        FechaUltimoAbandono    DATETIME2(3)        NULL,   -- Última vez que el cliente abandonó el flujo
        
        -- Dirección capturada durante el flujo (GT-05)
        -- Campos de staging: se sincronizan a terceros al aprobar el estudio
        DepartamentoCapturado  NVARCHAR(100)       NULL,
        CiudadCapturada        NVARCHAR(100)       NULL,
        DireccionCapturada     NVARCHAR(300)       NULL,
        BarrioCapturado        NVARCHAR(100)       NULL,
        
        -- Control temporal
        FechaInicio            DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaUltimaActividad   DATETIME2(3)       NOT NULL DEFAULT GETDATE(),
        FechaFinalizacion      DATETIME2(3)       NULL,
        FechaPausa             DATETIME2(3)       NULL,
        
        -- Metadatos
        FechaCreacion          DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion     DATETIME2(3)       NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_EstudiosCredito PRIMARY KEY (IdEstudio),
        CONSTRAINT FK_EstudiosCredito_Estado FOREIGN KEY (IdEstadoActual) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT FK_EstudiosCredito_Paso FOREIGN KEY (IdPasoActual) REFERENCES PasosEstudio(IdPaso),
        CONSTRAINT FK_EstudiosCredito_Canal FOREIGN KEY (IdCanal) REFERENCES CatalogoCanalesOrigen(IdCanal),  -- G-DB-01
        CONSTRAINT FK_EstudiosCredito_Tercero FOREIGN KEY (NitTercero) REFERENCES TercerosFabricas(NitTercero),  -- G-DB-02
        CONSTRAINT CK_EstudiosCredito_TipoCierre CHECK (TipoCierre IS NULL OR TipoCierre IN ('EXPRESS','NORMAL','FABRICA'))  -- GT-04
    );
    
    CREATE INDEX IX_EstudiosCredito_Cliente ON EstudiosCredito(NitTercero);
    CREATE INDEX IX_EstudiosCredito_Estado ON EstudiosCredito(IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_Asesor ON EstudiosCredito(IdAsesor) WHERE IdAsesor IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Tienda ON EstudiosCredito(IdTienda) WHERE IdTienda IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Canal ON EstudiosCredito(IdCanal) WHERE IdCanal IS NOT NULL;  -- G-DB-01
    CREATE INDEX IX_EstudiosCredito_FechaInicio ON EstudiosCredito(FechaInicio);
    CREATE INDEX IX_EstudiosCredito_ClienteFecha ON EstudiosCredito(NitTercero, FechaInicio) INCLUDE (IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_CallCenter ON EstudiosCredito(RequiereCallCenter, IdEstadoActual) WHERE RequiereCallCenter = 1;
    CREATE INDEX IX_EstudiosCredito_SlugWeb ON EstudiosCredito(SlugPasoWeb) WHERE SlugPasoWeb IS NOT NULL;  -- G-DB-07
    
    PRINT '✓ Tabla EstudiosCredito creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.2 RetosSeguridad: OTP, tokenización y retos de verificación
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RetosSeguridad') AND type in (N'U'))
BEGIN
    CREATE TABLE RetosSeguridad (
        IdReto              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        CanalEnvio          VARCHAR(20)         NOT NULL,
        HashToken           VARCHAR(256)        NOT NULL,
        FechaEnvio          DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaExpiracion     DATETIME2(3)       NOT NULL,
        FechaValidacion     DATETIME2(3)       NULL,
        NumeroIntentos      INT                 NOT NULL DEFAULT 0,
        Exitoso             BIT                 NOT NULL DEFAULT 0,
        
        -- G-DB-05: Seguimiento de reenvíos del token
        NumeroReenvios      INT                 NOT NULL DEFAULT 0,   -- Cantidad de veces que se reenvió el token
        UltimoReenvio       DATETIME2(3)        NULL,                  -- Fecha y hora del último reenvío realizado
        
        CONSTRAINT PK_RetosSeguridad PRIMARY KEY (IdReto),
        CONSTRAINT FK_RetosSeguridad_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_RetosSeguridad_Canal CHECK (CanalEnvio IN ('WHATSAPP','EMAIL','SMS'))
    );
    
    CREATE INDEX IX_RetosSeguridad_ClienteFecha ON RetosSeguridad(NitTercero, FechaEnvio);
    CREATE INDEX IX_RetosSeguridad_Estudio ON RetosSeguridad(IdEstudio);
    
    PRINT '✓ Tabla RetosSeguridad creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.3 EvaluacionesRiesgo: Listas restrictivas, buró, Preselecta, FOSYGA
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'EvaluacionesRiesgo') AND type in (N'U'))
BEGIN
    CREATE TABLE EvaluacionesRiesgo (
        IdEvaluacion                BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                  BIGINT              NOT NULL,
        IdPaso                     INT                 NULL,
        TipoEvaluacion             VARCHAR(30)         NOT NULL,
        
        -- Resultados clave
        CoincidenciaListasRestrictivas BIT            NOT NULL DEFAULT 0,
        ScoreBuro                  INT                 NULL,
        ViablePreselecta           BIT                 NULL,
        EsPensionado               BIT                 NULL,
        TieneSeguridadSocial       BIT                 NULL,
        
        -- Resultado general
        Resultado                  VARCHAR(20)         NOT NULL,
        MotivoResultado            NVARCHAR(200)       NULL,
        
        -- Payload original
        DetallesJSON               NVARCHAR(MAX)       NULL,
        
        FechaEvaluacion            DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_EvaluacionesRiesgo PRIMARY KEY (IdEvaluacion),
        CONSTRAINT FK_EvaluacionesRiesgo_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_EvaluacionesRiesgo_Paso FOREIGN KEY (IdPaso) REFERENCES PasosEstudio(IdPaso),
        -- G-DB-03: Ampliado para incluir ANTECEDENTES y UBICA
        CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (TipoEvaluacion IN ('LISTAS','BURO','PRESELECTA','FOSYGA','ANTECEDENTES','UBICA')),
        CONSTRAINT CK_EvaluacionesRiesgo_Resultado CHECK (Resultado IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR'))
    );
    
    CREATE INDEX IX_EvaluacionesRiesgo_Estudio ON EvaluacionesRiesgo(IdEstudio);
    CREATE INDEX IX_EvaluacionesRiesgo_Tipo ON EvaluacionesRiesgo(TipoEvaluacion, Resultado);
    
    PRINT '✓ Tabla EvaluacionesRiesgo creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.4 RegistrosBiometria: Biometría facial, OCR, prueba de vida
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND type in (N'U'))
BEGIN
    CREATE TABLE RegistrosBiometria (
        IdBiometria             BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio               BIGINT              NOT NULL,
        IdTransaccionProveedor  VARCHAR(100)        NULL,
        TipoVerificacion        VARCHAR(20)         NOT NULL,
        
        -- Resultados
        PruebaVidaAprobada      BIT                 NOT NULL DEFAULT 0,
        PorcentajeCoincidencia DECIMAL(5,2)        NULL,
        EstadoOCR               VARCHAR(20)         NULL,
        
        -- Control de intentos
        NumeroIntentos          INT                 NOT NULL DEFAULT 1,
        EstadoProceso           VARCHAR(20)         NOT NULL,
        
        -- G-DB-08: Campos extraídos por OCR del documento de identidad
        NombreExtraidoOCR           NVARCHAR(200)   NULL,   -- Nombre completo según OCR
        FechaExpedicionExtraidaOCR  DATE            NULL,   -- Fecha de expedición del documento según OCR
        NumeroDocumentoExtraidoOCR  VARCHAR(20)     NULL,   -- Número de documento según OCR
        CoincidenciaOCR             BIT             NULL,   -- TRUE si OCR coincide con datos declarados por el cliente
        
        FechaRegistro           DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_RegistrosBiometria PRIMARY KEY (IdBiometria),
        CONSTRAINT FK_RegistrosBiometria_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_RegistrosBiometria_Tipo CHECK (TipoVerificacion IN ('ONBOARDING','AUTENTICACION')),
        CONSTRAINT CK_RegistrosBiometria_Estado CHECK (EstadoProceso IN ('EXITOSO','FALLIDO','REVISION_MANUAL'))
    );
    
    CREATE INDEX IX_RegistrosBiometria_Estudio ON RegistrosBiometria(IdEstudio);
    
    PRINT '✓ Tabla RegistrosBiometria creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.5 ValidacionesContactabilidad: UBICA y gestión manual
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ValidacionesContactabilidad') AND type in (N'U'))
BEGIN
    CREATE TABLE ValidacionesContactabilidad (
        IdValidacion              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                 BIGINT              NOT NULL,
        ScoreUbica                VARCHAR(30)         NULL,
        EsActivacionAutomatica    BIT                 NOT NULL DEFAULT 0,
        
        -- G-DB-04: Estado granular de UBICA para enrutamiento preciso
        EstadoUbica               VARCHAR(30)         NULL,   -- Estado detallado retornado por UBICA
        
        -- Gestión manual
        EstadoVerificacionManual  VARCHAR(20)         NULL,
        IdAsesorCallCenter       INT                 NULL,
        ComentariosAgente         NVARCHAR(500)       NULL,
        
        FechaVerificacion         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ValidacionesContactabilidad PRIMARY KEY (IdValidacion),
        CONSTRAINT FK_ValidContact_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_ValidContact_EstadoManual CHECK (
            EstadoVerificacionManual IS NULL OR 
            EstadoVerificacionManual IN ('PENDIENTE','CONFIRMADO','RECHAZADO')
        ),
        -- G-DB-04: Valores válidos para el estado granular de UBICA
        CONSTRAINT CK_ValidContact_EstadoUbica CHECK (
            EstadoUbica IS NULL OR
            EstadoUbica IN ('OK_CEL_CORREO','OK_CEL','GESTION_MANUAL_CALL','GESTION_MANUAL_FABRICA','NO_CONTACTABLE','PENDIENTE')
        )
    );
    
    CREATE INDEX IX_ValidContact_Estudio ON ValidacionesContactabilidad(IdEstudio);
    CREATE INDEX IX_ValidContact_Pendientes ON ValidacionesContactabilidad(EstadoVerificacionManual) 
        WHERE EstadoVerificacionManual = 'PENDIENTE';
    CREATE INDEX IX_ValidContact_EstadoUbica ON ValidacionesContactabilidad(EstadoUbica)  -- G-DB-04
        WHERE EstadoUbica IS NOT NULL;
    
    PRINT '✓ Tabla ValidacionesContactabilidad creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.6 ConsentimientosLegales: Trazabilidad de aceptaciones
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ConsentimientosLegales') AND type in (N'U'))
BEGIN
    CREATE TABLE ConsentimientosLegales (
        IdConsentimiento      BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio            BIGINT              NOT NULL,
        NitTercero           VARCHAR(20)         NOT NULL,
        TipoConsentimiento   VARCHAR(40)         NOT NULL,
        VersionDocumento    VARCHAR(20)         NULL,
        Aceptado             BIT                 NOT NULL DEFAULT 0,
        DireccionIP          VARCHAR(45)         NULL,
        UserAgent            NVARCHAR(500)       NULL,
        
        -- G-DB-09: Tipo de firma utilizado para el consentimiento
        TipoFirma            VARCHAR(20)         NOT NULL DEFAULT 'CHECKBOX',
        
        FechaAceptacion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ConsentimientosLegales PRIMARY KEY (IdConsentimiento),
        CONSTRAINT FK_Consentimientos_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        -- G-DB-09: Tipos de firma admitidos
        CONSTRAINT CK_Consentimientos_TipoFirma CHECK (
            TipoFirma IN ('OTP_SMS','OTP_EMAIL','OTP_WHATSAPP','CHECKBOX','FIRMA_DIGITAL')
        )
    );
    
    CREATE INDEX IX_Consentimientos_Estudio ON ConsentimientosLegales(IdEstudio);
    CREATE INDEX IX_Consentimientos_Cliente ON ConsentimientosLegales(NitTercero);
    
    PRINT '✓ Tabla ConsentimientosLegales creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.7 EvidenciasFabrica: Archivos adjuntos y evidencias para revisión manual
--     GT-08: Tabla de evidencias/adjuntos para el proceso de revisión en fábrica
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'EvidenciasFabrica') AND type in (N'U'))
BEGIN
    CREATE TABLE EvidenciasFabrica (
        IdEvidencia         BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudioCredito    BIGINT                  NOT NULL,   -- FK al estudio de crédito asociado
        
        -- Clasificación de la evidencia
        TipoEvidencia       VARCHAR(30)             NOT NULL,   -- Tipo de documento o archivo
        
        -- Datos del archivo almacenado
        UrlArchivo          NVARCHAR(500)           NOT NULL,   -- URL o ruta de almacenamiento del archivo
        NombreArchivo       NVARCHAR(200)           NOT NULL,   -- Nombre original del archivo
        ContentType         VARCHAR(100)            NULL,       -- MIME type del archivo (ej. image/jpeg, application/pdf)
        TamanoBytes         BIGINT                  NULL,       -- Tamaño del archivo en bytes
        
        -- Trazabilidad de quien subió el archivo
        SubidoPor           NVARCHAR(100)           NOT NULL,   -- Usuario o sistema que cargó el archivo
        Observaciones       NVARCHAR(500)           NULL,       -- Notas adicionales del asesor o sistema
        
        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT SYSDATETIME(),
        
        CONSTRAINT PK_EvidenciasFabrica PRIMARY KEY (IdEvidencia),
        CONSTRAINT FK_EvidenciasFabrica_Estudio FOREIGN KEY (IdEstudioCredito) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_EvidenciasFabrica_Tipo CHECK (
            TipoEvidencia IN ('FOTO_DOCUMENTO','SELFIE','COMPROBANTE','NOTA_ASESOR','DOCUMENTO_SOPORTE','OTRO')
        )
    );
    
    -- Índice principal para consultas por estudio
    CREATE INDEX IX_EvidenciasFabrica_Estudio ON EvidenciasFabrica(IdEstudioCredito);
    -- Índice para filtrar por tipo de evidencia dentro de un estudio
    CREATE INDEX IX_EvidenciasFabrica_EstudioTipo ON EvidenciasFabrica(IdEstudioCredito, TipoEvidencia);
    -- Índice para auditoría por usuario que subió el archivo
    CREATE INDEX IX_EvidenciasFabrica_SubidoPor ON EvidenciasFabrica(SubidoPor, FechaCreacion);
    
    PRINT '✓ Tabla EvidenciasFabrica creada';
END
GO


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: TABLAS DE AUDITORÍA (TRAZABILIDAD INMUTABLE)
-- ==============================================================================
-- Estas tablas registran todos los cambios y son de solo INSERT.
-- Fundamental para auditoría, debugging y cumplimiento regulatorio.

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.1 HistorialEstados: Máquina de estados inmutable
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'HistorialEstados') AND type in (N'U'))
BEGIN
    CREATE TABLE HistorialEstados (
        IdHistorial         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        IdEstadoAnterior    INT                 NULL,
        IdEstadoNuevo       INT                 NOT NULL,
        IdPasoRelacionado   INT                 NULL,
        
        -- Quién y por qué
        IdUsuarioAccion     INT                 NULL,
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        MotivoTransicion    NVARCHAR(500)       NULL,
        
        FechaTransicion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_HistorialEstados PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_Hist_Request FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_Hist_EstAnterior FOREIGN KEY (IdEstadoAnterior) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT FK_Hist_EstNuevo FOREIGN KEY (IdEstadoNuevo) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT FK_Hist_Paso FOREIGN KEY (IdPasoRelacionado) REFERENCES PasosEstudio(IdPaso),
        CONSTRAINT CK_HistorialEstados_TipoUsr CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CALL_CENTER'))
    );
    
    CREATE INDEX IX_HistorialEstados_Estudio ON HistorialEstados(IdEstudio, FechaTransicion);
    CREATE INDEX IX_HistorialEstados_EstadoFecha ON HistorialEstados(IdEstadoNuevo, FechaTransicion);
    
    PRINT '✓ Tabla HistorialEstados creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.2 AuditoriaCambiosDatos: Registro de cambios en datos mutables
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AuditoriaCambiosDatos') AND type in (N'U'))
BEGIN
    CREATE TABLE AuditoriaCambiosDatos (
        IdAuditoria         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        NombreTabla         VARCHAR(50)         NOT NULL,
        NombreCampo         VARCHAR(50)         NOT NULL,
        ValorAnterior       NVARCHAR(500)       NULL,
        ValorNuevo          NVARCHAR(500)       NULL,
        
        IdUsuarioAccion     INT                 NULL,
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        FechaCambio         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_AuditoriaCambiosDatos PRIMARY KEY (IdAuditoria),
        CONSTRAINT FK_Audit_Request FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio)
    );
    
    CREATE INDEX IX_AuditoriaCambiosDatos_Cliente ON AuditoriaCambiosDatos(NitTercero, FechaCambio);
    CREATE INDEX IX_AuditoriaCambiosDatos_Estudio ON AuditoriaCambiosDatos(IdEstudio) WHERE IdEstudio IS NOT NULL;
    
    PRINT '✓ Tabla AuditoriaCambiosDatos creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.3 RegistroServiciosExternos: Logging de invocaciones a servicios
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RegistroServiciosExternos') AND type in (N'U'))
BEGIN
    CREATE TABLE RegistroServiciosExternos (
        IdRegistro              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio               BIGINT              NOT NULL,
        IdPaso                  INT                 NULL,
        NombreServicio          VARCHAR(50)         NOT NULL,
        URLEndpoint             NVARCHAR(500)       NULL,
        MetodoHTTP              VARCHAR(10)         NULL,
        
        -- Payloads
        PayloadRequest          NVARCHAR(MAX)       NULL,
        PayloadResponse         NVARCHAR(MAX)       NULL,
        CodigoHTTPRespuesta     INT                 NULL,
        
        -- Resultado interpretado
        ResultadoInterpretado   VARCHAR(20)         NOT NULL,
        MensajeError            NVARCHAR(500)       NULL,
        
        -- Métricas de rendimiento
        DuracionMs              INT                 NULL,
        FechaInvocacion         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaRespuesta          DATETIME2(3)        NULL,
        
        CONSTRAINT PK_RegistroServiciosExternos PRIMARY KEY (IdRegistro),
        CONSTRAINT FK_RegServ_Request FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_RegServ_Paso FOREIGN KEY (IdPaso) REFERENCES PasosEstudio(IdPaso),
        CONSTRAINT CK_RegServExt_Resultado CHECK (ResultadoInterpretado IN ('EXITOSO','FALLIDO','TIMEOUT','ERROR'))
    );
    
    CREATE INDEX IX_RegServExt_Estudio ON RegistroServiciosExternos(IdEstudio, FechaInvocacion);
    CREATE INDEX IX_RegServExt_Servicio ON RegistroServiciosExternos(NombreServicio, ResultadoInterpretado, FechaInvocacion);
    CREATE INDEX IX_RegServExt_Duracion ON RegistroServiciosExternos(NombreServicio, DuracionMs) WHERE DuracionMs IS NOT NULL;
    
    PRINT '✓ Tabla RegistroServiciosExternos creada';
END
GO


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: PARCHES V2.2 — GAPS DEL ESCENARIO DE ESTRÉS (SENIOR ARCHITECT AUDIT)
-- ══════════════════════════════════════════════════════════════════════════════
-- Identificados mediante análisis senior de arquitectura de datos (2026-04-10).
-- Cubren EXACTAMENTE los 5 pasos del caso de estrés: autoservicio, validación
-- UBICA, fallo OTP, cambio de email, alerta de fraude y escalamiento a Fábrica.
--
-- GAPS CORREGIDOS EN ESTE BLOQUE:
--   SA-01: CatalogoMotivosEscalamiento  — catálogo tipificado de razones de escalamiento manual
--   SA-02: EscalamientosFabrica         — tabla transaccional de escalamiento con motivo, contexto y FK
--   SA-03: LogValidacionesOTP           — log granular de cada intento/reenvío OTP (independiente de RetosSeguridad)
--   SA-04: HistorialDatosSensibles      — trazabilidad de mutaciones de campos de contacto (email, celular)
--   SA-05: AlertasFraude                — registro de alertas de fraude detectadas por reglas de negocio
--   SA-06: CatalogoReglasFraude         — catálogo tipificado de reglas de detección de fraude
--   SA-07: ALTER EstudiosCredito        — IdEscalamiento + ClaveIdempotencia + VersionFila + EliminadoLogico + IdCorrelacion
--   SA-08: ALTER HistorialEstados       — IdCorrelacion para trazabilidad distribuida
--   SA-09: ALTER RetosSeguridad         — DireccionEnvio para registrar email/cel exacto al que se envió el OTP
--   SA-10: ALTER ValidacionesContactabilidad — IdAlertaFraude FK para vincular alerta de fraude al resultado UBICA
--   SA-11: Seeds para nuevos catálogos  (ver Sección 6)
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.1  CatalogoReglasFraude — tipificación de las reglas de detección de fraude
--      SA-06: Tabla de dominio para AlertasFraude.IdRegla
--
--      Justificación: sin este catálogo, las alertas tendrían strings libres en
--      'TipoAlerta', lo que impide agrupar, reportar o configurar umbrales sin
--      tocar código. Con este catálogo se pueden activar/desactivar reglas sin
--      deploy y el asesor ve la descripción enriquecida de por qué llegó el caso.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CatalogoReglasFraude') AND type = N'U')
BEGIN
    CREATE TABLE CatalogoReglasFraude (
        IdReglaFraude       INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(50)         NOT NULL,   -- Clave única usable desde código (ej. EMAIL_CHANGE_POST_OTP_FAIL)
        Nombre              NVARCHAR(150)       NOT NULL,   -- Nombre legible para el asesor
        Descripcion         NVARCHAR(500)       NULL,       -- Qué detecta esta regla y por qué es fraude
        NivelRiesgo         VARCHAR(10)         NOT NULL DEFAULT 'MEDIO',  -- BAJO, MEDIO, ALTO, CRITICO
        AccionAutomatica    VARCHAR(30)         NOT NULL DEFAULT 'ESCALAR',-- ESCALAR, BLOQUEAR, NOTIFICAR, SOLO_REGISTRO
        Activa              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoReglasFraude PRIMARY KEY (IdReglaFraude),
        CONSTRAINT UQ_CatalogoReglasFraude_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoReglasFraude_Nivel CHECK (NivelRiesgo IN ('BAJO','MEDIO','ALTO','CRITICO')),
        CONSTRAINT CK_CatalogoReglasFraude_Accion CHECK (AccionAutomatica IN ('ESCALAR','BLOQUEAR','NOTIFICAR','SOLO_REGISTRO'))
    );
    PRINT '✓ Tabla CatalogoReglasFraude creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.2  CatalogoMotivosEscalamiento — tipificación de razones de escalamiento manual
--      SA-01: Tabla de dominio para EscalamientosFabrica.IdMotivoEscalamiento
--
--      Justificación: sin este catálogo, el motivo sería texto libre en
--      HistorialEstados.MotivoTransicion. El asesor no puede filtrar ni el
--      sistema puede disparar reglas sobre texto libre. Este catálogo permite
--      dashboards de volumen por motivo y SLA diferenciados por tipo.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CatalogoMotivosEscalamiento') AND type = N'U')
BEGIN
    CREATE TABLE CatalogoMotivosEscalamiento (
        IdMotivo            INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(50)         NOT NULL,   -- Ej. OTP_FAIL_EMAIL_CHANGE, BIOMETRIA_REINTENTO_MAX
        Nombre              NVARCHAR(150)       NOT NULL,
        Descripcion         NVARCHAR(500)       NULL,
        Origen              VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',  -- SISTEMA, ASESOR, FRAUDE
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoMotivosEscalamiento PRIMARY KEY (IdMotivo),
        CONSTRAINT UQ_CatalogoMotivosEscalamiento_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoMotivos_Origen CHECK (Origen IN ('SISTEMA','ASESOR','FRAUDE'))
    );
    PRINT '✓ Tabla CatalogoMotivosEscalamiento creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.3  AlertasFraude — registro inmutable de alertas disparadas por reglas de negocio
--      SA-05: Tabla INSERT-ONLY. Una alerta no se cierra ni modifica; se crea
--             una nueva con AccionTomada = 'DESCARTADA' si el asesor la descarta.
--
--      Permite al asesor ver: CUÁNTAS alertas disparó este estudio, CUÁL regla
--      las generó, CUÁNDO, y QUÉ datos contextuales dispararon la alerta.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'AlertasFraude') AND type = N'U')
BEGIN
    CREATE TABLE AlertasFraude (
        IdAlerta            BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,   -- FK → EstudiosCredito
        IdReglaFraude       INT                 NOT NULL,   -- FK → CatalogoReglasFraude
        NitTercero          VARCHAR(20)         NOT NULL,   -- Redundancia controlada para consultas por cliente

        -- Contexto del momento de la alerta
        PasoEnQueOcurrio    VARCHAR(40)         NULL,       -- Código del paso (FK lógica a PasosEstudio.Codigo)
        ValorAnterior       NVARCHAR(300)       NULL,       -- Valor del campo ANTES del cambio anómalo
        ValorNuevo          NVARCHAR(300)       NULL,       -- Valor del campo DESPUÉS del cambio anómalo
        CampoAfectado       VARCHAR(50)         NULL,       -- Ej. 'EmailCliente', 'CelularCliente'
        ContextoJSON        NVARCHAR(MAX)       NULL,       -- Payload completo de contexto (IP, UserAgent, etc.)

        -- Resultado
        AccionTomada        VARCHAR(20)         NOT NULL DEFAULT 'PENDIENTE',  -- PENDIENTE, ESCALADO, BLOQUEADO, DESCARTADO
        IdUsuarioResolucion INT                 NULL,       -- FK lógica a BERP_FABRICASOperadores.idOperadorFabrica
        NotasResolucion     NVARCHAR(500)       NULL,
        FechaResolucion     DATETIME2(3)        NULL,

        FechaAlerta         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_AlertasFraude PRIMARY KEY (IdAlerta),
        CONSTRAINT FK_AlertasFraude_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_AlertasFraude_Regla FOREIGN KEY (IdReglaFraude) REFERENCES CatalogoReglasFraude(IdReglaFraude),
        CONSTRAINT CK_AlertasFraude_Accion CHECK (AccionTomada IN ('PENDIENTE','ESCALADO','BLOQUEADO','DESCARTADO'))
    );

    CREATE INDEX IX_AlertasFraude_Estudio ON AlertasFraude(IdEstudio, FechaAlerta);
    CREATE INDEX IX_AlertasFraude_Cliente ON AlertasFraude(NitTercero, FechaAlerta);
    CREATE INDEX IX_AlertasFraude_Pendientes ON AlertasFraude(AccionTomada, IdReglaFraude)
        WHERE AccionTomada = 'PENDIENTE';
    CREATE INDEX IX_AlertasFraude_Regla ON AlertasFraude(IdReglaFraude, FechaAlerta);

    PRINT '✓ Tabla AlertasFraude creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.4  EscalamientosFabrica — registro transaccional de escalamientos a revisión manual
--      SA-02: Una fila por cada vez que un estudio es enviado a revisión manual
--             por parte de la fábrica de crédito.
--
--      CRÍTICO para el escenario de estrés: el asesor DEBE poder ver:
--        - Motivo tipificado (FK → CatalogoMotivosEscalamiento)
--        - Alerta de fraude que lo desencadenó (FK → AlertasFraude, nullable)
--        - Historial de estados en el momento del escalamiento (texto snapshot)
--        - Quién escaló y cuándo
--        - Si fue resuelto, por quién y cuándo
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'EscalamientosFabrica') AND type = N'U')
BEGIN
    CREATE TABLE EscalamientosFabrica (
        IdEscalamiento          BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio               BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        IdMotivoEscalamiento    INT                     NOT NULL,   -- FK → CatalogoMotivosEscalamiento
        IdAlertaOrigen          BIGINT                  NULL,       -- FK → AlertasFraude (si el escalamiento fue por fraude)

        -- Contexto completo para el asesor
        DescripcionContexto     NVARCHAR(1000)          NULL,       -- Texto libre con el resumen de por qué llegó
        PasoEnQueEscalo         VARCHAR(40)             NULL,       -- Código del paso en que se escaló
        IdEstadoAlEscalar       INT                     NOT NULL,   -- FK → CatalogoEstados (estado en el momento de escalar)
        SnapshotDatosCliente    NVARCHAR(MAX)           NULL,       -- JSON snapshot de datos clave del cliente en ese momento

        -- Quién escaló
        EscaladoPorSistema      BIT                     NOT NULL DEFAULT 1,  -- 1=automático, 0=manual por asesor
        IdUsuarioEscala         INT                     NULL,       -- FK lógica a BERP_FABRICASOperadores (si fue manual)

        -- Resolución
        IdAsesorAsignado        INT                     NULL,       -- FK lógica a BERP_FABRICASOperadores
        FechaAsignacion         DATETIME2(3)            NULL,
        EstadoEscalamiento      VARCHAR(20)             NOT NULL DEFAULT 'ABIERTO',  -- ABIERTO, EN_GESTION, RESUELTO, CERRADO_SIN_RESOLUCION
        ResultadoGestion        VARCHAR(20)             NULL,       -- APROBADO, RECHAZADO, DEVUELTO_FLUJO
        NotasAsesor             NVARCHAR(1000)          NULL,
        FechaResolucion         DATETIME2(3)            NULL,

        FechaCreacion           DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion      DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_EscalamientosFabrica PRIMARY KEY (IdEscalamiento),
        CONSTRAINT FK_EscalamientosFabrica_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_EscalamientosFabrica_Motivo FOREIGN KEY (IdMotivoEscalamiento) REFERENCES CatalogoMotivosEscalamiento(IdMotivo),
        CONSTRAINT FK_EscalamientosFabrica_Alerta FOREIGN KEY (IdAlertaOrigen) REFERENCES AlertasFraude(IdAlerta),
        CONSTRAINT FK_EscalamientosFabrica_EstadoAlEscalar FOREIGN KEY (IdEstadoAlEscalar) REFERENCES CatalogoEstados(IdEstado),
        CONSTRAINT CK_EscalamientosFabrica_Estado CHECK (EstadoEscalamiento IN ('ABIERTO','EN_GESTION','RESUELTO','CERRADO_SIN_RESOLUCION')),
        CONSTRAINT CK_EscalamientosFabrica_Resultado CHECK (ResultadoGestion IS NULL OR ResultadoGestion IN ('APROBADO','RECHAZADO','DEVUELTO_FLUJO'))
    );

    CREATE INDEX IX_Escalamientos_Estudio ON EscalamientosFabrica(IdEstudio, FechaCreacion);
    CREATE INDEX IX_Escalamientos_AbiertosAsesor ON EscalamientosFabrica(IdAsesorAsignado, EstadoEscalamiento)
        WHERE EstadoEscalamiento IN ('ABIERTO','EN_GESTION');
    CREATE INDEX IX_Escalamientos_Motivo ON EscalamientosFabrica(IdMotivoEscalamiento, FechaCreacion);
    CREATE INDEX IX_Escalamientos_Alerta ON EscalamientosFabrica(IdAlertaOrigen)
        WHERE IdAlertaOrigen IS NOT NULL;

    PRINT '✓ Tabla EscalamientosFabrica creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.5  LogValidacionesOTP — log granular de cada intento individual de OTP
--      SA-03: RetosSeguridad registra el RETO (un token). Esta tabla registra
--             cada INTENTO individual de validación: correcto, fallido, expirado.
--
--      CRÍTICO: La columna RetosSeguridad.NumeroIntentos es un contador, no un log.
--      No permite reconstruir "intento 1 falló a las 10:01, intento 2 expiró a las 10:06"
--      ni vincular un intento fallido específico con el cambio de email subsiguiente.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'LogValidacionesOTP') AND type = N'U')
BEGIN
    CREATE TABLE LogValidacionesOTP (
        IdLogOTP            BIGINT IDENTITY(1,1) NOT NULL,
        IdReto              BIGINT              NOT NULL,   -- FK → RetosSeguridad
        IdEstudio           BIGINT              NOT NULL,   -- Redundancia para consultas directas por estudio
        NitTercero          VARCHAR(20)         NOT NULL,   -- Redundancia para consultas por cliente
        NumeroIntento       INT                 NOT NULL,   -- 1, 2, 3...
        DireccionEnvio      NVARCHAR(200)       NULL,       -- Email/cel al que se envió ESTE intento (puede diferir si hubo cambio)
        ResultadoIntento    VARCHAR(20)         NOT NULL,   -- EXITOSO, FALLIDO_HASH, EXPIRADO, CANCELADO
        CodigoEntradoHash   VARCHAR(256)        NULL,       -- Hash del código ingresado (nunca el código en claro)
        DireccionIP         VARCHAR(45)         NULL,       -- IP del cliente al momento del intento
        UserAgent           NVARCHAR(500)       NULL,
        FechaIntento        DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_LogValidacionesOTP PRIMARY KEY (IdLogOTP),
        CONSTRAINT FK_LogOTP_Reto FOREIGN KEY (IdReto) REFERENCES RetosSeguridad(IdReto),
        CONSTRAINT FK_LogOTP_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_LogOTP_Resultado CHECK (ResultadoIntento IN ('EXITOSO','FALLIDO_HASH','EXPIRADO','CANCELADO'))
    );

    CREATE INDEX IX_LogOTP_Reto ON LogValidacionesOTP(IdReto, NumeroIntento);
    CREATE INDEX IX_LogOTP_Estudio ON LogValidacionesOTP(IdEstudio, FechaIntento);
    CREATE INDEX IX_LogOTP_Cliente ON LogValidacionesOTP(NitTercero, FechaIntento);

    PRINT '✓ Tabla LogValidacionesOTP creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.6  HistorialDatosSensibles — trazabilidad de mutaciones de campos de contacto
--      SA-04: AuditoriaCambiosDatos existe pero es genérica. Esta tabla es
--             específica para campos de contacto (email, celular, dirección) y
--             es la ÚNICA fuente de verdad para el patrón de fraude:
--             "email original → email cambiado después de OTP fallido".
--
--      Diseño: INSERT-ONLY, con FK al reto de seguridad activo al momento del cambio
--              para poder correlacionar "cambio de email mientras había un reto OTP abierto".
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'HistorialDatosSensibles') AND type = N'U')
BEGIN
    CREATE TABLE HistorialDatosSensibles (
        IdHistorialDato     BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,   -- FK → EstudiosCredito
        NitTercero          VARCHAR(20)         NOT NULL,
        CampoCambiado       VARCHAR(50)         NOT NULL,   -- 'EmailCliente', 'CelularCliente', 'DireccionCapturada'
        ValorOriginal       NVARCHAR(300)       NULL,       -- Valor ANTES del cambio
        ValorNuevo          NVARCHAR(300)       NULL,       -- Valor DESPUÉS del cambio
        IdRetoActivoAlCambio BIGINT             NULL,       -- FK → RetosSeguridad (reto que estaba activo/pendiente al cambiar)
        EsPostFalloOTP      BIT                 NOT NULL DEFAULT 0,  -- 1 si había un reto OTP fallido reciente al momento del cambio
        TipoActor           VARCHAR(20)         NOT NULL DEFAULT 'CLIENTE',  -- CLIENTE, ASESOR, SISTEMA
        DireccionIP         VARCHAR(45)         NULL,
        UserAgent           NVARCHAR(500)       NULL,
        MotivoDeclarado     NVARCHAR(300)       NULL,       -- Razón declarada por el cliente/asesor para el cambio
        FechaCambio         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_HistorialDatosSensibles PRIMARY KEY (IdHistorialDato),
        CONSTRAINT FK_HistDatosSensibles_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_HistDatosSensibles_Reto FOREIGN KEY (IdRetoActivoAlCambio) REFERENCES RetosSeguridad(IdReto),
        CONSTRAINT CK_HistDatosSensibles_Actor CHECK (TipoActor IN ('CLIENTE','ASESOR','SISTEMA'))
    );

    CREATE INDEX IX_HistDatosSensibles_Estudio ON HistorialDatosSensibles(IdEstudio, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_Cliente ON HistorialDatosSensibles(NitTercero, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_PostOTP ON HistorialDatosSensibles(IdEstudio, EsPostFalloOTP)
        WHERE EsPostFalloOTP = 1;   -- Índice filtrado para detección rápida de patrón de fraude

    PRINT '✓ Tabla HistorialDatosSensibles creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.7  ALTER EstudiosCredito — columnas de control de concurrencia, idempotencia,
--      escalamiento, soft-delete y correlación distribuida
--      SA-07: Estas columnas son necesarias para la preparación API y para
--             vincular el estudio con su escalamiento activo de forma directa.
-- ─────────────────────────────────────────────────────────────────────────────

-- Clave de idempotencia para el API: evita procesar dos veces la misma solicitud
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'ClaveIdempotencia')
BEGIN
    ALTER TABLE EstudiosCredito ADD ClaveIdempotencia VARCHAR(64) NULL;  -- Hash/UUID del request original del cliente
    PRINT '✓ EstudiosCredito: columna ClaveIdempotencia añadida';
END
GO

-- Control de concurrencia optimista (row versioning) — previene race conditions
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'VersionFila')
BEGIN
    ALTER TABLE EstudiosCredito ADD VersionFila ROWVERSION NOT NULL;  -- Actualizada automáticamente por SQL Server en cada UPDATE
    PRINT '✓ EstudiosCredito: columna VersionFila (ROWVERSION) añadida';
END
GO

-- Soft delete: permite "cerrar" un estudio sin borrar datos históricos
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'EliminadoLogico')
BEGIN
    ALTER TABLE EstudiosCredito ADD EliminadoLogico BIT NOT NULL DEFAULT 0;
    PRINT '✓ EstudiosCredito: columna EliminadoLogico añadida';
END
GO

-- ID de correlación para trazabilidad distribuida (tracing entre microservicios)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'IdCorrelacion')
BEGIN
    ALTER TABLE EstudiosCredito ADD IdCorrelacion VARCHAR(64) NULL;   -- Correlation-ID del request HTTP original
    PRINT '✓ EstudiosCredito: columna IdCorrelacion añadida';
END
GO

-- FK directa al escalamiento activo (denormalización controlada para consulta rápida)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'IdEscalamientoActivo')
BEGIN
    ALTER TABLE EstudiosCredito ADD IdEscalamientoActivo BIGINT NULL;  -- FK lógica → EscalamientosFabrica (FK física genera circular ref)
    PRINT '✓ EstudiosCredito: columna IdEscalamientoActivo añadida';
END
GO

-- Índice para deduplicación de requests por clave de idempotencia
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'UQ_EstudiosCredito_Idempotencia')
BEGIN
    CREATE UNIQUE INDEX UQ_EstudiosCredito_Idempotencia ON EstudiosCredito(ClaveIdempotencia)
        WHERE ClaveIdempotencia IS NOT NULL;
    PRINT '✓ EstudiosCredito: índice UQ_EstudiosCredito_Idempotencia creado';
END
GO

-- Índice para correlación distribuida
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'IX_EstudiosCredito_Correlacion')
BEGIN
    CREATE INDEX IX_EstudiosCredito_Correlacion ON EstudiosCredito(IdCorrelacion)
        WHERE IdCorrelacion IS NOT NULL;
    PRINT '✓ EstudiosCredito: índice IX_EstudiosCredito_Correlacion creado';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.8  ALTER HistorialEstados — añadir IdCorrelacion para trazabilidad
--      SA-08: Permite correlacionar cada transición de estado con el request
--             HTTP que la originó, esencial para debugging en producción.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'HistorialEstados') AND name = 'IdCorrelacion')
BEGIN
    ALTER TABLE HistorialEstados ADD IdCorrelacion VARCHAR(64) NULL;   -- Correlation-ID propagado desde el request
    PRINT '✓ HistorialEstados: columna IdCorrelacion añadida';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.9  ALTER RetosSeguridad — añadir DireccionEnvio para registrar el email/cel
--      exacto al que se envió ESTE token (puede diferir si hubo cambio de email)
--      SA-09: Permite detectar la anomalía "OTP enviado a email A pero cliente
--             luego cambió a email B antes de validar".
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RetosSeguridad') AND name = 'DireccionEnvio')
BEGIN
    ALTER TABLE RetosSeguridad ADD DireccionEnvio NVARCHAR(200) NULL;  -- Email o celular exacto al que se envió el token
    PRINT '✓ RetosSeguridad: columna DireccionEnvio añadida';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.10 ALTER ValidacionesContactabilidad — añadir IdAlertaFraude
--      SA-10: Vincula el resultado de la validación UBICA con la alerta de
--             fraude que ésta generó (o que existía antes de la validación).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ValidacionesContactabilidad') AND name = 'IdAlertaFraude')
BEGIN
    ALTER TABLE ValidacionesContactabilidad ADD IdAlertaFraude BIGINT NULL;  -- FK → AlertasFraude (si esta validación generó o está asociada a una alerta)
    PRINT '✓ ValidacionesContactabilidad: columna IdAlertaFraude añadida';
END
GO

-- Añadir FK para IdAlertaFraude (la tabla AlertasFraude ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'ValidacionesContactabilidad')
      AND name = 'FK_ValidContact_AlertaFraude'
)
BEGIN
    ALTER TABLE ValidacionesContactabilidad
        ADD CONSTRAINT FK_ValidContact_AlertaFraude
        FOREIGN KEY (IdAlertaFraude) REFERENCES AlertasFraude(IdAlerta);
    PRINT '✓ ValidacionesContactabilidad: FK FK_ValidContact_AlertaFraude añadida';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.11 NUEVO ESTADO: REVISION_FABRICA — estado faltante en CatalogoEstados
--      CRÍTICO: El escenario de estrés requiere un estado para "en revisión manual
--      por la fábrica de crédito". El estado PENDIENTE_CALL es para call center,
--      no para revisión por asesor de fábrica.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'REVISION_FABRICA')
BEGIN
    INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('REVISION_FABRICA', 'En Revisión Manual — Fábrica de Crédito', 'PROCESO', 0, 0,
            'Estudio derivado a revisión manual por asesor de fábrica de crédito, usualmente por alerta de fraude o anomalía en el flujo');
    PRINT '✓ Estado REVISION_FABRICA insertado en CatalogoEstados';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.12 NUEVO ESTADO: BLOQUEADO_FRAUDE — estado terminal por sospecha de fraude
--      Permite cerrar un estudio por sospecha de fraude confirmada sin rechazarlo
--      por razones de riesgo crediticio (son categorizaciones distintas).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'BLOQUEADO_FRAUDE')
BEGIN
    INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('BLOQUEADO_FRAUDE', 'Bloqueado por Sospecha de Fraude', 'TERMINAL', 1, 0,
            'Solicitud bloqueada por detección de patrón de fraude. Requiere investigación por área de seguridad.');
    PRINT '✓ Estado BLOQUEADO_FRAUDE insertado en CatalogoEstados';
END
GO

-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 6: DATOS SEMILLA (SEEDS)
-- ==============================================================================
-- Datos iniciales para los catálogos de configuración.
-- Solo se insertan si las tablas están vacías.

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.1 Insertar FasesEstudio (7 fases)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM FasesEstudio)
BEGIN
    INSERT INTO FasesEstudio (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
    ('IDENTIFICACION',          'Identificación del Cliente',       1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
    ('DATOS_CLIENTE',           'Datos del Cliente',                2, 'Captura o actualización de datos personales y de contacto'),
    ('CONSENTIMIENTO_LEGAL',    'Consentimiento Legal',             3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
    ('VALIDACIONES_RIESGO',     'Validaciones de Riesgo',           4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
    ('LIMITE_CREDITO',          'Límite de Crédito',                5, 'Cálculo y presentación del cupo preaprobado'),
    ('VERIFICACION_IDENTIDAD',  'Verificación de Identidad',        6, 'Biometría facial, OCR de documento, prueba de vida'),
    ('ACTIVACION',              'Activación del Cupo',              7, 'Validación UBICA, activación automática o gestión manual Call Center');
    
    PRINT '✓ Seeds insertados en FasesEstudio';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.2 Insertar CatalogoEstados (11 estados base + 2 nuevos en sección 5)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados)
BEGIN
    INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('BORRADOR',            'Borrador',                         'INICIAL',  0, 0, 'Solicitud iniciada, documento ingresado pero aún sin procesar'),
    ('EN_PROGRESO',         'En Progreso',                      'PROCESO',  0, 1, 'Estudio en ejecución activa de pasos automáticos'),
    ('PAUSADO',             'Pausado',                          'PROCESO',  0, 0, 'Cliente se retiró de la tienda; estudio en espera de reanudación'),
    ('PENDIENTE_OTP',       'Pendiente Validación OTP',         'PROCESO',  0, 1, 'Esperando que el cliente valide el token de seguridad'),
    ('PENDIENTE_BIOMETRIA', 'Pendiente Biometría',              'PROCESO',  0, 1, 'Esperando captura y validación biométrica'),
    ('PENDIENTE_CALL',      'Pendiente Gestión Call Center',    'PROCESO',  0, 0, 'Derivado a call center por fallo en automatización'),
    ('CUPO_PREAPROBADO',    'Cupo Preaprobado',                 'PROCESO',  0, 1, 'Cupo calculado exitosamente, pendiente verificación de identidad'),
    ('APROBADO',            'Aprobado y Activado',              'TERMINAL', 1, 0, 'Cupo activado exitosamente, disponible para uso'),
    ('RECHAZADO',           'Rechazado',                        'TERMINAL', 1, 0, 'Solicitud rechazada por alguna validación'),
    ('EXPIRADO',            'Expirado',                         'TERMINAL', 1, 0, 'Solicitud expirada por inactividad'),
    ('CANCELADO_CLIENTE',   'Cancelado por el Cliente',         'TERMINAL', 1, 0, 'El cliente solicitó cancelar el proceso voluntariamente');
    
    PRINT '✓ Seeds insertados en CatalogoEstados';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.3 Insertar PasosEstudio (13 pasos)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM PasosEstudio)
BEGIN
    INSERT INTO PasosEstudio (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, ServicioExterno, EsAutomatico, RequiereIntervencion, TiempoTimeoutSeg, Descripcion) VALUES
    (1, 'INGRESO_DOCUMENTO',        'Ingreso de Documento',             1,  1,  'ASESOR',       NULL,                   0, 0, NULL,   'El asesor digita el número de documento del cliente'),
    (1, 'VALIDAR_EXISTENCIA',       'Validar Existencia del Cliente',   2,  2,  'SISTEMA',      'ERP_QUAC',             1, 0, 30,     'Verifica si el cliente existe en el sistema ERP'),
    (1, 'VALIDAR_CUPO_BLOQUEO',     'Validar Cupo Activo / Bloqueo',   3,  3,  'SISTEMA',      'CORE_CREDITO',         1, 0, 30,     'Verifica cupo activo, bloqueos, mora'),
    (2, 'CAPTURA_DATOS',            'Captura de Datos Personales',      1,  4,  'ASESOR',       NULL,                   0, 0, NULL,   'Captura de datos personales'),
    (3, 'CONSENTIMIENTO_DATOS',     'Autorización Tratamiento Datos',   1,  5,  'CLIENTE',      NULL,                   0, 0, NULL,   'Aceptación de términos'),
    (3, 'TOKENIZACION',             'Envío y Validación de Token OTP',  2,  6,  'SISTEMA',      'OTP_PROVIDER',         1, 0, 120,    'Envío y validación de OTP'),
    (4, 'VALIDAR_LISTAS',           'Validar Listas Restrictivas',      1,  7,  'SISTEMA',      'LISTAS_RESTRICTIVAS',  1, 0, 30,     'Consulta en listas restrictivas'),
    (4, 'CONSULTAR_BURO',           'Consultar Buró de Crédito',        2,  8,  'SISTEMA',      'BURO_CREDITO',         1, 0, 60,     'Consulta historial crediticio'),
    (4, 'EVALUAR_PRESELECTA',       'Evaluación Preselecta',            3,  9,  'SISTEMA',      'PRESELECTA',           1, 0, 60,     'Motor de decisión Preselecta'),
    (4, 'VALIDAR_FOSYGA',           'Validar FOSYGA / ADRES',           4, 10,  'SISTEMA',      'FOSYGA',               1, 0, 30,     'Verificación seguridad social'),
    (5, 'CALCULAR_CUPO',            'Cálculo del Cupo Preaprobado',    1, 11,  'SISTEMA',      'MOTOR_CUPO',           1, 0, 30,     'Cálculo del límite de crédito'),
    (6, 'VERIFICACION_BIOMETRICA',  'Verificación Biométrica',          1, 12,  'SISTEMA',      'BIOMETRIA',            1, 1, 120,    'Captura y verificación biométrica'),
    (7, 'ACTIVACION_CUPO',          'Activación del Cupo',             1, 13,  'SISTEMA',      'UBICA',                1, 1, 60,     'Validación UBICA y activación');
    
    PRINT '✓ Seeds insertados en PasosEstudio';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.4 Insertar TransicionesEstado (transiciones válidas)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM TransicionesEstado)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion) VALUES
    (1,  2,  0, 'Iniciar procesamiento del estudio'),
    (1, 11, 0, 'Cancelación voluntaria antes de iniciar'),
    (2,  3,  0, 'Cliente se retira, pausar estudio'),
    (2,  4,  0, 'Paso de tokenización: esperar OTP'),
    (2,  5,  0, 'Paso biométrico: esperar captura'),
    (2,  6,  1, 'Fallo automático: derivar a call center'),
    (2,  7,  0, 'Cupo calculado exitosamente'),
    (2,  8,  0, 'Todas las validaciones aprobadas, cupo activado'),
    (2,  9,  1, 'Rechazado por validación de riesgo'),
    (2, 11, 0, 'Cancelación voluntaria durante el proceso'),
    (3,  2,  0, 'Cliente regresa, reanudar estudio'),
    (3, 10, 0, 'Estudio expiró por inactividad'),
    (3, 11, 0, 'Cancelación voluntaria mientras pausado'),
    (4,  2,  0, 'OTP validado exitosamente'),
    (4,  3,  0, 'Cliente se retira, pausar'),
    (4,  9,  1, 'OTP fallido, intentos agotados'),
    (5,  2,  0, 'Biometría validada exitosamente'),
    (5,  3,  0, 'Cliente se retira, pausar'),
    (5,  6,  1, 'Biometría fallida, derivar a call center'),
    (5,  9,  1, 'Biometría rechazada definitivamente'),
    (6,  2,  0, 'Call center resuelve exitosamente'),
    (6,  8,  0, 'Call center aprueba y activa directamente'),
    (6,  9,  1, 'Call center rechaza la solicitud'),
    (7,  2,  0, 'Continuar a verificación de identidad'),
    (7,  3,  0, 'Cliente se retira, pausar'),
    (7, 11, 0, 'Cancelación voluntaria con cupo preaprobado');
    
    PRINT '✓ Seeds insertados en TransicionesEstado';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.5 Insertar ConfiguracionReglasNegocio (reglas iniciales)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio)
BEGIN
    INSERT INTO ConfiguracionReglasNegocio (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_ENFRIAMIENTO',           'Días de Enfriamiento por Rechazo',         '90',       'INT',      'ENFRIAMIENTO', 'Días que un cliente rechazado debe esperar'),
    ('DIAS_EXPIRACION_ESTUDIO',     'Días de Expiración del Estudio',           '90',       'INT',      'GENERAL',      'Días de inactividad antes de expirar'),
    ('INTENTOS_OTP_MAX',            'Intentos Máximos de OTP',                  '3',        'INT',      'OTP',          'Número máximo de intentos OTP'),
    ('VIGENCIA_OTP_SEG',            'Vigencia del Token OTP (segundos)',        '300',      'INT',      'OTP',          'Tiempo de vida del token OTP'),
    ('BLOQUEO_OTP_HORAS',           'Horas de Bloqueo por OTP Fallidos',       '24',       'INT',      'OTP',          'Horas de bloqueo tras intentos fallidos'),
    ('INTENTOS_BIOMETRIA_MAX',      'Intentos Máximos de Biometría',           '3',        'INT',      'BIOMETRIA',    'Número máximo de intentos biométricos'),
    ('UMBRAL_MATCH_FACIAL',         'Umbral de Coincidencia Facial (%)',        '85.00',    'DECIMAL',  'BIOMETRIA',    'Porcentaje mínimo de coincidencia facial'),
    ('DIAS_CANCELACION_REACTIV',    'Días Desde Cancelación para Reactivación', '365',     'INT',      'GENERAL',      'Días desde cancelación para reactivación');
    
    PRINT '✓ Seeds insertados en ConfiguracionReglasNegocio';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.6 Insertar CatalogoCanalesOrigen (canales iniciales)
--     G-DB-01: Seeds para los 3 canales base del sistema
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoCanalesOrigen)
BEGIN
    INSERT INTO CatalogoCanalesOrigen (Codigo, Nombre, Descripcion, Activo) VALUES
    ('WEB',      'Canal Web',      'Originación a través del portal web o app del cliente',              1),
    ('TIENDA',   'Canal Tienda',   'Originación presencial en punto de venta asistida por asesor',       1),
    ('EXTERNO',  'Canal Externo',  'Originación por fuerza de ventas externas o aliados comerciales',    1);
    
    PRINT '✓ Seeds insertados en CatalogoCanalesOrigen';
END
GO


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.7 Insertar CatalogoReglasFraude (reglas de detección de fraude)
--     SA-06: Seeds para las reglas de fraude del escenario de estrés
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoReglasFraude)
BEGIN
    INSERT INTO CatalogoReglasFraude (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('EMAIL_CHANGE_POST_OTP_FAIL',
        'Cambio de email después de fallo OTP',
        'El cliente intenta cambiar su email después de que falló la validación OTP. Patrón típico de suplantación: el suplantador no tiene acceso al email real del titular y lo cambia para recibir el OTP.',
        'ALTO', 'ESCALAR'),
    ('CEL_CHANGE_POST_OTP_FAIL',
        'Cambio de celular después de fallo OTP',
        'El cliente intenta cambiar su número de celular después de que falló la validación OTP enviada a ese número.',
        'ALTO', 'ESCALAR'),
    ('CONTACTO_CHANGE_DURANTE_RETO_ACTIVO',
        'Cambio de dato de contacto con reto OTP activo',
        'Intento de modificar email o celular mientras hay un token OTP vigente y sin validar. Indica posible suplantación en tiempo real.',
        'CRITICO', 'BLOQUEAR'),
    ('MULTIPLES_FALLOS_OTP_MISMA_SESION',
        'Múltiples fallos OTP en la misma sesión',
        'Se agotaron los intentos máximos de OTP en una misma sesión de originación. El titular real normalmente puede acceder a su email/cel.',
        'MEDIO', 'ESCALAR'),
    ('UBICA_EMAIL_DISCREPANCIA',
        'Discrepancia entre email declarado y email UBICA',
        'El email ingresado por el cliente no coincide con el email registrado en UBICA (buró de identidad). Puede indicar datos falsos.',
        'MEDIO', 'ESCALAR'),
    ('REINTENTO_RAPIDO_OTRO_EMAIL',
        'Reintento de OTP con email diferente en menos de 5 minutos',
        'El cliente solicita un nuevo OTP a una dirección diferente en un intervalo muy corto. Patrón de barrido de cuentas.',
        'ALTO', 'ESCALAR'),
    ('IP_MULTIPLES_ESTUDIOS',
        'Misma IP usada en múltiples estudios simultáneos',
        'La misma dirección IP está siendo usada para originar crédito para múltiples clientes distintos en un período corto.',
        'CRITICO', 'BLOQUEAR'),
    ('DOCUMENTO_OCR_DISCREPANCIA',
        'Datos OCR no coinciden con datos declarados',
        'Los datos extraídos por OCR del documento de identidad no coinciden con los datos declarados por el cliente.',
        'MEDIO', 'ESCALAR');

    PRINT '✓ Seeds insertados en CatalogoReglasFraude';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.8 Insertar CatalogoMotivosEscalamiento (motivos de escalamiento a fábrica)
--     SA-01: Seeds para los motivos del escenario de estrés y casos comunes
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoMotivosEscalamiento)
BEGIN
    INSERT INTO CatalogoMotivosEscalamiento (Codigo, Nombre, Descripcion, Origen) VALUES
    ('OTP_FAIL_EMAIL_CHANGE',
        'Cambio de email tras fallo OTP — posible suplantación',
        'El cliente falló la validación OTP y a continuación intentó cambiar su email. Activó regla de fraude EMAIL_CHANGE_POST_OTP_FAIL.',
        'FRAUDE'),
    ('OTP_INTENTOS_AGOTADOS',
        'Intentos OTP agotados sin validación exitosa',
        'Se consumieron todos los intentos permitidos de OTP sin que el cliente lo validara correctamente.',
        'SISTEMA'),
    ('BIOMETRIA_MAX_REINTENTOS',
        'Biometría fallida — máximo de reintentos alcanzado',
        'La verificación biométrica falló el número máximo de veces configurado.',
        'SISTEMA'),
    ('UBICA_GESTION_MANUAL_FABRICA',
        'UBICA indica gestión manual por fábrica',
        'El resultado de la validación UBICA devolvió el estado GESTION_MANUAL_FABRICA, indicando que el caso requiere revisión humana.',
        'SISTEMA'),
    ('ALERTA_FRAUDE_CRITICA',
        'Alerta de fraude nivel CRÍTICO disparada',
        'Se disparó una regla de fraude de nivel CRÍTICO que requiere revisión inmediata antes de continuar el proceso.',
        'FRAUDE'),
    ('DISCREPANCIA_DATOS_UBICA',
        'Discrepancia entre datos declarados y UBICA',
        'Los datos de contacto declarados por el cliente no coinciden con los reportados por el servicio UBICA.',
        'SISTEMA'),
    ('ESCALAMIENTO_MANUAL_ASESOR',
        'Escalamiento manual por asesor',
        'El asesor decidió escalar el caso manualmente a revisión de fábrica.',
        'ASESOR'),
    ('DATO_CONTACTO_MODIFICADO_EN_FLUJO',
        'Dato de contacto modificado durante el flujo',
        'El cliente o asesor modificó un dato de contacto clave (email, celular) durante el proceso de originación.',
        'FRAUDE');

    PRINT '✓ Seeds insertados en CatalogoMotivosEscalamiento';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.9 Insertar TransicionesEstado para los nuevos estados (REVISION_FABRICA, BLOQUEADO_FRAUDE)
--     Usa variables locales para obtener los IdEstado dinámicamente
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE
    @IdRevFabrica   INT,
    @IdBloqFraude   INT,
    @IdEnProgreso   INT,
    @IdRechazado    INT,
    @IdPendCall     INT;

SELECT @IdRevFabrica = IdEstado FROM CatalogoEstados WHERE Codigo = 'REVISION_FABRICA';
SELECT @IdBloqFraude = IdEstado FROM CatalogoEstados WHERE Codigo = 'BLOQUEADO_FRAUDE';
SELECT @IdEnProgreso = IdEstado FROM CatalogoEstados WHERE Codigo = 'EN_PROGRESO';
SELECT @IdRechazado  = IdEstado FROM CatalogoEstados WHERE Codigo = 'RECHAZADO';
SELECT @IdPendCall   = IdEstado FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_CALL';

-- EN_PROGRESO → REVISION_FABRICA (alerta de fraude, anomalía de flujo)
IF @IdEnProgreso IS NOT NULL AND @IdRevFabrica IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdEnProgreso AND IdEstadoDestino = @IdRevFabrica)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso, @IdRevFabrica, 1, 'Anomalía detectada: derivar a revisión manual por fábrica de crédito');
END

-- PENDIENTE_CALL → REVISION_FABRICA (call center escala a fábrica)
IF @IdPendCall IS NOT NULL AND @IdRevFabrica IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendCall AND IdEstadoDestino = @IdRevFabrica)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendCall, @IdRevFabrica, 1, 'Call center no puede resolver: escala a revisión fábrica');
END

-- REVISION_FABRICA → EN_PROGRESO (asesor resuelve, devuelve al flujo automático)
IF @IdRevFabrica IS NOT NULL AND @IdEnProgreso IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdEnProgreso)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdEnProgreso, 1, 'Asesor de fábrica resuelve: devolver al flujo automático');
END

-- REVISION_FABRICA → RECHAZADO (asesor rechaza)
IF @IdRevFabrica IS NOT NULL AND @IdRechazado IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdRechazado)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdRechazado, 1, 'Asesor de fábrica determina rechazo definitivo');
END

-- REVISION_FABRICA → BLOQUEADO_FRAUDE (asesor confirma fraude)
IF @IdRevFabrica IS NOT NULL AND @IdBloqFraude IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdBloqFraude)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdBloqFraude, 1, 'Asesor de fábrica confirma sospecha de fraude');
END

-- EN_PROGRESO → BLOQUEADO_FRAUDE (sistema bloquea automáticamente por regla crítica)
IF @IdEnProgreso IS NOT NULL AND @IdBloqFraude IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdEnProgreso AND IdEstadoDestino = @IdBloqFraude)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso, @IdBloqFraude, 1, 'Regla de fraude crítica: bloqueo automático inmediato');
END

PRINT '✓ Transiciones para REVISION_FABRICA y BLOQUEADO_FRAUDE insertadas';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 6.10 Insertar ConfiguracionReglasNegocio — parámetros adicionales para fraude y escalamiento
--      SA-11: Seeds de configuración para umbral de detección de fraude
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio WHERE Codigo = 'VENTANA_FRAUDE_OTP_MIN')
BEGIN
    INSERT INTO ConfiguracionReglasNegocio (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_FRAUDE_OTP_MIN',
        'Ventana de tiempo para detección de fraude post-OTP (minutos)',
        '10', 'INT', 'RIESGO',
        'Número de minutos después de un fallo OTP durante los cuales un cambio de email/cel activa la regla de fraude EMAIL_CHANGE_POST_OTP_FAIL'),
    ('MAX_ESTUDIOS_POR_IP_HORA',
        'Máximo de estudios simultáneos desde una misma IP por hora',
        '3', 'INT', 'RIESGO',
        'Si una IP genera más de este número de estudios en 1 hora, activa la regla de fraude IP_MULTIPLES_ESTUDIOS'),
    ('SLA_REVISION_FABRICA_HORAS',
        'SLA máximo para resolver un escalamiento a fábrica (horas)',
        '24', 'INT', 'RIESGO',
        'Tiempo máximo en horas para que un asesor resuelva un caso escalado a la fábrica de crédito'),
    ('REENVIOS_OTP_MAX',
        'Máximo de reenvíos de OTP permitidos por reto',
        '2', 'INT', 'OTP',
        'Número máximo de veces que el cliente puede solicitar reenvío del OTP sin que se cancele el reto');

    PRINT '✓ Seeds adicionales insertados en ConfiguracionReglasNegocio';
END
GO

-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 7: PARCHES V2.3 — GESTIÓN DE FOTOGRAFÍAS Y MÓDULO DE REVISIÓN
-- ══════════════════════════════════════════════════════════════════════════════
-- Identificados mediante análisis de arquitectura de datos (2026-04-13).
--
-- PROBLEMA CENTRAL:
--   El modelo v2.2 tiene RegistrosBiometria para guardar el RESULTADO del
--   proceso AWS Rekognition (match %, OCR pass/fail) y EvidenciasFabrica para
--   almacenar archivos genéricos. Sin embargo, ninguna de las dos tablas puede:
--     1. Rastrear el ciclo de vida individual de cada una de las 3 fotos
--        obligatorias (FOTO_FRONTAL_DOC, FOTO_TRASERA_DOC, SELFIE)
--     2. Registrar la decisión de revisión (aprobar/rechazar) POR FOTO
--     3. Registrar QUIÉN revisó cada foto y CUÁNDO
--     4. Generar y rastrear links de re-carga enviados al cliente
--     5. Desbloquear automáticamente el proceso cuando el cliente re-sube fotos
--     6. Impedir la aprobación del crédito si faltan fotos o hay fotos rechazadas
--     7. Auditar el historial completo de re-subidas y re-revisiones por foto
--
-- DECISIÓN DE DISEÑO — OPCIÓN B (tabla dedicada FotografiasEstudio):
--   Se elige NO extender EvidenciasFabrica porque:
--   - EvidenciasFabrica es para evidencias GENÉRICAS de la fábrica (comprobantes,
--     notas del asesor, soportes). Las fotos de identidad tienen un ciclo de vida
--     completamente diferente y son entidades de PRIMERA CLASE en el proceso.
--   - Las 3 fotos son un bloqueo hard para la aprobación del crédito; ninguna
--     evidencia genérica tiene ese peso.
--   - El módulo de revisión necesita UI dedicada para ver las 3 fotos lado a lado,
--     lo que requiere consultas eficientes por TipoFoto + IdEstudio.
--   - RegistrosBiometria seguirá siendo el hogar del RESULTADO de Rekognition
--     (match %, prueba de vida, OCR). FotografiasEstudio es el hogar del ARCHIVO
--     y su ciclo de revisión. Los dos se vinculan mediante FK.
--
-- GAPS CORREGIDOS EN ESTE BLOQUE:
--   PH-01: CatalogoTiposFotografia   — catálogo de los 3 tipos obligatorios
--   PH-02: FotografiasEstudio        — entidad de ciclo de vida de cada foto
--   PH-03: RevisionesFotografia      — decisiones de revisión (INSERT-ONLY)
--   PH-04: SolicitudesRecarga        — links enviados al cliente para re-carga
--   PH-05: HistorialFotografias      — auditoría inmutable de todos los cambios
--   PH-06: ALTER EstudiosCredito     — FotografiasAprobadas + EstadoRevisionFotos
--   PH-07: ALTER RegistrosBiometria  — FKs a las 3 fotografías del proceso
--   PH-08: Nuevos estados de CatalogoEstados: PENDIENTE_FOTOS + FOTOS_EN_REVISION
--   PH-09: Seeds ConfiguracionReglasNegocio (parámetros foto)
--   PH-10: Seeds de todos los catálogos de fotografía
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.1  CatalogoTiposFotografia — los 3 tipos obligatorios y sus reglas
--      PH-01: Catálogo maestro. Define cuáles fotos son obligatorias,
--             en qué orden aparecen en el módulo de revisión, y qué servicio
--             AWS utiliza cada tipo (orientación visual del asesor).
--
--      Diseño INT IDENTITY (catálogo pequeño y estable).
--      EsObligatoria = 1 para los 3 tipos → la regla de negocio se lee desde
--      este catálogo, no desde código, para poder agregar tipos opcionales
--      en el futuro sin tocar el schema (ej. FOTO_RECIBO_SERVICIOS).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CatalogoTiposFotografia') AND type = N'U')
BEGIN
    CREATE TABLE CatalogoTiposFotografia (
        IdTipoFoto          INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(30)         NOT NULL,   -- FOTO_FRONTAL_DOC, FOTO_TRASERA_DOC, SELFIE
        Nombre              NVARCHAR(100)       NOT NULL,   -- Nombre legible para el asesor/UI
        Descripcion         NVARCHAR(300)       NULL,       -- Instrucción de qué debe contener esta foto
        EsObligatoria       BIT                 NOT NULL DEFAULT 1,  -- 1 = bloquea aprobación si falta o está rechazada
        OrdenRevision       INT                 NOT NULL,            -- Orden en que aparece en el módulo de revisión (1,2,3)
        ServicioAWS         VARCHAR(30)         NULL,       -- Referencia informativa: REKOGNITION_DETECT_FACES, etc.
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoTiposFotografia PRIMARY KEY (IdTipoFoto),
        CONSTRAINT UQ_CatalogoTiposFotografia_Codigo UNIQUE (Codigo),
        CONSTRAINT UQ_CatalogoTiposFotografia_Orden  UNIQUE (OrdenRevision)
    );
    PRINT '✓ Tabla CatalogoTiposFotografia creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.2  FotografiasEstudio — entidad de primera clase para ciclo de vida de fotos
--      PH-02: Una fila por INSTANCIA de fotografía (no por tipo).
--             Si el cliente re-sube la selfie, se inserta una nueva fila con
--             NumeroVersion = 2. La fila anterior queda como registro histórico.
--             La foto ACTIVA para el estudio es la de mayor NumeroVersion que
--             no esté en estado REEMPLAZADA.
--
--      EstadoFoto (máquina de estados simplificada):
--        PENDIENTE_CARGA  → cliente aún no sube la foto (link enviado)
--        CARGADA          → foto subida, esperando revisión del asesor
--        EN_REVISION      → asesor está revisando activamente
--        APROBADA         → asesor aprobó la foto
--        RECHAZADA        → asesor rechazó la foto (motivo en RevisionesFotografia)
--        REEMPLAZADA      → foto supersedida por una nueva versión del cliente
--        EXPIRADA         → link de carga expiró sin que el cliente subiera la foto
--
--      BIGINT IDENTITY porque en alto volumen puede haber millones de filas
--      (múltiples estudios × 3 fotos × múltiples versiones por re-cargas).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'FotografiasEstudio') AND type = N'U')
BEGIN
    CREATE TABLE FotografiasEstudio (
        IdFotografia        BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio           BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        IdTipoFoto          INT                     NOT NULL,   -- FK → CatalogoTiposFotografia
        NumeroVersion       INT                     NOT NULL DEFAULT 1,  -- 1=original, 2=re-carga 1, etc.

        -- Datos del archivo
        UrlArchivo          NVARCHAR(500)           NOT NULL,   -- URL en S3 / Azure Blob / almacenamiento
        NombreArchivoOriginal NVARCHAR(200)         NULL,       -- Nombre original del archivo subido
        ContentType         VARCHAR(100)            NULL,       -- MIME type (image/jpeg, image/png)
        TamanoBytes         BIGINT                  NULL,       -- Tamaño del archivo en bytes
        HashArchivo         VARCHAR(64)             NULL,       -- SHA-256 del contenido (detección de duplicados/manipulación)

        -- Estado del ciclo de vida
        EstadoFoto          VARCHAR(20)             NOT NULL DEFAULT 'PENDIENTE_CARGA',
                                                                -- PENDIENTE_CARGA, CARGADA, EN_REVISION,
                                                                -- APROBADA, RECHAZADA, REEMPLAZADA, EXPIRADA

        -- Trazabilidad de carga
        SubidaPorCliente    BIT                     NOT NULL DEFAULT 1,  -- 1=cliente, 0=asesor (carga manual excepcional)
        IdentificadorCargador NVARCHAR(100)         NULL,       -- NitTercero del cliente o login del asesor
        FechaCarga          DATETIME2(3)            NULL,       -- NULL si aún no se ha cargado

        -- Vinculación al proceso de Rekognition
        IdBiometria         BIGINT                  NULL,       -- FK → RegistrosBiometria (resultado del proceso Rekognition)

        -- Vinculación a la solicitud de re-carga que originó esta versión
        IdSolicitudRecarga  BIGINT                  NULL,       -- FK → SolicitudesRecarga (NULL para la versión original)

        -- Metadatos de auditoría
        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_FotografiasEstudio PRIMARY KEY (IdFotografia),
        CONSTRAINT FK_FotografiasEstudio_Estudio    FOREIGN KEY (IdEstudio)  REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_FotografiasEstudio_TipoFoto   FOREIGN KEY (IdTipoFoto) REFERENCES CatalogoTiposFotografia(IdTipoFoto),
        -- FK a RegistrosBiometria se añade en PH-07 (dependencia circular)
        CONSTRAINT UQ_FotografiasEstudio_Version    UNIQUE (IdEstudio, IdTipoFoto, NumeroVersion),
        CONSTRAINT CK_FotografiasEstudio_Estado     CHECK (EstadoFoto IN (
            'PENDIENTE_CARGA','CARGADA','EN_REVISION','APROBADA','RECHAZADA','REEMPLAZADA','EXPIRADA'
        )),
        CONSTRAINT CK_FotografiasEstudio_Version    CHECK (NumeroVersion >= 1)
    );

    -- Índice principal: consultar las 3 fotos de un estudio (módulo de revisión)
    CREATE INDEX IX_FotografiasEstudio_Estudio
        ON FotografiasEstudio(IdEstudio, IdTipoFoto, NumeroVersion);

    -- Índice para cola de revisión: fotos en estado CARGADA o EN_REVISION
    CREATE INDEX IX_FotografiasEstudio_PendientesRevision
        ON FotografiasEstudio(EstadoFoto, FechaCarga)
        WHERE EstadoFoto IN ('CARGADA','EN_REVISION');

    -- Índice para fotos aprobadas (verificación rápida del gate de aprobación)
    CREATE INDEX IX_FotografiasEstudio_Aprobadas
        ON FotografiasEstudio(IdEstudio, EstadoFoto)
        WHERE EstadoFoto = 'APROBADA';

    -- Índice para fotos rechazadas (follow-up de re-carga)
    CREATE INDEX IX_FotografiasEstudio_Rechazadas
        ON FotografiasEstudio(IdEstudio, EstadoFoto)
        WHERE EstadoFoto = 'RECHAZADA';

    -- Índice para FK a biometría
    CREATE INDEX IX_FotografiasEstudio_Biometria
        ON FotografiasEstudio(IdBiometria)
        WHERE IdBiometria IS NOT NULL;

    PRINT '✓ Tabla FotografiasEstudio creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.3  RevisionesFotografia — decisiones de revisión por fotografía
--      PH-03: INSERT-ONLY. Cada vez que un revisor toma una decisión
--             (APROBADA / RECHAZADA) se inserta una nueva fila.
--             Si aprueba → rechaza → vuelve a aprobar, hay 3 filas.
--             La decisión vigente es la última (MAX FechaRevision).
--
--      Justificación de INSERT-ONLY: el modelo de auditoría exige saber
--      "quién aprobó primero, quién rechazó después, quién aprobó al final".
--      Un UPDATE borraría esa cadena. INSERT-ONLY garantiza el trail completo.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RevisionesFotografia') AND type = N'U')
BEGIN
    CREATE TABLE RevisionesFotografia (
        IdRevision          BIGINT IDENTITY(1,1)    NOT NULL,
        IdFotografia        BIGINT                  NOT NULL,   -- FK → FotografiasEstudio
        IdEstudio           BIGINT                  NOT NULL,   -- Redundancia para consultas directas

        -- Quién revisó
        IdRevisor           INT                     NOT NULL,   -- FK lógica → BERP_FABRICASOperadores.idOperadorFabrica
        NombreRevisor       NVARCHAR(150)           NULL,       -- Snapshot del nombre en el momento de la revisión

        -- Decisión
        DecisionRevision    VARCHAR(10)             NOT NULL,   -- APROBADA, RECHAZADA
        MotivoRechazo       NVARCHAR(300)           NULL,       -- Obligatorio si DecisionRevision = 'RECHAZADA'
        CodigoMotivoRechazo VARCHAR(40)             NULL,       -- Código tipificado (del CHECK a continuación)
        NotasAdicionales    NVARCHAR(500)           NULL,       -- Observaciones opcionales del revisor

        FechaRevision       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_RevisionesFotografia  PRIMARY KEY (IdRevision),
        CONSTRAINT FK_RevisionesFotografia_Foto FOREIGN KEY (IdFotografia) REFERENCES FotografiasEstudio(IdFotografia),
        CONSTRAINT FK_RevisionesFotografia_Estudio FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT CK_RevisionesFotografia_Decision CHECK (DecisionRevision IN ('APROBADA','RECHAZADA')),
        CONSTRAINT CK_RevisionesFotografia_MotivoRechazo CHECK (
            CodigoMotivoRechazo IS NULL OR CodigoMotivoRechazo IN (
                'FOTO_BORROSA',         -- Imagen con poca resolución o movida
                'FOTO_CORTADA',         -- El documento no está completo en el encuadre
                'DOCUMENTO_VENCIDO',    -- Cédula con fecha de vencimiento expirada
                'DOCUMENTO_DAÑADO',     -- Documento físicamente deteriorado
                'ROSTRO_NO_VISIBLE',    -- La cara no se ve claramente (selfie)
                'NO_COINCIDE_PERSONA',  -- La selfie no coincide con el documento
                'FOTO_INCORRECTA',      -- Se subió el tipo de foto equivocado
                'REFLEJO_O_BRILLO',     -- Reflexión de luz que impide leer el documento
                'FOTO_DUPLICADA',       -- La misma foto subida para tipos distintos
                'CALIDAD_INSUFICIENTE', -- Calidad general insuficiente para Rekognition
                'OTRO'                  -- Motivo libre en NotasAdicionales
            )
        )
    );

    -- Índice para el módulo de revisión: todas las decisiones sobre una foto
    CREATE INDEX IX_RevisionesFotografia_Foto
        ON RevisionesFotografia(IdFotografia, FechaRevision);

    -- Índice para dashboard de revisiones por estudio
    CREATE INDEX IX_RevisionesFotografia_Estudio
        ON RevisionesFotografia(IdEstudio, FechaRevision);

    -- Índice para métricas de rendimiento del revisor
    CREATE INDEX IX_RevisionesFotografia_Revisor
        ON RevisionesFotografia(IdRevisor, FechaRevision);

    -- Índice para filtrado rápido de rechazos (seguimiento de calidad)
    CREATE INDEX IX_RevisionesFotografia_Rechazos
        ON RevisionesFotografia(CodigoMotivoRechazo, FechaRevision)
        WHERE DecisionRevision = 'RECHAZADA';

    PRINT '✓ Tabla RevisionesFotografia creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.4  SolicitudesRecarga — links de re-carga enviados al cliente
--      PH-04: Cada vez que el sistema o el asesor genera un link para que
--             el cliente suba/resuba una foto, se registra aquí.
--             El link tiene un token único (hash), un canal de envío, una
--             fecha de expiración, y un estado de uso.
--
--      CICLO DE VIDA del link:
--        GENERADO   → Link creado en el sistema
--        ENVIADO    → Link enviado al cliente (email/SMS/WhatsApp)
--        USADO      → Cliente hizo clic y subió la foto exitosamente
--        EXPIRADO   → Venció sin que el cliente lo usara
--        CANCELADO  → Anulado manualmente (se generó uno nuevo)
--
--      Desbloqueo automático: cuando el cliente sube la foto (estado → USADO),
--      se actualiza FotografiasEstudio.EstadoFoto → CARGADA y se puede
--      retomar el flujo si todas las fotos pendientes están cargadas.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'SolicitudesRecarga') AND type = N'U')
BEGIN
    CREATE TABLE SolicitudesRecarga (
        IdSolicitudRecarga  BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio           BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        IdTipoFoto          INT                     NOT NULL,   -- FK → CatalogoTiposFotografia (qué foto se pide)
        IdFotografiaAnterior BIGINT                 NULL,       -- FK → FotografiasEstudio (la foto rechazada o faltante)

        -- Token del link
        TokenRecarga        VARCHAR(128)            NOT NULL,   -- Token único (GUID o hash) para la URL del link
        HashToken           VARCHAR(64)             NULL,       -- SHA-256 del token para verificación segura

        -- Canal de envío
        CanalEnvio          VARCHAR(20)             NOT NULL,   -- EMAIL, SMS, WHATSAPP
        DireccionEnvio      NVARCHAR(200)           NOT NULL,   -- Email o número al que se envió

        -- Estado del link
        EstadoSolicitud     VARCHAR(15)             NOT NULL DEFAULT 'GENERADO',
                                                                -- GENERADO, ENVIADO, USADO, EXPIRADO, CANCELADO
        MotivoSolicitud     NVARCHAR(300)           NULL,       -- Por qué se generó (ej. "Selfie rechazada: foto borrosa")

        -- Control temporal
        FechaExpiracion     DATETIME2(3)            NOT NULL,   -- Calculada al generar: GETDATE() + VIGENCIA_LINK_HORAS
        FechaEnvio          DATETIME2(3)            NULL,       -- Cuándo se envió efectivamente
        FechaUso            DATETIME2(3)            NULL,       -- Cuándo el cliente usó el link
        NumeroReintentos    INT                     NOT NULL DEFAULT 0,  -- Veces que se reenvió el mismo link

        -- Quién generó la solicitud
        GeneradaPorSistema  BIT                     NOT NULL DEFAULT 1,  -- 1=automático, 0=manual por asesor
        IdAsesorGenerador   INT                     NULL,       -- FK lógica → BERP_FABRICASOperadores (si fue manual)

        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_SolicitudesRecarga PRIMARY KEY (IdSolicitudRecarga),
        CONSTRAINT FK_SolicitudesRecarga_Estudio  FOREIGN KEY (IdEstudio)  REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_SolicitudesRecarga_TipoFoto FOREIGN KEY (IdTipoFoto) REFERENCES CatalogoTiposFotografia(IdTipoFoto),
        CONSTRAINT FK_SolicitudesRecarga_FotoAnterior FOREIGN KEY (IdFotografiaAnterior) REFERENCES FotografiasEstudio(IdFotografia),
        CONSTRAINT UQ_SolicitudesRecarga_Token    UNIQUE (TokenRecarga),
        CONSTRAINT CK_SolicitudesRecarga_Canal    CHECK (CanalEnvio IN ('EMAIL','SMS','WHATSAPP')),
        CONSTRAINT CK_SolicitudesRecarga_Estado   CHECK (EstadoSolicitud IN ('GENERADO','ENVIADO','USADO','EXPIRADO','CANCELADO'))
    );

    -- Índice para lookup rápido del token (validación cuando el cliente accede al link)
    CREATE UNIQUE INDEX IX_SolicitudesRecarga_Token
        ON SolicitudesRecarga(TokenRecarga);

    -- Índice para consultar todas las solicitudes de un estudio
    CREATE INDEX IX_SolicitudesRecarga_Estudio
        ON SolicitudesRecarga(IdEstudio, IdTipoFoto, FechaCreacion);

    -- Índice para expiración batch (job nocturno que marca links expirados)
    CREATE INDEX IX_SolicitudesRecarga_Expiracion
        ON SolicitudesRecarga(FechaExpiracion, EstadoSolicitud)
        WHERE EstadoSolicitud IN ('GENERADO','ENVIADO');

    -- Índice para analíticas de canal de envío
    CREATE INDEX IX_SolicitudesRecarga_Canal
        ON SolicitudesRecarga(CanalEnvio, EstadoSolicitud, FechaCreacion);

    PRINT '✓ Tabla SolicitudesRecarga creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.5  HistorialFotografias — auditoría inmutable de cambios en FotografiasEstudio
--      PH-05: INSERT-ONLY. Registra cada transición de estado de una foto,
--             quién la provocó y en qué contexto.
--
--      Separado de RevisionesFotografia porque:
--      - RevisionesFotografia registra DECISIONES HUMANAS (revisor → aprobó/rechazó)
--      - HistorialFotografias registra TRANSICIONES DE ESTADO (sistema/cliente/asesor)
--      - La auditoría completa requiere ambas perspectivas
--
--      Ejemplos de entradas:
--        EstadoAnterior=NULL,       EstadoNuevo=PENDIENTE_CARGA, Actor=SISTEMA  → Link generado
--        EstadoAnterior=PENDIENTE_CARGA, EstadoNuevo=CARGADA,   Actor=CLIENTE  → Cliente sube foto
--        EstadoAnterior=CARGADA,    EstadoNuevo=APROBADA,       Actor=ASESOR   → Revisión aprobatoria
--        EstadoAnterior=APROBADA,   EstadoNuevo=RECHAZADA,      Actor=ASESOR   → Revisión rechazatoria
--        EstadoAnterior=RECHAZADA,  EstadoNuevo=REEMPLAZADA,    Actor=SISTEMA  → Nueva versión sube
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'HistorialFotografias') AND type = N'U')
BEGIN
    CREATE TABLE HistorialFotografias (
        IdHistorialFoto     BIGINT IDENTITY(1,1)    NOT NULL,
        IdFotografia        BIGINT                  NOT NULL,   -- FK → FotografiasEstudio
        IdEstudio           BIGINT                  NOT NULL,   -- Redundancia para consultas directas
        IdTipoFoto          INT                     NOT NULL,   -- Redundancia para filtros rápidos

        -- Transición de estado
        EstadoAnterior      VARCHAR(20)             NULL,       -- NULL en la primera transición (creación)
        EstadoNuevo         VARCHAR(20)             NOT NULL,

        -- Contexto de la transición
        TipoActor           VARCHAR(15)             NOT NULL DEFAULT 'SISTEMA',  -- SISTEMA, CLIENTE, ASESOR
        IdActorUsuario      INT                     NULL,       -- FK lógica si es ASESOR (BERP_FABRICASOperadores)
        IdentificadorActor  NVARCHAR(100)           NULL,       -- NitTercero si CLIENTE, login si ASESOR, 'SISTEMA' si automático
        MotivoTransicion    NVARCHAR(300)           NULL,       -- Descripción del motivo (por ej. motivo de rechazo)
        IdRevisionRelacionada BIGINT                NULL,       -- FK → RevisionesFotografia (si la transición fue por revisión)
        IdSolicitudRelacionada BIGINT               NULL,       -- FK → SolicitudesRecarga (si la transición fue por re-carga)

        FechaTransicion     DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_HistorialFotografias PRIMARY KEY (IdHistorialFoto),
        CONSTRAINT FK_HistFotos_Fotografia  FOREIGN KEY (IdFotografia) REFERENCES FotografiasEstudio(IdFotografia),
        CONSTRAINT FK_HistFotos_Estudio     FOREIGN KEY (IdEstudio) REFERENCES EstudiosCredito(IdEstudio),
        CONSTRAINT FK_HistFotos_TipoFoto    FOREIGN KEY (IdTipoFoto) REFERENCES CatalogoTiposFotografia(IdTipoFoto),
        CONSTRAINT FK_HistFotos_Revision    FOREIGN KEY (IdRevisionRelacionada) REFERENCES RevisionesFotografia(IdRevision),
        CONSTRAINT FK_HistFotos_Solicitud   FOREIGN KEY (IdSolicitudRelacionada) REFERENCES SolicitudesRecarga(IdSolicitudRecarga),
        CONSTRAINT CK_HistFotos_Actor       CHECK (TipoActor IN ('SISTEMA','CLIENTE','ASESOR')),
        CONSTRAINT CK_HistFotos_EstNuevo    CHECK (EstadoNuevo IN (
            'PENDIENTE_CARGA','CARGADA','EN_REVISION','APROBADA','RECHAZADA','REEMPLAZADA','EXPIRADA'
        ))
    );

    -- Línea de tiempo completa para una foto específica
    CREATE INDEX IX_HistFotos_Fotografia
        ON HistorialFotografias(IdFotografia, FechaTransicion);

    -- Línea de tiempo completa para un estudio (módulo de revisión / auditoría)
    CREATE INDEX IX_HistFotos_Estudio
        ON HistorialFotografias(IdEstudio, FechaTransicion);

    -- Índice para filtrar por tipo de foto (ej. todas las transiciones de SELFIEs)
    CREATE INDEX IX_HistFotos_TipoFoto
        ON HistorialFotografias(IdTipoFoto, EstadoNuevo, FechaTransicion);

    PRINT '✓ Tabla HistorialFotografias creada';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.6  ALTER EstudiosCredito — contador de fotos aprobadas y estado de revisión
--      PH-06: Columnas de resumen para evitar JOINs costosos en la validación
--             del gate de aprobación ("¿están las 3 fotos aprobadas?").
--
--      FotografiasAprobadas: entero desnormalizado, incrementado por trigger/SP
--        cuando una foto pasa a APROBADA. Gate: FotografiasAprobadas >= 3.
--      EstadoRevisionFotos: estado resumen del proceso fotográfico para la UI.
--        PENDIENTE      → aún no se han subido todas las fotos
--        EN_REVISION    → todas cargadas, al menos una en revisión
--        APROBADO       → las 3 fotos obligatorias están APROBADAS
--        CON_RECHAZOS   → al menos una foto fue rechazada (re-carga pendiente)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'FotografiasAprobadas')
BEGIN
    ALTER TABLE EstudiosCredito
        ADD FotografiasAprobadas INT NOT NULL DEFAULT 0;  -- Contador desnormalizado: 0-3. Gate: = 3 para aprobar crédito
    PRINT '✓ EstudiosCredito: columna FotografiasAprobadas añadida';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'EstadoRevisionFotos')
BEGIN
    ALTER TABLE EstudiosCredito
        ADD EstadoRevisionFotos VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE';
                                                            -- PENDIENTE, EN_REVISION, APROBADO, CON_RECHAZOS
    PRINT '✓ EstudiosCredito: columna EstadoRevisionFotos añadida';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'EstudiosCredito') AND name = 'IX_EstudiosCredito_RevisionFotos')
BEGIN
    CREATE INDEX IX_EstudiosCredito_RevisionFotos
        ON EstudiosCredito(EstadoRevisionFotos, IdEstadoActual)
        WHERE EstadoRevisionFotos IN ('EN_REVISION','CON_RECHAZOS');
    PRINT '✓ EstudiosCredito: índice IX_EstudiosCredito_RevisionFotos creado';
END
GO

-- Constraint para los valores válidos de EstadoRevisionFotos
IF NOT EXISTS (
    SELECT * FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'EstudiosCredito')
      AND name = 'CK_EstudiosCredito_EstadoRevisionFotos'
)
BEGIN
    ALTER TABLE EstudiosCredito
        ADD CONSTRAINT CK_EstudiosCredito_EstadoRevisionFotos
        CHECK (EstadoRevisionFotos IN ('PENDIENTE','EN_REVISION','APROBADO','CON_RECHAZOS'));
    PRINT '✓ EstudiosCredito: constraint CK_EstudiosCredito_EstadoRevisionFotos añadido';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.7  ALTER RegistrosBiometria — FKs directas a las 3 fotografías del proceso
--      PH-07: El proceso Rekognition opera SOBRE fotografías concretas.
--             Estas FKs permiten saber exactamente qué versión de cada foto
--             usó Rekognition para calcular el match %, hacer el OCR, y la
--             prueba de vida. Crítico para reproductibilidad de auditoría:
--             "¿con qué foto se procesó la biometría del estudio 12345?"
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IdFotografiaFrontal')
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD IdFotografiaFrontal BIGINT NULL;  -- FK → FotografiasEstudio (FOTO_FRONTAL_DOC usada en Rekognition)
    PRINT '✓ RegistrosBiometria: columna IdFotografiaFrontal añadida';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IdFotografiaReverso')
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD IdFotografiaReverso BIGINT NULL;  -- FK → FotografiasEstudio (FOTO_TRASERA_DOC usada en OCR)
    PRINT '✓ RegistrosBiometria: columna IdFotografiaReverso añadida';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IdFotografiaSelfie')
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD IdFotografiaSelfie BIGINT NULL;   -- FK → FotografiasEstudio (SELFIE usada en CompareFaces/DetectFaces)
    PRINT '✓ RegistrosBiometria: columna IdFotografiaSelfie añadida';
END
GO

-- Añadir FKs físicas (FotografiasEstudio ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoFrontal'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoFrontal
        FOREIGN KEY (IdFotografiaFrontal) REFERENCES FotografiasEstudio(IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoFrontal añadida';
END
GO

IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoReverso'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoReverso
        FOREIGN KEY (IdFotografiaReverso) REFERENCES FotografiasEstudio(IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoReverso añadida';
END
GO

IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoSelfie'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoSelfie
        FOREIGN KEY (IdFotografiaSelfie) REFERENCES FotografiasEstudio(IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoSelfie añadida';
END
GO

-- Índices para los FK en RegistrosBiometria
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IX_RegistrosBiometria_FotoFrontal')
BEGIN
    CREATE INDEX IX_RegistrosBiometria_FotoFrontal ON RegistrosBiometria(IdFotografiaFrontal)
        WHERE IdFotografiaFrontal IS NOT NULL;
    PRINT '✓ RegistrosBiometria: índice IX_RegistrosBiometria_FotoFrontal creado';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IX_RegistrosBiometria_FotoReverso')
BEGIN
    CREATE INDEX IX_RegistrosBiometria_FotoReverso ON RegistrosBiometria(IdFotografiaReverso)
        WHERE IdFotografiaReverso IS NOT NULL;
    PRINT '✓ RegistrosBiometria: índice IX_RegistrosBiometria_FotoReverso creado';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'RegistrosBiometria') AND name = 'IX_RegistrosBiometria_FotoSelfie')
BEGIN
    CREATE INDEX IX_RegistrosBiometria_FotoSelfie ON RegistrosBiometria(IdFotografiaSelfie)
        WHERE IdFotografiaSelfie IS NOT NULL;
    PRINT '✓ RegistrosBiometria: índice IX_RegistrosBiometria_FotoSelfie creado';
END
GO

-- Ahora se puede añadir la FK en FotografiasEstudio → RegistrosBiometria
-- (la dependencia circular se rompe añadiendo la FK como ALTER posterior)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'FotografiasEstudio')
      AND name = 'FK_FotografiasEstudio_Biometria'
)
BEGIN
    ALTER TABLE FotografiasEstudio
        ADD CONSTRAINT FK_FotografiasEstudio_Biometria
        FOREIGN KEY (IdBiometria) REFERENCES RegistrosBiometria(IdBiometria);
    PRINT '✓ FotografiasEstudio: FK FK_FotografiasEstudio_Biometria añadida';
END
GO

-- FK en FotografiasEstudio → SolicitudesRecarga
-- (SolicitudesRecarga ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'FotografiasEstudio')
      AND name = 'FK_FotografiasEstudio_SolicitudRecarga'
)
BEGIN
    ALTER TABLE FotografiasEstudio
        ADD CONSTRAINT FK_FotografiasEstudio_SolicitudRecarga
        FOREIGN KEY (IdSolicitudRecarga) REFERENCES SolicitudesRecarga(IdSolicitudRecarga);
    PRINT '✓ FotografiasEstudio: FK FK_FotografiasEstudio_SolicitudRecarga añadida';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.8  NUEVOS ESTADOS — PENDIENTE_FOTOS y FOTOS_EN_REVISION
--      PH-08: El flujo necesita dos estados adicionales para representar
--             el bloqueo fotográfico en la máquina de estados del estudio:
--
--      PENDIENTE_FOTOS:   El proceso está bloqueado porque al menos una
--                         foto obligatoria está faltante o fue rechazada.
--                         El cliente debe subir/re-subir fotos via link.
--      FOTOS_EN_REVISION: Todas las fotos fueron cargadas. El asesor de
--                         fábrica debe revisarlas antes de continuar.
--                         Estado intermedio entre carga y aprobación.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_FOTOS')
BEGIN
    INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES (
        'PENDIENTE_FOTOS',
        'Pendiente Carga de Fotografías',
        'PROCESO', 0, 0,
        'El proceso está bloqueado porque al menos una fotografía obligatoria (frente/reverso cédula o selfie) '
        + 'está faltante o fue rechazada. Se ha enviado link de re-carga al cliente.'
    );
    PRINT '✓ Estado PENDIENTE_FOTOS insertado en CatalogoEstados';
END
GO

IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'FOTOS_EN_REVISION')
BEGIN
    INSERT INTO CatalogoEstados (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES (
        'FOTOS_EN_REVISION',
        'Fotografías en Revisión Manual',
        'PROCESO', 0, 0,
        'Todas las fotografías obligatorias fueron cargadas por el cliente. '
        + 'El asesor de fábrica está revisando las imágenes para aprobarlas o rechazarlas.'
    );
    PRINT '✓ Estado FOTOS_EN_REVISION insertado en CatalogoEstados';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.9  Transiciones de estado para los nuevos estados fotográficos
--      PH-08 (continuación): Integración con la máquina de estados existente
-- ─────────────────────────────────────────────────────────────────────────────
DECLARE
    @IdPendFotos    INT,
    @IdFotosRev     INT,
    @IdEnProgreso2  INT,
    @IdPendBiom     INT,
    @IdRechazado2   INT;

SELECT @IdPendFotos  = IdEstado FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_FOTOS';
SELECT @IdFotosRev   = IdEstado FROM CatalogoEstados WHERE Codigo = 'FOTOS_EN_REVISION';
SELECT @IdEnProgreso2 = IdEstado FROM CatalogoEstados WHERE Codigo = 'EN_PROGRESO';
SELECT @IdPendBiom   = IdEstado FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_BIOMETRIA';
SELECT @IdRechazado2 = IdEstado FROM CatalogoEstados WHERE Codigo = 'RECHAZADO';

-- EN_PROGRESO → PENDIENTE_FOTOS (foto faltante o rechazada detectada durante el flujo)
IF @IdEnProgreso2 IS NOT NULL AND @IdPendFotos IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdEnProgreso2 AND IdEstadoDestino = @IdPendFotos)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso2, @IdPendFotos, 1,
            'Foto obligatoria faltante o rechazada: sistema envía link de re-carga al cliente');
END

-- PENDIENTE_BIOMETRIA → PENDIENTE_FOTOS (durante la fase biométrica se detecta que las fotos no están OK)
IF @IdPendBiom IS NOT NULL AND @IdPendFotos IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendBiom AND IdEstadoDestino = @IdPendFotos)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendBiom, @IdPendFotos, 1,
            'Desde paso biométrico: foto rechazada o de calidad insuficiente para Rekognition');
END

-- PENDIENTE_FOTOS → FOTOS_EN_REVISION (cliente subió todas las fotos pendientes)
IF @IdPendFotos IS NOT NULL AND @IdFotosRev IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendFotos AND IdEstadoDestino = @IdFotosRev)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendFotos, @IdFotosRev, 0,
            'Cliente subió todas las fotos pendientes: pasan a revisión del asesor');
END

-- PENDIENTE_FOTOS → PENDIENTE_FOTOS (link expiró, se genera nuevo link — misma cola)
-- No aplica como transición de estado, el estado no cambia.

-- FOTOS_EN_REVISION → EN_PROGRESO (asesor aprueba todas las fotos, proceso se reanuda)
IF @IdFotosRev IS NOT NULL AND @IdEnProgreso2 IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdEnProgreso2)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdEnProgreso2, 0,
            'Asesor aprobó todas las fotografías: proceso de crédito se reanuda automáticamente');
END

-- FOTOS_EN_REVISION → PENDIENTE_FOTOS (asesor rechaza al menos una foto, se pide re-carga)
IF @IdFotosRev IS NOT NULL AND @IdPendFotos IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdPendFotos)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdPendFotos, 1,
            'Asesor rechazó una o más fotografías: se genera nuevo link de re-carga al cliente');
END

-- FOTOS_EN_REVISION → RECHAZADO (fotos definitivamente no viables — ej. persona suplantada)
IF @IdFotosRev IS NOT NULL AND @IdRechazado2 IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdRechazado2)
BEGIN
    INSERT INTO TransicionesEstado (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdRechazado2, 1,
            'Asesor determina rechazo definitivo por fotografías: suplantación, documento falso, etc.');
END

PRINT '✓ Transiciones PENDIENTE_FOTOS y FOTOS_EN_REVISION insertadas';
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.10 Seeds CatalogoTiposFotografia — los 3 tipos obligatorios
--      PH-10: Datos iniciales del catálogo de tipos de fotografía.
--             OrdenRevision define el orden en que aparecen en el módulo
--             de revisión del asesor (1=Frontal, 2=Reverso, 3=Selfie).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoTiposFotografia)
BEGIN
    INSERT INTO CatalogoTiposFotografia
        (Codigo, Nombre, Descripcion, EsObligatoria, OrdenRevision, ServicioAWS)
    VALUES
    (
        'FOTO_FRONTAL_DOC',
        'Foto Frontal de Cédula de Ciudadanía',
        'Fotografía del lado frontal de la cédula de ciudadanía colombiana. '
        + 'Debe mostrar claramente: foto del titular, nombres y apellidos, número de documento, '
        + 'fecha de nacimiento y fecha de expedición. Usada por OCR para extracción de datos '
        + 'y por Rekognition CompareFaces para verificar que coincide con la selfie.',
        1, 1, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'FOTO_TRASERA_DOC',
        'Foto Reverso de Cédula de Ciudadanía',
        'Fotografía del reverso de la cédula de ciudadanía colombiana. '
        + 'Debe mostrar: grupo sanguíneo, RH, huella dactilar y código de barras/código Registraduría. '
        + 'Usada por OCR para extracción de tipo de sangre y verificación del código de barras.',
        1, 2, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'SELFIE',
        'Selfie del Titular',
        'Foto del rostro del cliente tomada en tiempo real (no foto de foto). '
        + 'Debe mostrar el rostro completo de frente, sin lentes oscuros ni elementos que lo cubran. '
        + 'Usada por Rekognition DetectFaces (prueba de vida) y CompareFaces '
        + '(comparar con foto de cédula para validar identidad).',
        1, 3, 'REKOGNITION_DETECT_FACES'
    );

    PRINT '✓ Seeds insertados en CatalogoTiposFotografia';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.11 Seeds ConfiguracionReglasNegocio — parámetros del módulo fotográfico
--      PH-09: Todos los valores límite del proceso de fotografías son
--             configurables sin tocar código, siguiendo el patrón existente.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio WHERE Codigo = 'VIGENCIA_LINK_RECARGA_HORAS')
BEGIN
    INSERT INTO ConfiguracionReglasNegocio
        (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion)
    VALUES
    (
        'VIGENCIA_LINK_RECARGA_HORAS',
        'Vigencia del link de re-carga de fotografías (horas)',
        '48', 'INT', 'FOTOS',
        'Número de horas que tiene el cliente para usar el link de re-carga antes de que expire. '
        + 'Pasado este tiempo, el asesor debe generar un nuevo link manualmente.'
    ),
    (
        'MAX_REINTENTOS_RECARGA_FOTO',
        'Máximo de solicitudes de re-carga por foto por estudio',
        '3', 'INT', 'FOTOS',
        'Número máximo de veces que se puede solicitar re-carga de la misma foto en el mismo estudio. '
        + 'Si se supera, el estudio pasa a revisión manual de fábrica.'
    ),
    (
        'MAX_VERSIONES_FOTO',
        'Máximo de versiones por fotografía por estudio',
        '4', 'INT', 'FOTOS',
        'Número máximo de veces que el cliente puede re-subir la misma foto. '
        + 'Incluye la subida original. Al superarlo, el caso se escala a fábrica para revisión.'
    ),
    (
        'FOTOS_OBLIGATORIAS_REQUERIDAS',
        'Número de fotografías obligatorias requeridas para aprobación',
        '3', 'INT', 'FOTOS',
        'Cantidad de fotos que deben estar en estado APROBADA para que el gate de aprobación '
        + 'de crédito sea superado. Valor fijo = 3 (frontal, reverso, selfie). '
        + 'Parametrizado para auditoría; no se debe cambiar sin revisión de cumplimiento.'
    ),
    (
        'CANAL_DEFECTO_RECARGA',
        'Canal de envío por defecto para links de re-carga',
        'WHATSAPP', 'TEXT', 'FOTOS',
        'Canal preferido para enviar el link de re-carga al cliente. '
        + 'Valores: EMAIL, SMS, WHATSAPP. Se usa cuando no hay preferencia declarada por el cliente.'
    ),
    (
        'ALERTA_FOTO_RECHAZADA_VECES',
        'Número de rechazos de una misma foto que activan alerta de fraude',
        '2', 'INT', 'FOTOS',
        'Si la misma foto es rechazada este número de veces consecutivas, '
        + 'se activa una alerta de fraude y el caso se escala a revisión manual de fábrica.'
    );

    PRINT '✓ Seeds de parámetros fotográficos insertados en ConfiguracionReglasNegocio';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.12 Seeds CatalogoReglasFraude — reglas de fraude fotográfico
--      PH-10 (continuación): Añadir reglas de fraude específicas al módulo
--             de fotografías (complementan las reglas de OTP/email del v2.2).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoReglasFraude WHERE Codigo = 'FOTO_RECHAZADA_MULTIPLE_VECES')
BEGIN
    INSERT INTO CatalogoReglasFraude
        (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica)
    VALUES
    (
        'FOTO_RECHAZADA_MULTIPLE_VECES',
        'Fotografía rechazada múltiples veces consecutivas',
        'La misma fotografía fue rechazada en dos o más revisiones consecutivas. '
        + 'Puede indicar intento de usar documentos falsificados o fotos de baja calidad intencional.',
        'MEDIO', 'ESCALAR'
    ),
    (
        'MAX_VERSIONES_FOTO_SUPERADO',
        'Se superó el máximo de versiones de foto permitidas',
        'El cliente ha intentado subir la misma foto más veces del límite configurado. '
        + 'Puede indicar intento persistente de pasar controles de identidad con documentos falsos.',
        'ALTO', 'ESCALAR'
    ),
    (
        'FOTO_DUPLICADA_OTRO_ESTUDIO',
        'Fotografía idéntica usada en otro estudio de crédito',
        'El hash del archivo de la foto es idéntico al de una foto en otro estudio activo. '
        + 'Puede indicar reutilización fraudulenta de fotos de otra persona.',
        'CRITICO', 'BLOQUEAR'
    ),
    (
        'SELFIE_NO_COINCIDE_DOCUMENTO',
        'Selfie no coincide con fotografía del documento según Rekognition',
        'El porcentaje de coincidencia facial entre la selfie y la foto del documento es '
        + 'menor al umbral configurado (UMBRAL_MATCH_FACIAL). Posible suplantación de identidad.',
        'ALTO', 'ESCALAR'
    );

    PRINT '✓ Seeds de reglas de fraude fotográfico insertados en CatalogoReglasFraude';
END
GO

-- ─────────────────────────────────────────────────────────────────────────────
-- 7.13 Seeds CatalogoMotivosEscalamiento — motivos de escalamiento fotográfico
--      PH-10 (continuación): Añadir motivos de escalamiento específicos al
--             módulo de fotografías.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoMotivosEscalamiento WHERE Codigo = 'FOTO_MAX_REINTENTOS_SUPERADO')
BEGIN
    INSERT INTO CatalogoMotivosEscalamiento
        (Codigo, Nombre, Descripcion, Origen)
    VALUES
    (
        'FOTO_MAX_REINTENTOS_SUPERADO',
        'Máximo de re-cargas de fotografía superado',
        'El cliente superó el número máximo de intentos de re-carga para una foto. '
        + 'Requiere revisión manual del asesor para determinar si el problema es '
        + 'de calidad o de intento fraudulento.',
        'SISTEMA'
    ),
    (
        'FOTO_RECHAZADA_VARIAS_VECES',
        'Fotografía rechazada en múltiples revisiones',
        'La misma fotografía fue rechazada por el asesor en dos o más revisiones. '
        + 'Se escala para que un supervisor decida si continuar o rechazar el crédito.',
        'SISTEMA'
    ),
    (
        'LINK_RECARGA_EXPIRADO_SIN_USO',
        'Link de re-carga de foto expiró sin ser usado',
        'Se generó un link de re-carga para una fotografía y expiró sin que el cliente '
        + 'lo usara. El asesor debe contactar al cliente o generar un nuevo link.',
        'SISTEMA'
    ),
    (
        'SELFIE_BIOMETRIA_FALLO',
        'Selfie falló verificación biométrica Rekognition',
        'La selfie no superó la comparación facial de AWS Rekognition contra el documento. '
        + 'Puede ser problema de calidad de foto o posible suplantación de identidad.',
        'SISTEMA'
    );

    PRINT '✓ Seeds de motivos de escalamiento fotográfico insertados en CatalogoMotivosEscalamiento';
END
GO


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE MIGRACIÓN
-- ==============================================================================
/*
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                        RESUMEN DE IMPLEMENTACIÓN V2.3                        ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║                                                                              ║
  ║  TABLAS CREADAS:                     27 tablas (23 v2.2 + 4 v2.3)           ║
  ║  ├── Configuración:                  9 tablas                                ║
  ║  │   ├── CatalogoCanalesOrigen       (G-DB-01 — nueva en v2.1)               ║
  ║  │   ├── CatalogoReglasFraude        (SA-06 — nueva en v2.2)                 ║
  ║  │   ├── CatalogoMotivosEscalamiento (SA-01 — nueva en v2.2)                 ║
  ║  │   └── CatalogoTiposFotografia     (PH-01 — nueva en v2.3)                 ║
  ║  ├── Transaccionales:                14 tablas                               ║
  ║  │   ├── EvidenciasFabrica           (GT-08 — nueva en v2.1)                 ║
  ║  │   ├── EscalamientosFabrica        (SA-02 — nueva en v2.2)                 ║
  ║  │   ├── AlertasFraude               (SA-05 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── LogValidacionesOTP          (SA-03 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── HistorialDatosSensibles     (SA-04 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── FotografiasEstudio          (PH-02 — nueva en v2.3)                 ║
  ║  │   ├── SolicitudesRecarga          (PH-04 — nueva en v2.3)                 ║
  ║  ├── Auditoría:                      5 tablas                                ║
  ║  │   ├── RevisionesFotografia        (PH-03 — nueva en v2.3, INSERT-ONLY)    ║
  ║  │   └── HistorialFotografias        (PH-05 — nueva en v2.3, INSERT-ONLY)    ║
  ║  └── Integración:                    1 tabla (TercerosFabricas)              ║
  ║                                                                              ║
  ║  TABLAS MODIFICADAS (ALTER):         10 tablas                               ║
  ║  ├── QUAC.dbo.KCRM_CadenaCreditos   +4 columnas (v2.1)                      ║
  ║  ├── QUAC.dbo.BERP_FABRICASOperadores +1 columna (v2.1)                     ║
  ║  ├── EstudiosCredito                 +10 col (v2.1) +5 col (v2.2: SA-07)    ║
  ║  │                                   +2 col (v2.3: PH-06)                    ║
  ║  ├── RetosSeguridad                  +2 col (v2.1) +1 col DireccionEnvio    ║
  ║  ├── EvaluacionesRiesgo              CHECK ampliado (G-DB-03)                ║
  ║  ├── RegistrosBiometria              +4 columnas OCR (G-DB-08)               ║
  ║  │                                   +3 FK a FotografiasEstudio (PH-07)      ║
  ║  ├── ValidacionesContactabilidad     +1 col EstadoUbica (v2.1) +1 FK (SA-10) ║
  ║  ├── ConsentimientosLegales          +1 columna (G-DB-09)                    ║
  ║  └── HistorialEstados                +1 col IdCorrelacion (SA-08)            ║
  ║                                                                              ║
  ║  ESTADOS NUEVOS EN CatalogoEstados:                                          ║
  ║  ├── REVISION_FABRICA               (SA-11 — estado PROCESO)                 ║
  ║  ├── BLOQUEADO_FRAUDE               (SA-11 — estado TERMINAL)                ║
  ║  ├── PENDIENTE_FOTOS                (PH-08 — estado PROCESO)                 ║
  ║  └── FOTOS_EN_REVISION              (PH-08 — estado PROCESO)                 ║
  ║                                                                              ║
  ║  ESTRATEGIA TERCEROS:                                                        ║
  ║  ├── QUAC.dbo.terceros: SIN MODIFICACIÓN (tabla producción existente)        ║
  ║  └── TercerosFabricas: Tabla propia como fuente de verdad                    ║
  ║                                                                              ║
  ║  DATOS SEMILLA INSERTADOS:           13 catálogos                            ║
  ║  ├── FasesEstudio:                   7 registros                             ║
  ║  ├── CatalogoEstados:               15 registros (11 base + 4 nuevos)        ║
  ║  ├── PasosEstudio:                  13 registros                             ║
  ║  ├── TransicionesEstado:            40 registros (+8 nuevas v2.3)            ║
  ║  ├── ConfiguracionReglasNegocio:    18 registros (+6 nuevos v2.3)            ║
  ║  ├── CatalogoCanalesOrigen:          3 registros                             ║
  ║  ├── CatalogoReglasFraude:          12 registros (+4 nuevas v2.3)            ║
  ║  ├── CatalogoMotivosEscalamiento:   12 registros (+4 nuevos v2.3)            ║
  ║  └── CatalogoTiposFotografia:        3 registros (PH-10)                     ║
  ║                                                                              ║
  ║  GAPS CORREGIDOS v2.3 (10) — Módulo de Gestión de Fotografías 2026-04-13:   ║
  ║  ├── PH-01: CatalogoTiposFotografia (3 tipos: frontal, reverso, selfie)      ║
  ║  ├── PH-02: FotografiasEstudio (ciclo de vida individual por foto + versión) ║
  ║  ├── PH-03: RevisionesFotografia (decisiones de revisión INSERT-ONLY)        ║
  ║  ├── PH-04: SolicitudesRecarga (links con estado, canal, expiración)         ║
  ║  ├── PH-05: HistorialFotografias (auditoría inmutable INSERT-ONLY)           ║
  ║  ├── PH-06: EstudiosCredito +FotografiasAprobadas +EstadoRevisionFotos       ║
  ║  ├── PH-07: RegistrosBiometria +IdFotografiaFrontal +Reverso +Selfie (FKs)  ║
  ║  ├── PH-08: Estados PENDIENTE_FOTOS + FOTOS_EN_REVISION + 6 transiciones    ║
  ║  ├── PH-09: ConfiguracionReglasNegocio +6 parámetros fotográficos            ║
  ║  └── PH-10: Seeds completos para todos los catálogos fotográficos            ║
  ║                                                                              ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
*/

PRINT '================================================================';
PRINT '  MIGRACIÓN FABRICASV2.3 COMPLETADA EXITOSAMENTE';
PRINT '================================================================';
PRINT '  Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';