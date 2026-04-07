/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS V2 
  
  ESTRUCTURA DEL SCRIPT:
  ─────────────────────────────────────────────────────────────────────────────
  1. TABLAS DE CONFIGURACIÓN (6 tablas)      → Parametrización del flujo
  2. MODIFICACIÓN DE TABLAS EXISTENTES        → ALTER TABLE a tablas prod.
  3. TABLAS TRANSACCIONALES (7 tablas)        → Operaciones del proceso
  4. TABLAS DE AUDITORÍA (3 tablas)           → Trazabilidad inmutable
  5. DATOS SEMILLA (SEEDS)                    → Catálogos iniciales
  
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
-- SECCIÓN 5: DATOS SEMILLA (SEEDS)
-- ==============================================================================
-- Datos iniciales para los catálogos de configuración.
-- Solo se insertan si las tablas están vacías.

-- ─────────────────────────────────────────────────────────────────────────────
-- 5.1 Insertar FasesEstudio (7 fases)
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
-- 5.2 Insertar CatalogoEstados (11 estados)
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
-- 5.3 Insertar PasosEstudio (13 pasos)
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
-- 5.4 Insertar TransicionesEstado (transiciones válidas)
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
-- 5.5 Insertar ConfiguracionReglasNegocio (reglas iniciales)
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
-- 5.6 Insertar CatalogoCanalesOrigen (canales iniciales)
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


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE MIGRACIÓN
-- ==============================================================================
/*
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                        RESUMEN DE IMPLEMENTACIÓN V2.1                        ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║                                                                              ║
  ║  TABLAS CREADAS:                     17 tablas                               ║
  ║  ├── Configuración:                  6 tablas                                ║
  ║  │   └── CatalogoCanalesOrigen       (G-DB-01 — nueva)                       ║
  ║  ├── Transaccionales:                7 tablas                                ║
  ║  │   └── EvidenciasFabrica           (GT-08 — nueva)                         ║
  ║  ├── Auditoría:                      3 tablas                                ║
  ║  └── Integración:                    1 tabla (TercerosFabricas)              ║
  ║                                                                              ║
  ║  TABLAS MODIFICADAS (ALTER):         6 tablas                                ║
  ║  ├── QUAC.dbo.KCRM_CadenaCreditos   +4 columnas                             ║
  ║  ├── QUAC.dbo.BERP_FABRICASOperadores +1 columna                            ║
  ║  ├── EstudiosCredito                 +10 columnas + 2 FK (G-DB-01,02,06,07,GT-04,GT-05)
  ║  ├── RetosSeguridad                  +2 columnas (G-DB-05)                   ║
  ║  ├── EvaluacionesRiesgo              CHECK ampliado (G-DB-03)                ║
  ║  ├── RegistrosBiometria              +4 columnas OCR (G-DB-08)               ║
  ║  ├── ValidacionesContactabilidad     +1 columna (G-DB-04)                    ║
  ║  └── ConsentimientosLegales          +1 columna (G-DB-09)                    ║
  ║                                                                              ║
  ║  ESTRATEGIA TERCEROS:                                                        ║
  ║  ├── QUAC.dbo.terceros: SIN MODIFICACIÓN (tabla producción existente)        ║
  ║  └── TercerosFabricas: Tabla propia como fuente de verdad                    ║
  ║                                                                              ║
  ║  DATOS SEMILLA INSERTADOS:           6 catálogos                             ║
  ║  ├── FasesEstudio:                   7 registros                             ║
  ║  ├── CatalogoEstados:               11 registros                             ║
  ║  ├── PasosEstudio:                  13 registros                             ║
  ║  ├── TransicionesEstado:             26 registros                            ║
  ║  ├── ConfiguracionReglasNegocio:     8 registros                             ║
  ║  └── CatalogoCanalesOrigen:          3 registros (G-DB-01)                   ║
  ║                                                                              ║
  ║  GAPS CORREGIDOS:                                                            ║
  ║  ├── G-DB-01: CatalogoCanalesOrigen + FK EstudiosCredito.IdCanal             ║
  ║  ├── G-DB-02: FK física NitTercero → TercerosFabricas                        ║
  ║  ├── G-DB-03: CHECK TipoEvaluacion ampliado (ANTECEDENTES, UBICA)            ║
  ║  ├── G-DB-04: EstadoUbica granular en ValidacionesContactabilidad            ║
  ║  ├── G-DB-05: NumeroReenvios + UltimoReenvio en RetosSeguridad               ║
  ║  ├── G-DB-06: EmailCliente + EmailUbica en EstudiosCredito                   ║
  ║  ├── G-DB-07: SlugPasoWeb + FechaUltimoAbandono en EstudiosCredito           ║
  ║  ├── G-DB-08: Campos OCR en RegistrosBiometria (4 columnas)                  ║
  ║  ├── G-DB-09: TipoFirma en ConsentimientosLegales                            ║
  ║  ├── GT-04: EsCupoExpress + TipoCierre en EstudiosCredito                    ║
  ║  ├── GT-05: 4 columnas de dirección capturada en EstudiosCredito             ║
  ║  └── GT-08: Nueva tabla EvidenciasFabrica                                    ║
  ║                                                                              ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
*/

PRINT '================================================================';
PRINT '  MIGRACIÓN FABRICASV2.1 COMPLETADA EXITOSAMENTE';
PRINT '================================================================';
PRINT '  Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';