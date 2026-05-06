/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS V2 (PARA ENTORNO DE PRUEBAS)
  Motor:    SQL Server 2019+
  Versión:  2.8-PRUEBAS
  Fecha:    2026-05-05
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  NOTA: Esta versión contiene REPLICAS LOCALES de las tablas externas necesarias
  para ejecutar el script en un entorno de pruebas donde no se tiene acceso
  a las bases de datos QUAC o PRUEBASBD.
  
  TABLAS EXTERNAS REPLICADAS LOCALMENTE:
  - dbo.terceros      (solo columnas necesarias para FK)
  - dbo.bodegas      (solo columnas necesarias para FK)
  - dbo.KCRM_CadenaCreditos (solo columnas necesarias para ALTER TABLE)

  NOTA: En v2.5+, BERP_FABRICASOperadores fue REEMPLAZADA por fab.OperadoresFabrica (GAP-19).
  Las FKs ahora referencian fab.OperadoresFabrica en lugar de dbo.BERP_FABRICASOperadores.
================================================================================
*/

-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 0: TABLAS EXTERNAS REPLICADAS LOCALMENTE (PARA ENTORNO DE PRUEBAS)
-- ==============================================================================
-- Estas son copias mínimas de las tablas de QUAC.dbo necesarias para el script.
-- En producción, estas tablas YA EXISTEN y no se deben crear.

-- ─────────────────────────────────────────────────────────────────────────────
-- 0.1 terceros (REPLICA local para pruebas)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.terceros') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[terceros] (
        nit VARCHAR(20) NOT NULL,
        nombres VARCHAR(60) NULL,
        direccion VARCHAR(200) NULL,
        telefono_1 VARCHAR(50) NULL,
        mail VARCHAR(100) NULL,
        celular VARCHAR(15) NULL,
        fecha_creacion DATETIME NULL,
        fecha_modificacion DATETIME NULL,
        
        CONSTRAINT PK_terceros PRIMARY KEY (nit)
    );

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 0.2 bodegas (REPLICA local para pruebas)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.bodegas') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[bodegas] (
        id INT IDENTITY(1,1) NOT NULL,
        bodega DECIMAL(18,0) NULL,
        descripcion VARCHAR(40) NOT NULL,
        direccion VARCHAR(80) NULL,
        telefono VARCHAR(40) NULL,
        centro INT DEFAULT 0 NOT NULL,
        TipoTienda VARCHAR(50) NULL,
        Nit_Comercio VARCHAR(20) NULL,
        ciudad VARCHAR(5) NULL,
        departamento VARCHAR(5) NULL,
        pais VARCHAR(5) NULL,
        
        CONSTRAINT PK_bodegas PRIMARY KEY (id)
    );

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 0.3 KCRM_CadenaCreditos (REPLICA local para pruebas)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[KCRM_CadenaCreditos] (
        IdCadena INT IDENTITY(1,1) NOT NULL,
        Nit VARCHAR(20) NOT NULL,
        FechaIngreso DATETIME DEFAULT GETDATE() NOT NULL,
        Aprobado BIT DEFAULT 0 NOT NULL,
        Bodega INT NULL,
        CupoAprobado MONEY NULL,
        Activa BIT DEFAULT 0 NOT NULL,
        
        -- Columnas añadidas por FÁBRICAS v2.1
        EstadoActualFabricas VARCHAR(20) NULL,
        MotivoBloqueoFabricas VARCHAR(50) NULL,
        FechaCancelacionFabricas DATETIME2 NULL,
        ElegibleReactivacion BIT NOT NULL DEFAULT 0,
        
        CONSTRAINT PK_KCRM_CadenaCreditos PRIMARY KEY (IdCadena)
    );

END


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- CREACIÓN DE ESQUEMAS LÓGICOS
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'cfg') EXEC('CREATE SCHEMA cfg');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'cat') EXEC('CREATE SCHEMA cat');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fab') EXEC('CREATE SCHEMA fab');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'aud') EXEC('CREATE SCHEMA aud');


-- ==============================================================================
-- SECCIÓN 1: TABLAS DE CONFIGURACIÓN (MAQUINA DE ESTADOS)
-- ==============================================================================

-- 1.1 FasesEstudio
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.FasesEstudio') AND type in (N'U'))
BEGIN
    CREATE TABLE [cfg].[FasesEstudio] (
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

END


-- 1.2 PasosEstudio
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.PasosEstudio') AND type in (N'U'))
BEGIN
    CREATE TABLE [cfg].[PasosEstudio] (
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
        CONSTRAINT FK_PasosEstudio_Fase FOREIGN KEY (IdFase) REFERENCES [cfg].[FasesEstudio](IdFase),
        CONSTRAINT CK_PasosEstudio_Actor CHECK (Actor IN ('ASESOR','SISTEMA','CLIENTE','CALL_CENTER'))
    );
    
    CREATE INDEX IX_PasosEstudio_Fase ON [cfg].[PasosEstudio](IdFase);

END


-- 1.3 CatalogoEstados
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.CatalogoEstados') AND type in (N'U'))
BEGIN
    CREATE TABLE [cfg].[CatalogoEstados] (
        IdEstado            INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(40)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Grupo               VARCHAR(20)         NOT NULL,
        EsTerminal          BIT                 NOT NULL DEFAULT 0,
        PermitePausa        BIT                 NOT NULL DEFAULT 0,
        Descripcion         NVARCHAR(500)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_CatalogoEstados PRIMARY KEY (IdEstado),
        CONSTRAINT UQ_CatalogoEstados_codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoEstados_Grupo CHECK (Grupo IN ('INICIAL','PROCESO','TERMINAL','BLOQUEO','REACTIVACION'))
    );

END


-- 1.4 TransicionesEstado
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.TransicionesEstado') AND type in (N'U'))
BEGIN
    CREATE TABLE [cfg].[TransicionesEstado] (
        IdTransicion        INT IDENTITY(1,1)   NOT NULL,
        IdEstadoOrigen      INT                 NOT NULL,
        IdEstadoDestino     INT                 NOT NULL,
        RequiereMotivo      BIT                 NOT NULL DEFAULT 0,
        Descripcion         NVARCHAR(200)       NULL,
        Activa              BIT                 NOT NULL DEFAULT 1,
        
        CONSTRAINT PK_TransicionesEstado PRIMARY KEY (IdTransicion),
        CONSTRAINT FK_Transiciones_Origen FOREIGN KEY (IdEstadoOrigen) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_Transiciones_Destino FOREIGN KEY (IdEstadoDestino) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT UQ_Transiciones_OrigenDestino UNIQUE (IdEstadoOrigen, IdEstadoDestino)
    );

END


-- 1.5 ConfiguracionReglasNegocio
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.ConfiguracionReglasNegocio') AND type in (N'U'))
BEGIN
    CREATE TABLE [cfg].[ConfiguracionReglasNegocio] (
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
        CONSTRAINT CK_ConfigReglas_TipoDato CHECK (TipoDato IN ('INT','DECIMAL','BOOL','TEXT','JSON')),
        CONSTRAINT CK_ConfiguracionReglasNegocio_Categoria CHECK (
            Categoria IN ('ENFRIAMIENTO','GENERAL','OTP','BIOMETRIA','RIESGO','FOTOS','AUTH')
        )
    );

END


-- 1.6 CatalogoCanalesOrigen
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoCanalesOrigen') AND type in (N'U'))
BEGIN
    CREATE TABLE [cat].[CatalogoCanalesOrigen] (
        IdCanal             INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(20)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Descripcion         NVARCHAR(300)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_CatalogoCanalesOrigen PRIMARY KEY (IdCanal),
        CONSTRAINT UQ_CatalogoCanalesOrigen_Codigo UNIQUE (Codigo)
    );

END


-- ==============================================================================
-- SECCIÓN 2: MODIFICACIÓN DE TABLAS EXISTENTES (ALTER TABLE)
-- ==============================================================================
-- En esta versión PRUEBAS, las tablas ya existen localmente (Sección 0)
-- así que los ALTER TABLE funcionan directamente.

-- 2.1 Nueva Tabla: TercerosFabricas (CON FK LOCAL)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.TercerosFabricas') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[TercerosFabricas] (
        IdTerceroFabricas       INT IDENTITY(1,1) NOT NULL,
        NitTercero              VARCHAR(20) NOT NULL,
        NombreTercero           NVARCHAR(200) NULL,
        EstadoTercero           VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
        TieneCupoActivo        BIT NOT NULL DEFAULT 0,
        EstaBloqueadoFabricas  BIT NOT NULL DEFAULT 0,
        MotivoBloqueo          VARCHAR(100) NULL,
        FechaBloqueo           DATETIME2(3) NULL,
        FechaDesbloqueo        DATETIME2(3) NULL,
        TieneRegistroBiometrico BIT NOT NULL DEFAULT 0,
        FechaRegistroBiometrico DATETIME2(3) NULL,
        PuntajeCredito         DECIMAL(5,2) NULL,
        FechaUltimaEvaluacion  DATETIME2(3) NULL,
        CelularPrincipal       VARCHAR(20) NULL,
        CelularWhatsApp        VARCHAR(20) NULL,
        FechaCreacion          DATETIME2(3) NOT NULL DEFAULT GETDATE(),
        FechaModificacion      DATETIME2(3) NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_TercerosFabricas PRIMARY KEY CLUSTERED (IdTerceroFabricas),
        CONSTRAINT UQ_TercerosFabricas_Nit UNIQUE (NitTercero),
        -- FK local a terceros (en lugar de QUAC.dbo.terceros)
        CONSTRAINT FK_TercerosFabricas_Terceros FOREIGN KEY (NitTercero)
            REFERENCES dbo.terceros (nit) ON UPDATE NO ACTION ON DELETE NO ACTION
    );
    
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Nit ON [fab].[TercerosFabricas] (NitTercero);
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Estado ON [fab].[TercerosFabricas] (EstadoTercero, EstaBloqueadoFabricas);
    

END


-- 2.2 Modificar dbo.KCRM_CadenaCreditos (ya existe localmente)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'EstadoActualFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD EstadoActualFabricas VARCHAR(20) NULL;

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD MotivoBloqueoFabricas VARCHAR(50) NULL;

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD FechaCancelacionFabricas DATETIME2 NULL;

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD ElegibleReactivacion BIT NOT NULL DEFAULT 0;

END


-- ==============================================================================
-- SECCIÓN 3: TABLAS TRANSACCIONALES
-- ==============================================================================

-- 3.1 EstudiosCredito (CON FKs LOCALES)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EstudiosCredito') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EstudiosCredito] (
        IdEstudio               BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Referencia al cliente (terceros)
        NitTercero              VARCHAR(20)         NOT NULL,
        NitComercio             VARCHAR(20)         NOT NULL,
        CelularCliente          VARCHAR(20)         NULL,
        
        -- Referencias a entidades existentes (CON FK LOCALES)
        IdBodega               INT                 NULL,       -- FK a dbo.bodegas.id
        IdAsesor               INT                 NULL,       -- FK a fab.OperadoresFabrica.IdOperador (GAP-19)
        NitAsesor              VARCHAR(20)         NULL,       -- CC inmutable del asesor (GAP-19)
        IdCanal                INT                 NULL,       -- FK a CatalogoCanalesOrigen
        
        -- Estado de la máquina de estados
        IdEstadoActual          INT                 NOT NULL,
        IdPasoActual            INT                 NULL,
        
        -- Resultado del estudio
        MotivoRechazo           NVARCHAR(200)       NULL,
        CupoPreaprobado        DECIMAL(18,2)      NULL,
        
        -- Banderas de proceso
        EsPreaprobado          BIT                 NOT NULL DEFAULT 0,
        EsReactivacion         BIT                 NOT NULL DEFAULT 0,
        RenunciaCupo           BIT                 NOT NULL DEFAULT 0,
        RequiereCallCenter     BIT                 NOT NULL DEFAULT 0,
        
        -- Tipo de cierre y cupo express
        EsCupoExpress          BIT                 NOT NULL DEFAULT 0,
        TipoCierre             VARCHAR(20)         NULL,
        
        -- Datos de contacto
        EmailCliente           NVARCHAR(200)       NULL,
        EmailUbica             NVARCHAR(200)       NULL,
        
        -- Punto de reanudación del flujo web
        SlugPasoWeb            VARCHAR(50)         NULL,
        FechaUltimoAbandono    DATETIME2(3)        NULL,
        
        -- Dirección capturada
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
        FechaActualizacion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        -- Control de concurrencia
        EliminadoLogico        BIT                 NOT NULL DEFAULT 0,
        IdCorrelacion          VARCHAR(64)         NULL,
        IdEscalamientoActivo   BIGINT              NULL,
        
        -- Fotografías
        FotografiasAprobadas   INT                 NOT NULL DEFAULT 0,
        EstadoRevisionFotos    VARCHAR(15)         NOT NULL DEFAULT 'PENDIENTE',
        
        -- Validación biométrica del asesor
        IdValidacionAsesor     BIGINT              NULL,
        
        CONSTRAINT PK_EstudiosCredito PRIMARY KEY (IdEstudio),
        CONSTRAINT FK_EstudiosCredito_Estado FOREIGN KEY (IdEstadoActual) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_EstudiosCredito_Paso FOREIGN KEY (IdPasoActual) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT FK_EstudiosCredito_Canal FOREIGN KEY (IdCanal) REFERENCES [cat].[CatalogoCanalesOrigen](IdCanal),
        CONSTRAINT FK_EstudiosCredito_Tercero FOREIGN KEY (NitTercero) REFERENCES [fab].[TercerosFabricas](NitTercero),
        -- FK local a bodegas (en lugar de QUAC.dbo.bodegas)
        CONSTRAINT FK_EstudiosCredito_Bodega FOREIGN KEY (IdBodega) REFERENCES dbo.bodegas(id),
        CONSTRAINT CK_EstudiosCredito_TipoCierre CHECK (TipoCierre IS NULL OR TipoCierre IN ('EXPRESS','NORMAL','FABRICA')),
        CONSTRAINT CK_EstudiosCredito_EstadoRevisionFotos CHECK (EstadoRevisionFotos IN ('PENDIENTE','EN_REVISION','APROBADO','CON_RECHAZOS'))
    );
    
    CREATE INDEX IX_EstudiosCredito_Cliente ON [fab].[EstudiosCredito](NitTercero);
    CREATE INDEX IX_EstudiosCredito_NitComercio ON [fab].[EstudiosCredito](NitComercio);
    CREATE INDEX IX_EstudiosCredito_Estado ON [fab].[EstudiosCredito](IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_Asesor ON [fab].[EstudiosCredito](IdAsesor) WHERE IdAsesor IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Bodega ON [fab].[EstudiosCredito](IdBodega) WHERE IdBodega IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Canal ON [fab].[EstudiosCredito](IdCanal) WHERE IdCanal IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_FechaInicio ON [fab].[EstudiosCredito](FechaInicio);
    CREATE INDEX IX_EstudiosCredito_ClienteFecha ON [fab].[EstudiosCredito](NitTercero, FechaInicio) INCLUDE (IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_CallCenter ON [fab].[EstudiosCredito](RequiereCallCenter, IdEstadoActual) WHERE RequiereCallCenter = 1;
    CREATE INDEX IX_EstudiosCredito_SlugWeb ON [fab].[EstudiosCredito](SlugPasoWeb) WHERE SlugPasoWeb IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Correlacion ON [fab].[EstudiosCredito](IdCorrelacion) WHERE IdCorrelacion IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_RevisionFotos ON [fab].[EstudiosCredito](EstadoRevisionFotos, IdEstadoActual)
        WHERE EstadoRevisionFotos IN ('EN_REVISION','CON_RECHAZOS');
    CREATE INDEX IX_EstudiosCredito_ValidacionAsesor ON [fab].[EstudiosCredito](IdValidacionAsesor)
        WHERE IdValidacionAsesor IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_EscalamientoActivo ON [fab].[EstudiosCredito](IdEscalamientoActivo)
        WHERE IdEscalamientoActivo IS NOT NULL;
    

END


-- 3.2 RetosSeguridad
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.RetosSeguridad') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[RetosSeguridad] (
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
        NumeroReenvios      INT                 NOT NULL DEFAULT 0,
        UltimoReenvio       DATETIME2(3)        NULL,
        DireccionEnvio      NVARCHAR(200)       NULL,
        
        CONSTRAINT PK_RetosSeguridad PRIMARY KEY (IdReto),
        CONSTRAINT FK_RetosSeguridad_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_RetosSeguridad_Canal CHECK (CanalEnvio IN ('WHATSAPP','EMAIL','SMS'))
    );
    
    CREATE INDEX IX_RetosSeguridad_ClienteFecha ON [fab].[RetosSeguridad](NitTercero, FechaEnvio);
    CREATE INDEX IX_RetosSeguridad_Estudio ON [fab].[RetosSeguridad](IdEstudio);
    

END


-- 3.3 EvaluacionesRiesgo
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EvaluacionesRiesgo] (
        IdEvaluacion                BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                  BIGINT              NOT NULL,
        IdPaso                     INT                 NULL,
        TipoEvaluacion             VARCHAR(30)         NOT NULL,
        CoincidenciaListasRestrictivas BIT            NOT NULL DEFAULT 0,
        ScoreBuro                  INT                 NULL,
        MoraComerciosAliados       BIT                 NULL,
        ViablePreselecta           BIT                 NULL,
        EsPensionado               BIT                 NULL,
        TieneSeguridadSocial       BIT                 NULL,
        Resultado                  VARCHAR(20)         NOT NULL,
        MotivoResultado            NVARCHAR(200)       NULL,
        DetallesJSON               NVARCHAR(MAX)       NULL,
        FechaEvaluacion            DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_EvaluacionesRiesgo PRIMARY KEY (IdEvaluacion),
        CONSTRAINT FK_EvaluacionesRiesgo_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_EvaluacionesRiesgo_Paso FOREIGN KEY (IdPaso) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (TipoEvaluacion IN ('LISTAS','BURO','PRESELECTA','FOSYGA','ANTECEDENTES','UBICA')),
        CONSTRAINT CK_EvaluacionesRiesgo_Resultado CHECK (Resultado IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR'))
    );
    
    CREATE INDEX IX_EvaluacionesRiesgo_Estudio ON [fab].[EvaluacionesRiesgo](IdEstudio);
    CREATE INDEX IX_EvaluacionesRiesgo_Tipo ON [fab].[EvaluacionesRiesgo](TipoEvaluacion, Resultado);
    

END


-- 3.4 RegistrosBiometria
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.RegistrosBiometria') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[RegistrosBiometria] (
        IdBiometria             BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio               BIGINT              NOT NULL,
        IdTransaccionProveedor  VARCHAR(100)        NULL,
        TipoVerificacion        VARCHAR(20)         NOT NULL,
        PruebaVidaAprobada      BIT                 NOT NULL DEFAULT 0,
        PorcentajeCoincidencia DECIMAL(5,2)        NULL,
        EstadoOCR               VARCHAR(20)         NULL,
        NumeroIntentos          INT                 NOT NULL DEFAULT 1,
        EstadoProceso           VARCHAR(20)         NOT NULL,
        NombreExtraidoOCR           NVARCHAR(200)   NULL,
        FechaExpedicionExtraidaOCR  DATE            NULL,
        NumeroDocumentoExtraidoOCR  VARCHAR(20)     NULL,
        CoincidenciaOCR             BIT             NULL,
        FechaRegistro           DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        IdFotografiaFrontal     BIGINT              NULL,
        IdFotografiaReverso     BIGINT              NULL,
        IdFotografiaSelfie      BIGINT              NULL,
        
        CONSTRAINT PK_RegistrosBiometria PRIMARY KEY (IdBiometria),
        CONSTRAINT FK_RegistrosBiometria_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_RegistrosBiometria_Tipo CHECK (TipoVerificacion IN ('ONBOARDING','AUTENTICACION','PRUEBA_VIDA_HANDOFF')),
        CONSTRAINT CK_RegistrosBiometria_Estado CHECK (EstadoProceso IN ('EXITOSO','FALLIDO','REVISION_MANUAL'))
    );
    
    CREATE INDEX IX_RegistrosBiometria_Estudio ON [fab].[RegistrosBiometria](IdEstudio);
    CREATE INDEX IX_RegistrosBiometria_FotoFrontal ON [fab].[RegistrosBiometria](IdFotografiaFrontal)
        WHERE IdFotografiaFrontal IS NOT NULL;
    CREATE INDEX IX_RegistrosBiometria_FotoReverso ON [fab].[RegistrosBiometria](IdFotografiaReverso)
        WHERE IdFotografiaReverso IS NOT NULL;
    CREATE INDEX IX_RegistrosBiometria_FotoSelfie ON [fab].[RegistrosBiometria](IdFotografiaSelfie)
        WHERE IdFotografiaSelfie IS NOT NULL;
    

END


-- 3.5 ValidacionesContactabilidad
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ValidacionesContactabilidad') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[ValidacionesContactabilidad] (
        IdValidacion              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                 BIGINT              NOT NULL,
        ScoreUbica                VARCHAR(30)         NULL,
        EsActivacionAutomatica    BIT                 NOT NULL DEFAULT 0,
        EstadoUbica               VARCHAR(30)         NULL,
        EstadoVerificacionManual  VARCHAR(20)         NULL,
        IdAsesor                 INT                 NULL,
        NitAsesor                VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del asesor en el momento de la verificación
        ComentariosAgente         NVARCHAR(500)       NULL,
        IdAlertaFraude            BIGINT              NULL,
        FechaVerificacion         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ValidacionesContactabilidad PRIMARY KEY (IdValidacion),
        CONSTRAINT FK_ValidContact_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_ValidContact_EstadoManual CHECK (
            EstadoVerificacionManual IS NULL OR 
            EstadoVerificacionManual IN ('PENDIENTE','CONFIRMADO','RECHAZADO')
        ),
        CONSTRAINT CK_ValidContact_EstadoUbica CHECK (
            EstadoUbica IS NULL OR
            EstadoUbica IN ('OK_CEL_CORREO','OK_CEL','GESTION_MANUAL_CALL','GESTION_MANUAL_FABRICA','NO_CONTACTABLE','PENDIENTE')
        )
    );
    
    CREATE INDEX IX_ValidContact_Estudio ON [fab].[ValidacionesContactabilidad](IdEstudio);
    CREATE INDEX IX_ValidContact_Pendientes ON [fab].[ValidacionesContactabilidad](EstadoVerificacionManual) 
        WHERE EstadoVerificacionManual = 'PENDIENTE';
    CREATE INDEX IX_ValidContact_EstadoUbica ON [fab].[ValidacionesContactabilidad](EstadoUbica)
        WHERE EstadoUbica IS NOT NULL;
    CREATE INDEX IX_ValidContact_AlertaFraude ON [fab].[ValidacionesContactabilidad](IdAlertaFraude)
        WHERE IdAlertaFraude IS NOT NULL;
    

END


-- 3.6 ConsentimientosLegales
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ConsentimientosLegales') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[ConsentimientosLegales] (
        IdConsentimiento      BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio            BIGINT              NOT NULL,
        NitTercero           VARCHAR(20)         NOT NULL,
        TipoConsentimiento   VARCHAR(40)         NOT NULL,
        VersionDocumento    VARCHAR(20)         NULL,
        Aceptado             BIT                 NOT NULL DEFAULT 0,
        DireccionIP          VARCHAR(45)         NULL,
        UserAgent            NVARCHAR(500)       NULL,
        TipoFirma            VARCHAR(20)         NOT NULL DEFAULT 'CHECKBOX',
        FechaAceptacion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ConsentimientosLegales PRIMARY KEY (IdConsentimiento),
        CONSTRAINT FK_Consentimientos_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_Consentimientos_TipoFirma CHECK (
            TipoFirma IN ('OTP_SMS','OTP_EMAIL','OTP_WHATSAPP','CHECKBOX','FIRMA_DIGITAL')
        )
    );
    
    CREATE INDEX IX_Consentimientos_Estudio ON [fab].[ConsentimientosLegales](IdEstudio);
    CREATE INDEX IX_Consentimientos_Cliente ON [fab].[ConsentimientosLegales](NitTercero);
    

END


-- 3.7 EvidenciasFabrica
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EvidenciasFabrica') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EvidenciasFabrica] (
        IdEvidencia         BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudioCredito    BIGINT                  NOT NULL,
        TipoEvidencia       VARCHAR(30)             NOT NULL,
        UrlArchivo          NVARCHAR(500)           NOT NULL,
        NombreArchivo       NVARCHAR(200)           NOT NULL,
        ContentType         VARCHAR(100)            NULL,
        TamanoBytes         BIGINT                  NULL,
        SubidoPor           NVARCHAR(100)           NOT NULL,
        NitSubidoPor        VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del usuario que subió la evidencia
        Observaciones       NVARCHAR(500)           NULL,
        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_EvidenciasFabrica PRIMARY KEY (IdEvidencia),
        CONSTRAINT FK_EvidenciasFabrica_Estudio FOREIGN KEY (IdEstudioCredito) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_EvidenciasFabrica_Tipo CHECK (
            TipoEvidencia IN ('COMPROBANTE','NOTA_ASESOR','DOCUMENTO_SOPORTE','OTRO')
        )
    );
    
    CREATE INDEX IX_EvidenciasFabrica_Estudio ON [fab].[EvidenciasFabrica](IdEstudioCredito);
    CREATE INDEX IX_EvidenciasFabrica_EstudioTipo ON [fab].[EvidenciasFabrica](IdEstudioCredito, TipoEvidencia);
    CREATE INDEX IX_EvidenciasFabrica_SubidoPor ON [fab].[EvidenciasFabrica](SubidoPor, FechaCreacion);
    

END


-- ==============================================================================
-- SECCIÓN 4: TABLAS DE AUDITORÍA
-- ==============================================================================

-- 4.1 HistorialEstados
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.HistorialEstados') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[HistorialEstados] (
        IdHistorial         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        IdEstadoAnterior    INT                 NULL,
        IdEstadoNuevo       INT                 NOT NULL,
        IdPasoRelacionado   INT                 NULL,
        IdUsuarioAccion     INT                 NULL,
        NitAsesor           VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del operador que realizó la transición
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        MotivoTransicion    NVARCHAR(500)       NULL,
        IdCorrelacion       VARCHAR(64)         NULL,
        FechaTransicion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_HistorialEstados PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_Hist_Request FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_Hist_EstAnterior FOREIGN KEY (IdEstadoAnterior) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_Hist_EstNuevo FOREIGN KEY (IdEstadoNuevo) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_Hist_Paso FOREIGN KEY (IdPasoRelacionado) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT CK_HistorialEstados_TipoUsr CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CALL_CENTER','CLIENTE','ADMINISTRADOR'))
    );
    
    CREATE INDEX IX_HistorialEstados_Estudio ON [aud].[HistorialEstados](IdEstudio, FechaTransicion);
    CREATE INDEX IX_HistorialEstados_EstadoFecha ON [aud].[HistorialEstados](IdEstadoNuevo, FechaTransicion);
    

END


-- 4.2 AuditoriaCambiosDatos
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.AuditoriaCambiosDatos') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[AuditoriaCambiosDatos] (
        IdAuditoria         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        NombreTabla         VARCHAR(50)         NOT NULL,
        NombreCampo         VARCHAR(50)         NOT NULL,
        ValorAnterior       NVARCHAR(500)       NULL,
        ValorNuevo          NVARCHAR(500)       NULL,
        IdUsuarioAccion     INT                 NULL,
        NitAsesor           VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del operador que realizó el cambio
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        FechaCambio         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_AuditoriaCambiosDatos PRIMARY KEY (IdAuditoria),
        CONSTRAINT FK_Audit_Request FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_AuditoriaCambiosDatos_TipoUsuario CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CLIENTE','ADMINISTRADOR'))
    );
    
    CREATE INDEX IX_AuditoriaCambiosDatos_Cliente ON [aud].[AuditoriaCambiosDatos](NitTercero, FechaCambio);
    CREATE INDEX IX_AuditoriaCambiosDatos_Estudio ON [aud].[AuditoriaCambiosDatos](IdEstudio) WHERE IdEstudio IS NOT NULL;
    

END


-- 4.3 RegistroServiciosExternos
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.RegistroServiciosExternos') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[RegistroServiciosExternos] (
        IdRegistro              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio               BIGINT              NOT NULL,
        IdPaso                  INT                 NULL,
        NombreServicio          VARCHAR(50)         NOT NULL,
        URLEndpoint             NVARCHAR(500)       NULL,
        MetodoHTTP              VARCHAR(10)        NULL,
        PayloadRequest          NVARCHAR(MAX)       NULL,
        PayloadResponse         NVARCHAR(MAX)       NULL,
        CodigoHTTPRespuesta     INT                 NULL,
        ResultadoInterpretado   VARCHAR(20)         NOT NULL,
        MensajeError            NVARCHAR(500)       NULL,
        DuracionMs              INT                 NULL,
        FechaInvocacion         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaRespuesta          DATETIME2(3)        NULL,
        
        CONSTRAINT PK_RegistroServiciosExternos PRIMARY KEY (IdRegistro),
        CONSTRAINT FK_RegServ_Request FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_RegServ_Paso FOREIGN KEY (IdPaso) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT CK_RegServExt_Resultado CHECK (ResultadoInterpretado IN ('EXITOSO','FALLIDO','TIMEOUT','ERROR'))
    );
    
    CREATE INDEX IX_RegServExt_Estudio ON [aud].[RegistroServiciosExternos](IdEstudio, FechaInvocacion);
    CREATE INDEX IX_RegServExt_Servicio ON [aud].[RegistroServiciosExternos](NombreServicio, ResultadoInterpretado, FechaInvocacion);
    CREATE INDEX IX_RegServExt_Duracion ON [aud].[RegistroServiciosExternos](NombreServicio, DuracionMs) WHERE DuracionMs IS NOT NULL;
    

END


-- ==============================================================================
-- SECCIÓN 5: PARCHES V2.2 — Architect Audit
-- ==============================================================================

-- 5.1 CatalogoReglasFraude
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoReglasFraude') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoReglasFraude] (
        IdReglaFraude       INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(50)         NOT NULL,
        Nombre              NVARCHAR(150)       NOT NULL,
        Descripcion         NVARCHAR(500)       NULL,
        NivelRiesgo         VARCHAR(10)         NOT NULL DEFAULT 'MEDIO',
        AccionAutomatica    VARCHAR(30)         NOT NULL DEFAULT 'ESCALAR',
        Activa              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoReglasFraude PRIMARY KEY (IdReglaFraude),
        CONSTRAINT UQ_CatalogoReglasFraude_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoReglasFraude_Nivel CHECK (NivelRiesgo IN ('BAJO','MEDIO','ALTO','CRITICO')),
        CONSTRAINT CK_CatalogoReglasFraude_Accion CHECK (AccionAutomatica IN ('ESCALAR','BLOQUEAR','NOTIFICAR','SOLO_REGISTRO'))
    );

END


-- 5.2 CatalogoMotivosEscalamiento
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoMotivosEscalamiento') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoMotivosEscalamiento] (
        IdMotivo            INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(50)         NOT NULL,
        Nombre              NVARCHAR(150)       NOT NULL,
        Descripcion         NVARCHAR(500)       NULL,
        Origen              VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoMotivosEscalamiento PRIMARY KEY (IdMotivo),
        CONSTRAINT UQ_CatalogoMotivosEscalamiento_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoMotivos_Origen CHECK (Origen IN ('SISTEMA','ASESOR','FRAUDE'))
    );

END


-- 5.3 AlertasFraude
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.AlertasFraude') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[AlertasFraude] (
        IdAlerta            BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        IdReglaFraude       INT                 NOT NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        PasoEnQueOcurrio    VARCHAR(40)         NULL,
        ValorAnterior       NVARCHAR(300)       NULL,
        ValorNuevo          NVARCHAR(300)       NULL,
        CampoAfectado       VARCHAR(50)         NULL,
        ContextoJSON        NVARCHAR(MAX)       NULL,
        AccionTomada        VARCHAR(20)         NOT NULL DEFAULT 'PENDIENTE',  -- PENDIENTE, ESCALADO, BLOQUEADO, DESCARTADO
        IdAsesor            INT                 NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador
        NitAsesor           VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del operador que resolvió la alerta
        NotasResolucion     NVARCHAR(500)       NULL,
        FechaResolucion     DATETIME2(3)        NULL,
        FechaAlerta         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_AlertasFraude PRIMARY KEY (IdAlerta),
        CONSTRAINT FK_AlertasFraude_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_AlertasFraude_Regla FOREIGN KEY (IdReglaFraude) REFERENCES [cat].[CatalogoReglasFraude](IdReglaFraude),
        CONSTRAINT CK_AlertasFraude_Accion CHECK (AccionTomada IN ('PENDIENTE','ESCALADO','BLOQUEADO','DESCARTADO'))
    );

    CREATE INDEX IX_AlertasFraude_Estudio ON [aud].[AlertasFraude](IdEstudio, FechaAlerta);
    CREATE INDEX IX_AlertasFraude_Cliente ON [aud].[AlertasFraude](NitTercero, FechaAlerta);
    CREATE INDEX IX_AlertasFraude_Pendientes ON [aud].[AlertasFraude](AccionTomada, IdReglaFraude)
        WHERE AccionTomada = 'PENDIENTE';
    CREATE INDEX IX_AlertasFraude_Regla ON [aud].[AlertasFraude](IdReglaFraude, FechaAlerta);


END


-- 5.4 EscalamientosFabrica
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EscalamientosFabrica') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[EscalamientosFabrica] (
        IdEscalamiento          BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio               BIGINT                  NOT NULL,
        IdMotivoEscalamiento    INT                     NOT NULL,
        IdAlertaOrigen          BIGINT                  NULL,
        DescripcionContexto     NVARCHAR(1000)          NULL,
        PasoEnQueEscalo         VARCHAR(40)             NULL,
        IdEstadoAlEscalar       INT                     NOT NULL,
        SnapshotDatosCliente    NVARCHAR(MAX)           NULL,
        EscaladoPorSistema      BIT                     NOT NULL DEFAULT 1,  -- 1=automático, 0=manual por asesor
        IdAsesor                INT                     NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador (si fue manual)
        NitAsesor               VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del operador que escaló
        
        -- Resolución
        IdAsesorAsignado        INT                     NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador
        NitAsesorAsignado       VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del asesor asignado
        FechaAsignacion         DATETIME2(3)            NULL,
        EstadoEscalamiento      VARCHAR(20)             NOT NULL DEFAULT 'ABIERTO',
        ResultadoGestion        VARCHAR(20)             NULL,
        NotasAsesor             NVARCHAR(1000)          NULL,
        FechaResolucion         DATETIME2(3)            NULL,
        FechaCreacion           DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion      DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_EscalamientosFabrica PRIMARY KEY (IdEscalamiento),
        CONSTRAINT FK_EscalamientosFabrica_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_EscalamientosFabrica_Motivo FOREIGN KEY (IdMotivoEscalamiento) REFERENCES [cat].[CatalogoMotivosEscalamiento](IdMotivo),
        CONSTRAINT FK_EscalamientosFabrica_Alerta FOREIGN KEY (IdAlertaOrigen) REFERENCES [aud].[AlertasFraude](IdAlerta),
        CONSTRAINT FK_EscalamientosFabrica_EstadoAlEscalar FOREIGN KEY (IdEstadoAlEscalar) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT CK_EscalamientosFabrica_Estado CHECK (EstadoEscalamiento IN ('ABIERTO','EN_GESTION','RESUELTO','CERRADO_SIN_RESOLUCION')),
        CONSTRAINT CK_EscalamientosFabrica_Resultado CHECK (ResultadoGestion IS NULL OR ResultadoGestion IN ('APROBADO','RECHAZADO','DEVUELTO_FLUJO'))
    );

    CREATE INDEX IX_Escalamientos_Estudio ON [fab].[EscalamientosFabrica](IdEstudio, FechaCreacion);
    CREATE INDEX IX_Escalamientos_AbiertosAsesor ON [fab].[EscalamientosFabrica](IdAsesorAsignado, EstadoEscalamiento)
        WHERE EstadoEscalamiento IN ('ABIERTO','EN_GESTION');
    CREATE INDEX IX_Escalamientos_Motivo ON [fab].[EscalamientosFabrica](IdMotivoEscalamiento, FechaCreacion);
    CREATE INDEX IX_Escalamientos_Alerta ON [fab].[EscalamientosFabrica](IdAlertaOrigen)
        WHERE IdAlertaOrigen IS NOT NULL;


END


-- 5.5 LogValidacionesOTP
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.LogValidacionesOTP') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[LogValidacionesOTP] (
        IdLogOTP            BIGINT IDENTITY(1,1) NOT NULL,
        IdReto              BIGINT              NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        NumeroIntento       INT                 NOT NULL,
        DireccionEnvio      NVARCHAR(200)       NULL,
        ResultadoIntento    VARCHAR(20)         NOT NULL,
        CodigoEntradoHash   VARCHAR(256)        NULL,
        DireccionIP         VARCHAR(45)         NULL,
        UserAgent           NVARCHAR(500)       NULL,
        FechaIntento        DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_LogValidacionesOTP PRIMARY KEY (IdLogOTP),
        CONSTRAINT FK_LogOTP_Reto FOREIGN KEY (IdReto) REFERENCES [fab].[RetosSeguridad](IdReto),
        CONSTRAINT FK_LogOTP_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_LogOTP_Resultado CHECK (ResultadoIntento IN ('EXITOSO','FALLIDO_HASH','EXPIRADO','CANCELADO'))
    );

    CREATE INDEX IX_LogOTP_Reto ON [aud].[LogValidacionesOTP](IdReto, NumeroIntento);
    CREATE INDEX IX_LogOTP_Estudio ON [aud].[LogValidacionesOTP](IdEstudio, FechaIntento);
    CREATE INDEX IX_LogOTP_Cliente ON [aud].[LogValidacionesOTP](NitTercero, FechaIntento);


END


-- 5.6 HistorialDatosSensibles
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.HistorialDatosSensibles') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[HistorialDatosSensibles] (
        IdHistorialDato     BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        NitTercero          VARCHAR(20)         NOT NULL,
        CampoCambiado       VARCHAR(50)         NOT NULL,
        ValorOriginal       NVARCHAR(300)       NULL,
        ValorNuevo          NVARCHAR(300)       NULL,
        IdRetoActivoAlCambio BIGINT             NULL,
        EsPostFalloOTP      BIT                 NOT NULL DEFAULT 0,
        TipoActor           VARCHAR(20)         NOT NULL DEFAULT 'CLIENTE',
        DireccionIP         VARCHAR(45)         NULL,
        UserAgent           NVARCHAR(500)       NULL,
        MotivoDeclarado     NVARCHAR(300)       NULL,
        FechaCambio         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_HistorialDatosSensibles PRIMARY KEY (IdHistorialDato),
        CONSTRAINT FK_HistDatosSensibles_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_HistDatosSensibles_Reto FOREIGN KEY (IdRetoActivoAlCambio) REFERENCES [fab].[RetosSeguridad](IdReto),
        CONSTRAINT CK_HistDatosSensibles_Actor CHECK (TipoActor IN ('CLIENTE','ASESOR','SISTEMA'))
    );

    CREATE INDEX IX_HistDatosSensibles_Estudio ON [aud].[HistorialDatosSensibles](IdEstudio, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_Cliente ON [aud].[HistorialDatosSensibles](NitTercero, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_PostOTP ON [aud].[HistorialDatosSensibles](IdEstudio, EsPostFalloOTP)
        WHERE EsPostFalloOTP = 1;


END


-- 5.7 ValidacionesContactabilidad — FK IdAlertaFraude
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.ValidacionesContactabilidad')
      AND name = 'FK_ValidContact_AlertaFraude'
)
BEGIN
    ALTER TABLE [fab].[ValidacionesContactabilidad]
        ADD CONSTRAINT FK_ValidContact_AlertaFraude
        FOREIGN KEY (IdAlertaFraude) REFERENCES [aud].[AlertasFraude](IdAlerta);

END


-- ==============================================================================
-- SECCIÓN 6: PARCHES V2.4 — ValidacionesAsesor
-- ==============================================================================

-- ValidacionesAsesor (CON FKs LOCALES)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ValidacionesAsesor') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[ValidacionesAsesor] (
        IdValidacion            BIGINT IDENTITY(1,1)    NOT NULL,
        IdAsesor                INT                     NOT NULL,   -- FK → fab.OperadoresFabrica (GAP-19)
        CodigoAsesor            VARCHAR(20)             NOT NULL,
        IdBodega                INT                     NOT NULL,   -- FK → dbo.bodegas
        FechaValidacion         DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        PruebaVidaExitosa       BIT                     NOT NULL DEFAULT 0,
        PorcentajeCoincidencia  DECIMAL(5,2)            NULL,
        IdDispositivo           VARCHAR(100)            NULL,
        DireccionIP             VARCHAR(45)             NULL,
        ResultadoValidacion     VARCHAR(20)             NOT NULL,
        MensajeError            NVARCHAR(500)           NULL,
        FechaCreacion           DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_ValidacionesAsesor PRIMARY KEY (IdValidacion),
        CONSTRAINT CK_ValidacionesAsesor_Resultado CHECK (
            ResultadoValidacion IN ('EXITOSA', 'FALLIDA', 'ERROR_SERVICIO')
        ),
        -- NOTA: FK_ValidacionesAsesor_Asesor se agrega como ALTER TABLE en Sección 9,
        -- después de que fab.OperadoresFabrica es creada (igual que FK_EstudiosCredito_Asesor).
        -- FK local a la bodega (en lugar de QUAC.dbo.bodegas)
        CONSTRAINT FK_ValidacionesAsesor_Bodega
            FOREIGN KEY (IdBodega)
            REFERENCES dbo.bodegas (id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );

    CREATE INDEX IX_ValidacionesAsesor_Asesor
        ON [fab].[ValidacionesAsesor](IdAsesor, FechaValidacion DESC);
    CREATE INDEX IX_ValidacionesAsesor_Bodega
        ON [fab].[ValidacionesAsesor](IdBodega, FechaValidacion DESC);
    CREATE INDEX IX_ValidacionesAsesor_Codigo
        ON [fab].[ValidacionesAsesor](CodigoAsesor);
    CREATE INDEX IX_ValidacionesAsesor_Exitosas
        ON [fab].[ValidacionesAsesor](IdAsesor, FechaValidacion DESC)
        WHERE ResultadoValidacion = 'EXITOSA';


END


-- EstudiosCredito — FK IdValidacionAsesor
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.EstudiosCredito')
      AND name = 'FK_EstudiosCredito_ValidacionAsesor'
)
BEGIN
    ALTER TABLE [fab].[EstudiosCredito]
        ADD CONSTRAINT FK_EstudiosCredito_ValidacionAsesor
        FOREIGN KEY (IdValidacionAsesor) REFERENCES [fab].[ValidacionesAsesor](IdValidacion);

END


-- ==============================================================================
-- ==============================================================================
-- SECCIÓN 7: PARCHES V2.3 — GESTIÓN DE FOTOGRAFÍAS Y MÓDULO DE REVISIÓN
-- ==============================================================================
-- GAP-07: FotografiasEstudio REDISEÑADA como tabla unificada biométrica.
-- Diseño "Opción B": una tabla por foto con ciclo de vida completo, sin
-- separar tipos. Revisa el modelo en la sección de documentación de arquitectura.
--
-- TABLAS CREADAS:
--   PH-01: CatalogoTiposFotografia   — catálogo de los 3 tipos obligatorios
--   PH-02: FotografiasEstudio        — entidad de ciclo de vida de cada foto
--   PH-03: RevisionesFotografia      — decisiones de revisión (INSERT-ONLY)
--   PH-04: SolicitudesRecarga        — links enviados al cliente para re-carga
--   PH-05: HistorialFotografias      — auditoría inmutable de todos los cambios
-- ==============================================================================


-- 7.1  CatalogoTiposFotografia — los 3 tipos obligatorios y sus reglas
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoTiposFotografia') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoTiposFotografia] (
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

END


-- 7.2  FotografiasEstudio — tabla UNIFICADA de fotografías biométricas (GAP-07)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.FotografiasEstudio') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[FotografiasEstudio] (
        IdFotografia            BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio               BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        TipoFotografia          VARCHAR(30)             NOT NULL,   -- SELFIE, DOCUMENTO_FRONTAL, DOCUMENTO_TRASERO
        UrlArchivo              NVARCHAR(500)           NOT NULL,   -- URL/path al archivo almacenado (S3, Azure Blob, etc.)
        FechaCaptura            DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        -- Revisión y aprobación
        EstadoRevision          VARCHAR(20)             NOT NULL DEFAULT 'PENDIENTE',
                                                                    -- PENDIENTE, APROBADA_AUTO, APROBADA_ASESOR, RECHAZADA, REEMPLAZADA
        EsVigente               BIT                     NOT NULL DEFAULT 1,  -- 1 = foto activa/vigente para este tipo; 0 = reemplazada o rechazada

        -- Quién revisó
        MetodoRevision          VARCHAR(20)             NULL,       -- AUTOMATICO, MANUAL_ASESOR
        IdAsesorRevisor         INT                     NULL,       -- FK → fab.OperadoresFabrica (NULL si automático)
        FechaRevision           DATETIME2(3)            NULL,
        MotivoRechazo           NVARCHAR(500)           NULL,       -- Razón si EstadoRevision = 'RECHAZADA'

        -- Datos biométricos del servicio externo
        PorcentajeCoincidencia  DECIMAL(5,2)            NULL,       -- % coincidencia facial (selfie vs doc frontal)
        PruebaVidaExitosa       BIT                     NULL,       -- Resultado de prueba de vida (solo SELFIE)

        -- Auditoría
        FechaCreacion           DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        CreadoPor               VARCHAR(50)             NULL,       -- SISTEMA, ASESOR, CLIENTE

        CONSTRAINT PK_FotografiasEstudio PRIMARY KEY (IdFotografia),
        CONSTRAINT FK_FotografiasEstudio_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_FotografiasEstudio_Tipo CHECK (
            TipoFotografia IN ('SELFIE','DOCUMENTO_FRONTAL','DOCUMENTO_TRASERO')
        ),
        CONSTRAINT CK_FotografiasEstudio_Estado CHECK (
            EstadoRevision IN ('PENDIENTE','APROBADA_AUTO','APROBADA_ASESOR','RECHAZADA','REEMPLAZADA')
        ),
        CONSTRAINT CK_FotografiasEstudio_Metodo CHECK (
            MetodoRevision IS NULL OR MetodoRevision IN ('AUTOMATICO','MANUAL_ASESOR')
        )
    );

    -- Índice principal: fotos activas por estudio (módulo de revisión)
    CREATE INDEX IX_FotografiasEstudio_Estudio
        ON [fab].[FotografiasEstudio](IdEstudio, TipoFotografia, EsVigente);

    -- Cola de revisión pendiente
    CREATE INDEX IX_FotografiasEstudio_Revision
        ON [fab].[FotografiasEstudio](EstadoRevision)
        WHERE EstadoRevision = 'PENDIENTE';

    -- Garantiza UNA sola foto vigente por tipo por estudio
    CREATE UNIQUE INDEX UQ_FotografiasEstudio_Vigente
        ON [fab].[FotografiasEstudio](IdEstudio, TipoFotografia)
        WHERE EsVigente = 1;


END


-- 7.3  RevisionesFotografia — decisiones de revisión por fotografía (aud schema)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.RevisionesFotografia') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[RevisionesFotografia] (
        IdRevision          BIGINT IDENTITY(1,1)    NOT NULL,
        IdFotografia        BIGINT                  NOT NULL,   -- FK → FotografiasEstudio
        IdEstudio           BIGINT                  NOT NULL,   -- Redundancia para consultas directas

        -- Quién revisó
        IdRevisor           INT                     NOT NULL,   -- FK lógica → fab.OperadoresFabrica.IdOperador
        NombreRevisor       NVARCHAR(150)           NULL,       -- Snapshot del nombre en el momento de la revisión

        -- Decisión
        DecisionRevision    VARCHAR(10)             NOT NULL,   -- APROBADA, RECHAZADA
        MotivoRechazo       NVARCHAR(300)           NULL,       -- Obligatorio si DecisionRevision = 'RECHAZADA'
        CodigoMotivoRechazo VARCHAR(40)             NULL,       -- Código tipificado
        NotasAdicionales    NVARCHAR(500)           NULL,       -- Observaciones opcionales del revisor

        FechaRevision       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_RevisionesFotografia  PRIMARY KEY (IdRevision),
        CONSTRAINT FK_RevisionesFotografia_Foto FOREIGN KEY (IdFotografia) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT FK_RevisionesFotografia_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_RevisionesFotografia_Decision CHECK (DecisionRevision IN ('APROBADA','RECHAZADA')),
        CONSTRAINT CK_RevisionesFotografia_MotivoRechazo CHECK (
            CodigoMotivoRechazo IS NULL OR CodigoMotivoRechazo IN (
                'FOTO_BORROSA',
                'FOTO_CORTADA',
                'DOCUMENTO_VENCIDO',
                'DOCUMENTO_DAÑADO',
                'ROSTRO_NO_VISIBLE',
                'NO_COINCIDE_PERSONA',
                'FOTO_INCORRECTA',
                'REFLEJO_O_BRILLO',
                'FOTO_DUPLICADA',
                'CALIDAD_INSUFICIENTE',
                'OTRO'
            )
        )
    );

    CREATE INDEX IX_RevisionesFotografia_Foto
        ON [aud].[RevisionesFotografia](IdFotografia, FechaRevision);
    CREATE INDEX IX_RevisionesFotografia_Estudio
        ON [aud].[RevisionesFotografia](IdEstudio, FechaRevision);
    CREATE INDEX IX_RevisionesFotografia_Revisor
        ON [aud].[RevisionesFotografia](IdRevisor, FechaRevision);
    CREATE INDEX IX_RevisionesFotografia_Rechazos
        ON [aud].[RevisionesFotografia](CodigoMotivoRechazo, FechaRevision)
        WHERE DecisionRevision = 'RECHAZADA';


END


-- 7.4  SolicitudesRecarga — links de re-carga enviados al cliente
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.SolicitudesRecarga') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[SolicitudesRecarga] (
        IdSolicitudRecarga  BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio           BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        IdTipoFoto          INT                     NULL,       -- FK → CatalogoTiposFotografia (NULL en handoff biométrico)
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
        MotivoSolicitud     NVARCHAR(300)           NULL,       -- Por qué se generó

        -- Control temporal
        FechaExpiracion     DATETIME2(3)            NOT NULL,
        FechaEnvio          DATETIME2(3)            NULL,
        FechaUso            DATETIME2(3)            NULL,
        NumeroReintentos    INT                     NOT NULL DEFAULT 0,

        -- Quién generó la solicitud
        GeneradaPorSistema  BIT                     NOT NULL DEFAULT 1,
        IdAsesorGenerador   INT                     NULL,       -- FK lógica → fab.OperadoresFabrica.IdOperador

        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_SolicitudesRecarga PRIMARY KEY (IdSolicitudRecarga),
        CONSTRAINT FK_SolicitudesRecarga_Estudio  FOREIGN KEY (IdEstudio)  REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_SolicitudesRecarga_TipoFoto FOREIGN KEY (IdTipoFoto) REFERENCES [cat].[CatalogoTiposFotografia](IdTipoFoto),
        CONSTRAINT FK_SolicitudesRecarga_FotoAnterior FOREIGN KEY (IdFotografiaAnterior) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT UQ_SolicitudesRecarga_Token    UNIQUE (TokenRecarga),
        CONSTRAINT CK_SolicitudesRecarga_Canal    CHECK (CanalEnvio IN ('EMAIL','SMS','WHATSAPP')),
        CONSTRAINT CK_SolicitudesRecarga_Estado   CHECK (EstadoSolicitud IN ('GENERADO','ENVIADO','USADO','EXPIRADO','CANCELADO'))
    );

    CREATE UNIQUE INDEX IX_SolicitudesRecarga_Token
        ON [fab].[SolicitudesRecarga](TokenRecarga);
    CREATE INDEX IX_SolicitudesRecarga_Estudio
        ON [fab].[SolicitudesRecarga](IdEstudio, FechaCreacion)
        INCLUDE (IdTipoFoto);
    CREATE INDEX IX_SolicitudesRecarga_Expiracion
        ON [fab].[SolicitudesRecarga](FechaExpiracion, EstadoSolicitud)
        WHERE EstadoSolicitud IN ('GENERADO','ENVIADO');
    CREATE INDEX IX_SolicitudesRecarga_Canal
        ON [fab].[SolicitudesRecarga](CanalEnvio, EstadoSolicitud, FechaCreacion);


END


-- 7.5  HistorialFotografias — auditoría inmutable de cambios en FotografiasEstudio (aud schema)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.HistorialFotografias') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[HistorialFotografias] (
        IdHistorialFoto     BIGINT IDENTITY(1,1)    NOT NULL,
        IdFotografia        BIGINT                  NOT NULL,   -- FK → FotografiasEstudio
        IdEstudio           BIGINT                  NOT NULL,   -- Redundancia para consultas directas
        IdTipoFoto          INT                     NOT NULL,   -- Redundancia para filtros rápidos

        -- Transición de estado
        EstadoAnterior      VARCHAR(20)             NULL,       -- NULL en la primera transición (creación)
        EstadoNuevo         VARCHAR(20)             NOT NULL,

        -- Contexto de la transición
        TipoActor           VARCHAR(15)             NOT NULL DEFAULT 'SISTEMA',  -- SISTEMA, CLIENTE, ASESOR
        IdActorUsuario      INT                     NULL,       -- FK lógica si es ASESOR (fab.OperadoresFabrica)
        IdentificadorActor  NVARCHAR(100)           NULL,       -- NitTercero si CLIENTE, login si ASESOR, 'SISTEMA' si automático
        MotivoTransicion    NVARCHAR(300)           NULL,
        IdRevisionRelacionada BIGINT                NULL,       -- FK → RevisionesFotografia
        IdSolicitudRelacionada BIGINT               NULL,       -- FK → SolicitudesRecarga

        FechaTransicion     DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_HistorialFotografias PRIMARY KEY (IdHistorialFoto),
        CONSTRAINT FK_HistFotos_Fotografia  FOREIGN KEY (IdFotografia) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT FK_HistFotos_Estudio     FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_HistFotos_TipoFoto    FOREIGN KEY (IdTipoFoto) REFERENCES [cat].[CatalogoTiposFotografia](IdTipoFoto),
        CONSTRAINT FK_HistFotos_Revision    FOREIGN KEY (IdRevisionRelacionada) REFERENCES [aud].[RevisionesFotografia](IdRevision),
        CONSTRAINT FK_HistFotos_Solicitud   FOREIGN KEY (IdSolicitudRelacionada) REFERENCES [fab].[SolicitudesRecarga](IdSolicitudRecarga),
        CONSTRAINT CK_HistFotos_Actor       CHECK (TipoActor IN ('SISTEMA','CLIENTE','ASESOR')),
        CONSTRAINT CK_HistFotos_EstNuevo    CHECK (EstadoNuevo IN (
            'PENDIENTE_CARGA','CARGADA','EN_REVISION','APROBADA','RECHAZADA','REEMPLAZADA','EXPIRADA'
        ))
    );

    CREATE INDEX IX_HistFotos_Fotografia
        ON [aud].[HistorialFotografias](IdFotografia, FechaTransicion);
    CREATE INDEX IX_HistFotos_Estudio
        ON [aud].[HistorialFotografias](IdEstudio, FechaTransicion);
    CREATE INDEX IX_HistFotos_TipoFoto
        ON [aud].[HistorialFotografias](IdTipoFoto, EstadoNuevo, FechaTransicion);


END


-- 7.6  RegistrosBiometria — FKs físicas a FotografiasEstudio
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_Frontal'
)
BEGIN
    ALTER TABLE [fab].[RegistrosBiometria]
        ADD CONSTRAINT FK_RegistrosBiometria_Frontal
        FOREIGN KEY (IdFotografiaFrontal) REFERENCES [fab].[FotografiasEstudio](IdFotografia);
    ALTER TABLE [fab].[RegistrosBiometria]
        ADD CONSTRAINT FK_RegistrosBiometria_Reverso
        FOREIGN KEY (IdFotografiaReverso) REFERENCES [fab].[FotografiasEstudio](IdFotografia);
    ALTER TABLE [fab].[RegistrosBiometria]
        ADD CONSTRAINT FK_RegistrosBiometria_Selfie
        FOREIGN KEY (IdFotografiaSelfie) REFERENCES [fab].[FotografiasEstudio](IdFotografia);

END


-- ==============================================================================
-- ==============================================================================
-- SECCIÓN 8: PARCHES V2.5 — AuditoriaLogins (GAP-15)
-- ==============================================================================

-- 8.1  AuditoriaLogins — GAP-15: Auditoría de intentos de inicio de sesión
--      Registra cada intento de login (exitoso o fallido) por canal y tipo de usuario.
--      INSERT-ONLY: no se actualiza ni elimina.
--      OrigenLogin discrimina si el acceso fue web (cliente) o tienda (asesor).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.AuditoriaLogins') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[AuditoriaLogins] (
        IdLogin             BIGINT IDENTITY(1,1)    NOT NULL,
        OrigenLogin         VARCHAR(20)             NOT NULL,  -- 'LoginWeb' | 'LoginTienda'
        IdUsuario           VARCHAR(50)             NOT NULL,  -- cédula o ID del usuario
        TipoUsuario         VARCHAR(20)             NOT NULL,  -- 'CLIENTE' | 'ASESOR'
        FechaLogin          DATETIME2(3)            NOT NULL   CONSTRAINT DF_AuditoriaLogins_FechaLogin     DEFAULT GETDATE(),
        ResultadoLogin      VARCHAR(20)             NOT NULL,  -- 'EXITOSO' | 'FALLIDO' | 'BLOQUEADO'
        DireccionIP         VARCHAR(45)                 NULL,  -- IPv4 (15) o IPv6 (45)
        UserAgent           NVARCHAR(500)               NULL,
        IdBodega            INT                         NULL,  -- FK blanda a dbo.bodegas
        NitUsuario          VARCHAR(20)                 NULL,  -- GAP-19: CC inmutable del usuario autenticado
        MensajeError        NVARCHAR(500)               NULL,  -- detalle si ResultadoLogin != 'EXITOSO'
        FechaCreacion       DATETIME2(3)            NOT NULL   CONSTRAINT DF_AuditoriaLogins_FechaCreacion  DEFAULT GETDATE(),

        CONSTRAINT PK_AuditoriaLogins             PRIMARY KEY (IdLogin),
        CONSTRAINT CK_AuditoriaLogins_Origen      CHECK (OrigenLogin    IN ('LoginWeb', 'LoginTienda')),
        CONSTRAINT CK_AuditoriaLogins_TipoUsuario CHECK (TipoUsuario    IN ('CLIENTE', 'ASESOR')),
        CONSTRAINT CK_AuditoriaLogins_Resultado   CHECK (ResultadoLogin IN ('EXITOSO', 'FALLIDO', 'BLOQUEADO'))
    );

    CREATE INDEX IX_AuditoriaLogins_Usuario
        ON [aud].[AuditoriaLogins](IdUsuario, FechaLogin DESC);
    CREATE INDEX IX_AuditoriaLogins_Origen
        ON [aud].[AuditoriaLogins](OrigenLogin, FechaLogin DESC);


END


-- ==============================================================================
-- SECCIÓN 9: PARCHES V2.6 — Trazabilidad Operadores (GAP-19)
-- ==============================================================================

-- 9.1 OperadoresFabrica (CON FK LOCAL)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.OperadoresFabrica') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[OperadoresFabrica] (
        IdOperador              INT IDENTITY(1,1)   NOT NULL,
        NitOperador             VARCHAR(20)         NOT NULL,
        NombreOperador          NVARCHAR(200)       NOT NULL,
        CorreoOperador          NVARCHAR(100)       NULL,
        TelefonoOperador        VARCHAR(20)         NULL,
        TipoOperador            VARCHAR(20)         NOT NULL DEFAULT 'ASESOR',
        Activo                  BIT                 NOT NULL DEFAULT 1,
        FechaCreacion           DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion      DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_OperadoresFabrica PRIMARY KEY (IdOperador),
        CONSTRAINT UQ_OperadoresFabrica_Nit UNIQUE (NitOperador),
        CONSTRAINT CK_OperadoresFabrica_Tipo CHECK (
            TipoOperador IN ('ASESOR','SUPERVISOR','GERENTE','REVISOR_FOTOS','CALL_CENTER','ADMINISTRADOR')
        )
    );

    CREATE NONCLUSTERED INDEX IX_OperadoresFabrica_Nit ON [fab].[OperadoresFabrica](NitOperador);
    CREATE NONCLUSTERED INDEX IX_OperadoresFabrica_Tipo ON [fab].[OperadoresFabrica](TipoOperador, Activo);

    -- FKs diferidas (GAP-19): agregadas aquí porque OperadoresFabrica no existe
    -- cuando se crean EstudiosCredito (Sección 3) y ValidacionesAsesor (Sección 6).
    ALTER TABLE [fab].[EstudiosCredito] ADD CONSTRAINT FK_EstudiosCredito_Asesor
        FOREIGN KEY (IdAsesor) REFERENCES [fab].[OperadoresFabrica](IdOperador);

    ALTER TABLE [fab].[ValidacionesAsesor] ADD CONSTRAINT FK_ValidacionesAsesor_Asesor
        FOREIGN KEY (IdAsesor) REFERENCES [fab].[OperadoresFabrica](IdOperador)
        ON UPDATE NO ACTION ON DELETE NO ACTION;

END


-- 9.2 DisponibilidadOperadores (CON FK LOCAL)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.DisponibilidadOperadores') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[DisponibilidadOperadores] (
        IdDisponibilidad        BIGINT IDENTITY(1,1) NOT NULL,
        IdOperador              INT                 NOT NULL,
        NitOperador             VARCHAR(20)         NOT NULL,
        EstadoDisponibilidad  VARCHAR(20)         NOT NULL DEFAULT 'DESCONECTADO',
        FechaConexion           DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaDesconexion        DATETIME2(3)        NULL,
        DireccionIP             VARCHAR(45)         NULL,
        Observaciones           NVARCHAR(500)       NULL,

        CONSTRAINT PK_DisponibilidadOperadores PRIMARY KEY (IdDisponibilidad),
        CONSTRAINT FK_Disponibilidad_Operador FOREIGN KEY (IdOperador) 
            REFERENCES [fab].[OperadoresFabrica](IdOperador),
        CONSTRAINT CK_Disponibilidad_Estado CHECK (
            EstadoDisponibilidad IN ('CONECTADO','DESCONECTADO','EN_PAUSA','NO_DISPONIBLE')
        )
    );

    CREATE NONCLUSTERED INDEX IX_DisponibilidadOperadores_Operador 
        ON [fab].[DisponibilidadOperadores](IdOperador, FechaConexion);
    CREATE NONCLUSTERED INDEX IX_DisponibilidadOperadores_Estado 
        ON [fab].[DisponibilidadOperadores](EstadoDisponibilidad, FechaConexion)
        WHERE EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA');


END


-- ==============================================================================
-- SECCIÓN 10: DATOS SEMILLA (SEEDS) — Complete sync con FABRICASv2.sql
-- ==============================================================================

-- 10.1 FasesEstudio (7 fases)
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.FasesEstudio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[FasesEstudio])
    BEGIN
        INSERT INTO [cfg].[FasesEstudio] (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
        ('IDENTIFICACION',        'Identificación del Cliente',      1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
        ('DATOS_CLIENTE',         'Datos del Cliente',               2, 'Captura o actualización de datos personales y de contacto'),
        ('CONSENTIMIENTO_LEGAL',  'Consentimiento Legal',           3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
        ('VALIDACIONES_RIESGO',   'Validaciones de Riesgo',         4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
        ('LIMITE_CREDITO',        'Límite de Crédito',            5, 'Cálculo y presentación del cupo preaprobado'),
        ('VERIFICACION_IDENTIDAD','Verificación de Identidad',     6, 'Biometría facial, OCR de documento, prueba de vida'),
        ('CIERRE',               'Cierre del Estudio',            7, 'Confirmación, formalización del crédito');
    END
END


-- 10.2 Estados del Proceso (23 estados) — sync completo con v2.6
IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR')
BEGIN
    -- INICIAL
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('BORRADOR', 'En Validación Previa', 'INICIAL', 0, 0, 'El cliente se encuentra en pasos iniciales.'),
    ('PENDIENTE_CLIENTE_PREVIO', 'Pendiente Cliente — Previo', 'INICIAL', 0, 1, 'Se requiere acción del cliente antes de crear solicitud formal.'),
    ('EXPIRADO_PREVIO', 'Expirada — Previo', 'INICIAL', 1, 0, 'El proceso previo no continuó dentro del tiempo permitido.'),
    ('CUPO_YA_ACTIVO', 'Cupo Ya Activo', 'BLOQUEO', 1, 0, 'El cliente ya cuenta con cupo disponible.'),
    ('NO_APLICA_MORA', 'No Aplica — Por Mora', 'BLOQUEO', 1, 0, 'No puede continuar por cartera en mora.'),
    -- REACTIVACION
    ('DESBLOQUEADO', 'Desbloqueado', 'REACTIVACION', 0, 0, 'Se rehabilitó un cupo bloqueado.'),
    ('REACTIVADO', 'Reactivado', 'REACTIVACION', 0, 0, 'Se reactiva un cupo eliminado previamente.'),
    -- PROCESO
    ('EN_PROGRESO', 'En Proceso', 'PROCESO', 0, 1, 'La solicitud avanza normalmente.'),
    ('PAUSADO', 'Pausado', 'PROCESO', 0, 0, 'El cliente se retiró; estudio en espera.'),
    ('PENDIENTE_CLIENTE', 'Pendiente Cliente', 'PROCESO', 0, 1, 'Se requiere acción del cliente.'),
    ('PENDIENTE_OTP', 'Pendiente Validación OTP', 'PROCESO', 0, 1, 'Esperando validación del token.'),
    ('PENDIENTE_BIOMETRIA', 'Pendiente Biometría', 'PROCESO', 0, 1, 'Esperando captura biométrica.'),
    ('PENDIENTE_FOTOS', 'Pendiente Envío de Fotos', 'PROCESO', 0, 1, 'Esperando fotos del cliente.'),
    ('FOTOS_EN_REVISION', 'Fotos en Revisión', 'PROCESO', 0, 0, 'Fotos en revisión manual.'),
    ('PENDIENTE_VALIDACION_AUTOMATICA', 'Pendiente Validación Automática', 'PROCESO', 0, 1, 'Esperando respuesta de motores externos.'),
    ('EN_FABRICA', 'En Fábrica de Soporte', 'PROCESO', 0, 0, 'Caso enviado a gestión manual.'),
    ('CUPO_PREAPROBADO', 'Cupo Preaprobado', 'PROCESO', 0, 1, 'Cupo calculado exitosamente.'),
    ('REVISION_FABRICA', 'En Revisión Manual — Fábrica', 'PROCESO', 0, 0, 'Derivado a revisión por fábrica.'),
    -- TERMINAL
    ('APROBADO', 'Cupo Activado', 'TERMINAL', 1, 0, 'Solicitud aprobada.'),
    ('RECHAZADO', 'Rechazado', 'TERMINAL', 1, 0, 'Solicitud rechazada.'),
    ('NO_VIABLE_ANTECEDENTES_PREVIO', 'No Viable — Antecedentes (Previo)', 'TERMINAL', 1, 0, 'Rechazo en validaciones previas.'),
    ('NO_VIABLE_ANTECEDENTES', 'No Viable — Antecedentes', 'TERMINAL', 1, 0, 'Rechazo por antecedentes.'),
    ('NO_VIABLE_CENTRALES', 'No Viable — Centrales', 'TERMINAL', 1, 0, 'Rechazo por modelo de viabilidad.'),
    ('NO_APLICA_CUPO', 'No Aplica — Para Cupo', 'TERMINAL', 1, 0, 'No supera reglas complementarias.'),
    ('BLOQUEADO_FRAUDE', 'Bloqueado por Sospecha de Fraude', 'TERMINAL', 1, 0, 'Bloqueado por patrón de fraude.'),
    ('EXPIRADO', 'Expirada', 'TERMINAL', 1, 0, 'No retomó dentro del tiempo.'),
    ('CANCELADO_CLIENTE', 'Cancelada por Cliente', 'TERMINAL', 1, 0, 'El cliente desistió.');


END


-- 10.3 PasosEstudio (13 pasos)
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.PasosEstudio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[PasosEstudio])
    BEGIN
        INSERT INTO [cfg].[PasosEstudio] (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, ServicioExterno, EsAutomatico, RequiereIntervencion, TiempoTimeoutSeg, Descripcion) VALUES
    (1, 'INGRESO_DOCUMENTO',       'Ingreso de Documento',              1, 1,  'ASESOR',    NULL,                0, 0, NULL,  'El asesor digita el número de documento'),
    (1, 'VALIDAR_EXISTENCIA',     'Validar Existencia del Cliente',    2, 2,  'SISTEMA',  'ERP_QUAC',           1, 0, 30,   'Verifica si el cliente existe'),
    (1, 'VALIDAR_CUPO_BLOQUEO', 'Validar Cupo Activo / Bloqueo',    3, 3,  'SISTEMA',  'CORE_CREDITO',        1, 0, 30,   'Verifica cupo activo, bloqueos'),
    (2, 'CAPTURA_DATOS',         'Captura de Datos Personales',        1, 4,  'ASESOR',    NULL,                0, 0, NULL,  'Captura de datos personales'),
    (3, 'CONSENTIMIENTO_DATOS',  'Autorización Tratamiento Datos',  1, 5,  'CLIENTE',  NULL,                0, 0, NULL,  'Aceptación de términos'),
    (3, 'TOKENIZACION',          'Envío y Validación de Token OTP',  2, 6,  'SISTEMA',  'OTP_PROVIDER',        1, 0, 120,  'Envío y validación de OTP'),
    (4, 'VALIDAR_LISTAS',        'Validar Listas Restrictivas',           1, 7,  'SISTEMA',  'LISTAS_RESTRICTIVAS', 1, 0, 30,   'Consulta listas restrictivas'),
    (4, 'CONSULTAR_BURO',       'Consultar Buró de Crédito',        2, 8,  'SISTEMA',  'BURO_CREDITO',        1, 0, 60,   'Consulta historial crediticio'),
    (4, 'EVALUAR_PRESELECTA',   'Evaluación Preselecta',          3, 9,  'SISTEMA',  'PRESELECTA',         1, 0, 60,   'Motor de decisión Preselecta'),
    (4, 'VALIDAR_FOSYGA',       'Validar FOSYGA / ADRES',         4, 10, 'SISTEMA',  'FOSYGA',             1, 0, 30,   'Verificación seguridad social'),
    (5, 'CALCULAR_CUPO',        'Cálculo del Cupo Preaprobado',   1, 11, 'SISTEMA',  'MOTOR_CUPO',         1, 0, 30,   'Cálculo del límite de crédito'),
    (6, 'VERIFICACION_BIOMETRICA','Verificación Biométrica',         1, 12, 'SISTEMA',  'BIOMETRIA',          1, 1, 120,  'Captura y verificación biométrica'),
    (7, 'ACTIVACION_CUPO',        'Activación del Cupo',             1, 13, 'SISTEMA',  'UBICA',              1, 1, 60,   'Validación UBICA y activación');

    END
END



-- 10.4 TransicionesEstado (idempotente por fila — se pueden agregar transiciones sin borrar las existentes)

-- Transiciones desde BORRADOR
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Iniciar procesamiento del estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria antes de iniciar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'CANCELADO_CLIENTE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'PENDIENTE_CLIENTE_PREVIO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retracta en validación previa'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'PENDIENTE_CLIENTE_PREVIO';

-- Transiciones desde PENDIENTE_CLIENTE_PREVIO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'BORRADOR')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente completa datos pendientes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'BORRADOR';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria en previo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'CANCELADO_CLIENTE';

-- Transiciones desde EN_PROGRESO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_OTP')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando validación OTP'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_OTP';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_BIOMETRIA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando biométrica'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_BIOMETRIA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_FOTOS')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando fotos del cliente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_FOTOS';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando respuesta de servicio externo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CUPO_PREAPROBADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cupo preaprobado confirmado'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CUPO_PREAPROBADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'APROBADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Todas las validaciones aprobadas'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'APROBADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazado por validación de riesgo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazo por antecedentes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_CENTRALES')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazo por centrales/preselecta'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_CENTRALES';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_APLICA_CUPO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'No aplica para cupo: no supera reglas complementarias'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_APLICA_CUPO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Derivar a fábrica de soporte'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'EN_FABRICA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Regla de fraude crítica: bloqueo automático inmediato'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'BLOQUEADO_FRAUDE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria durante el proceso'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CANCELADO_CLIENTE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Preselecta rechaza por antecedentes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'REVISION_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Anomalía detectada: derivar a revisión manual por fábrica de crédito'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'REVISION_FABRICA';

-- Transiciones desde PAUSADO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente regresa, reanudar estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EXPIRADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Estudio expiró por inactividad'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EXPIRADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria mientras pausado'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'CANCELADO_CLIENTE';

-- Transiciones desde PENDIENTE_OTP
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'OTP validado exitosamente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'OTP fallido, intentos agotados'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'RECHAZADO';

-- Transiciones desde PENDIENTE_BIOMETRIA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Biometría validada exitosamente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Biometría fallida, derivar a fábrica'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_FABRICA';

-- Transiciones desde PENDIENTE_FOTOS
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_FOTOS' AND d.Codigo = 'FOTOS_EN_REVISION')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Fotos recibidas, en revisión'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_FOTOS' AND d.Codigo = 'FOTOS_EN_REVISION';

-- Transiciones desde FOTOS_EN_REVISION
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Asesor aprueba fotos: proceso se reanuda'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'PENDIENTE_FOTOS')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor rechaza fotos: nueva solicitud'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'PENDIENTE_FOTOS';

-- Transiciones desde EN_FABRICA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Fábrica resuelve: reanudar flujo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Fábrica determina rechazo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Fábrica detecta fraude'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE';

-- Transiciones desde PENDIENTE_VALIDACION_AUTOMATICA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Validación automática exitosa'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Validación automática fallida'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_FABRICA';

-- Transiciones desde REVISION_FABRICA (SA-11)
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica resuelve: devolver al flujo automático'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica determina rechazo definitivo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica confirma sospecha de fraude'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE';


-- 10.5 ConfiguracionReglasNegocio
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.ConfiguracionReglasNegocio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[ConfiguracionReglasNegocio])
    BEGIN
        INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_ENFRIAMIENTO',       'Días de Enfriamiento por Rechazo',       '90',    'INT', 'ENFRIAMIENTO', 'Días que un rechazado debe esperar'),
    ('DIAS_EXPIRACION_ESTUDIO', 'Días de Expiración del Estudio',        '90',    'INT', 'GENERAL',      'Días de inactividad antes de expirar'),
    ('INTENTOS_OTP_MAX',        'Intentos Máximos de OTP',               '3',     'INT', 'OTP',          'Número máximo de intentos OTP'),
    ('VIGENCIA_OTP_SEG',       'Vigencia del Token OTP (segundos)',    '300',   'INT', 'OTP',          'Tiempo de vida del token OTP'),
    ('BLOQUEO_OTP_HORAS',      'Horas de Bloqueo por OTP Fallidos',   '24',    'INT', 'OTP',          'Horas de bloqueo tras intentos fallidos'),
    ('INTENTOS_BIOMETRIA_MAX',  'Intentos Máximos de Biometría',      '3',     'INT', 'BIOMETRIA',    'Número máximo de intentos biométricos'),
    ('UMBRAL_MATCH_FACIAL',     'Umbral de Coincidencia Facial (%)',      '85.00','DECIMAL','BIOMETRIA',    'Porcentaje mínimo de coincidencia'),
    ('VENTANA_FRAUDE_OTP_MIN',  'Ventana de tiempo fraude post-OTP',    '10',    'INT', 'RIESGO',       'Minutos después de fallo OTP para regla fraude'),
    ('MAX_ESTUDIOS_POR_IP_HORA','Máximo estudios por IP por hora',     '3',     'INT', 'RIESGO',       'Máximo estudios simultáneos por IP'),
    ('SLA_REVISION_FABRICA_HORAS','SLA revisión fábrica (horas)', '24',    'INT', 'RIESGO',       'Tiempo máximo para resolver escalamiento'),
    ('REENVIOS_OTP_MAX',      'Máximo reenvíos OTP permitidos',    '2',     'INT',          'OTP',          'Reenvíos sin cancelar reto');


END

-- Parámetros adicionales (idempotentes por código)
IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'DIAS_CANCELACION_REACTIV')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_CANCELACION_REACTIV', 'Días Desde Cancelación para Reactivación', '365', 'INT', 'GENERAL', 'Días desde cancelación para reactivación');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_REACTIVACION_CUPO_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_REACTIVACION_CUPO_DIAS', 'Ventana de eliminación para reactivación (días)', '30', 'INT', 'RIESGO', 'Días permitidos para evaluar reactivación de un cupo tras haber sido eliminado por el cliente');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_COMPRAS_RECIENTES_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_COMPRAS_RECIENTES_DIAS', 'Ventana compras recientes ruta simplificada (días)', '60', 'INT', 'RIESGO', 'Validar si el cliente realizó compras en los últimos X días para habilitar validación abreviada');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_ACTUALIZACION_DATOS_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_ACTUALIZACION_DATOS_DIAS', 'Ventana actualización datos ruta simplificada (días)', '90', 'INT', 'RIESGO', 'Días transcurridos sin cambios de correo y dirección para habilitar validación abreviada');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VIGENCIA_LINK_RECARGA_HORAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VIGENCIA_LINK_RECARGA_HORAS', 'Vigencia del link de re-carga de fotografías (horas)', '48', 'INT', 'FOTOS', 'Número de horas que tiene el cliente para usar el link de re-carga antes de que expire');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'MAX_REINTENTOS_RECARGA_FOTO')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('MAX_REINTENTOS_RECARGA_FOTO', 'Máximo de solicitudes de re-carga por foto por estudio', '3', 'INT', 'FOTOS', 'Número máximo de veces que se puede solicitar re-carga de la misma foto en el mismo estudio');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'MAX_VERSIONES_FOTO')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('MAX_VERSIONES_FOTO', 'Máximo de versiones por fotografía por estudio', '4', 'INT', 'FOTOS', 'Número máximo de veces que el cliente puede re-subir la misma foto. Incluye la subida original');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'FOTOS_OBLIGATORIAS_REQUERIDAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('FOTOS_OBLIGATORIAS_REQUERIDAS', 'Número de fotografías obligatorias requeridas para aprobación', '3', 'INT', 'FOTOS', 'Cantidad de fotos que deben estar en estado APROBADA para que el gate de aprobación sea superado');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'CANAL_DEFECTO_RECARGA')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('CANAL_DEFECTO_RECARGA', 'Canal de envío por defecto para links de re-carga', 'WHATSAPP', 'TEXT', 'FOTOS', 'Canal preferido para enviar el link de re-carga al cliente. Valores: EMAIL, SMS, WHATSAPP');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'ALERTA_FOTO_RECHAZADA_VECES')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('ALERTA_FOTO_RECHAZADA_VECES', 'Número de rechazos de una misma foto que activan alerta de fraude', '2', 'INT', 'FOTOS', 'Si la misma foto es rechazada este número de veces consecutivas, se activa una alerta de fraude');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'JWT_ORIGEN_WEB')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('JWT_ORIGEN_WEB', 'Valor del claim ''origen'' en el JWT para el canal de autoservicio web', 'LoginWeb', 'TEXT', 'AUTH', 'Identificador de origen que se incluye en el JWT emitido para sesiones del portal web de autoservicio');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'JWT_ORIGEN_TIENDA')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('JWT_ORIGEN_TIENDA', 'Valor del claim ''origen'' en el JWT para el canal de tienda asistida', 'LoginTienda', 'TEXT', 'AUTH', 'Identificador de origen incluido en el JWT emitido para sesiones iniciadas por el asesor en tienda');

END


-- 10.6 CatalogoCanalesOrigen
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoCanalesOrigen', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoCanalesOrigen])
    BEGIN
        INSERT INTO [cat].[CatalogoCanalesOrigen] (Codigo, Nombre, Descripcion, Activo) VALUES
        ('WEB',     'Canal Web',     'Originación a través del portal web o app',        1),
        ('TIENDA',  'Canal Tienda','Originación presencial en punto de venta',         1),
        ('EXTERNO', 'Canal Externo','Originación por fuerza de ventas externas',        1);
    END
END


-- 10.7 CatalogoReglasFraude
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoReglasFraude', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoReglasFraude])
    BEGIN
        INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('EMAIL_CHANGE_POST_OTP_FAIL', 'Cambio de email después de fallo OTP',
        'El cliente intenta cambiar su email después de fallar OTP. Patrón típico de suplantación.',
        'ALTO', 'ESCALAR'),
    ('CEL_CHANGE_POST_OTP_FAIL', 'Cambio de celular después de fallo OTP',
        'El cliente intenta cambiar su número después de fallar OTP.',
        'ALTO', 'ESCALAR'),
    ('CONTACTO_CHANGE_DURANTE_RETO_ACTIVO', 'Cambio dato contacto con reto activo',
        'Intento de modificar datos mientras hay token OTP vigente.',
        'CRITICO', 'BLOQUEAR'),
    ('MULTIPLES_FALLOS_OTP_MISMA_SESION', 'Múltiples fallos OTP misma sesión',
        'Se agotaron los intentos máximos de OTP en una misma sesión.',
        'MEDIO', 'ESCALAR'),
    ('UBICA_EMAIL_DISCREPANCIA', 'Discrepancia email declarado vs UBICA',
        'El email declarada no coincide con el de UBICA.',
        'MEDIO', 'ESCALAR'),
    ('REINTENTO_RAPIDO_OTRO_EMAIL', 'Reintento rápido con otro email',
        'Solicita nuevo OTP a dirección diferente en poco tiempo.',
        'ALTO', 'ESCALAR'),
    ('IP_MULTIPLES_ESTUDIOS', 'Misma IP en múltiples estudios',
        'La misma IP para varios clientes en período corto.',
        'CRITICO', 'BLOQUEAR'),
    ('DOCUMENTO_OCR_DISCREPANCIA', 'OCR no coincide con datos declarados',
        'Datos extraídos del documento no coinciden con declarados.',
        'MEDIO', 'ESCALAR');


END

-- Reglas de fraude adicionales: DUPLICIDAD y módulo fotográfico (idempotentes por código)
IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'DUPLICIDAD_EMAIL')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('DUPLICIDAD_EMAIL', 'Email Duplicado', 'El correo electrónico ya se encuentra registrado con otro tercero.', 'MEDIO', 'NOTIFICAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'DUPLICIDAD_CELULAR')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('DUPLICIDAD_CELULAR', 'Celular Duplicado', 'El número de celular ya se encuentra registrado con otro tercero.', 'ALTO', 'BLOQUEAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'FOTO_RECHAZADA_MULTIPLE_VECES')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('FOTO_RECHAZADA_MULTIPLE_VECES', 'Fotografía rechazada múltiples veces consecutivas',
     'La misma fotografía fue rechazada en dos o más revisiones consecutivas. Puede indicar intento de usar documentos falsificados.',
     'MEDIO', 'ESCALAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'MAX_VERSIONES_FOTO_SUPERADO')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('MAX_VERSIONES_FOTO_SUPERADO', 'Se superó el máximo de versiones de foto permitidas',
     'El cliente ha intentado subir la misma foto más veces del límite configurado.',
     'ALTO', 'ESCALAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'FOTO_DUPLICADA_OTRO_ESTUDIO')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('FOTO_DUPLICADA_OTRO_ESTUDIO', 'Fotografía idéntica usada en otro estudio de crédito',
     'El hash del archivo de la foto es idéntico al de una foto en otro estudio activo. Posible reutilización fraudulenta.',
     'CRITICO', 'BLOQUEAR');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'SELFIE_NO_COINCIDE_DOCUMENTO')
        INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
        ('SELFIE_NO_COINCIDE_DOCUMENTO', 'Selfie no coincide con fotografía del documento según Rekognition',
         'El porcentaje de coincidencia facial entre la selfie y la foto del documento es menor al umbral configurado (UMBRAL_MATCH_FACIAL).',
         'ALTO', 'ESCALAR');

END


-- 10.8 CatalogoMotivosEscalamiento
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoMotivosEscalamiento', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoMotivosEscalamiento])
    BEGIN
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
    ('OTP_FAIL_EMAIL_CHANGE', 'Cambio email tras fallo OTP', 'Falló OTP y cambió email.', 'FRAUDE'),
    ('OTP_INTENTOS_AGOTADOS', 'Intentos OTP agotados', 'Sin validación exitosa.', 'SISTEMA'),
    ('BIOMETRIA_MAX_REINTENTOS', 'Biometría máximos reintentos', 'Reintentos biométricos agotados.', 'SISTEMA'),
    ('UBICA_GESTION_MANUAL_FABRICA', 'Gestión manual UBICA', 'Resultado UBICA requiere revisión.', 'SISTEMA'),
    ('ALERTA_FRAUDE_CRITICA', 'Alerta fraude nivel crítico', 'Regla de fraude CRÍTICO.', 'FRAUDE'),
    ('DISCREPANCIA_DATOS_UBICA', 'Discrepancia datos UBICA', 'Datos no coinciden con UBICA.', 'SISTEMA'),
    ('ESCALAMIENTO_MANUAL_ASESOR', 'Escalamiento manual', 'Asesor escala manualmente.', 'ASESOR'),
    ('DATO_CONTACTO_MODIFICADO_EN_FLUJO', 'Dato modificado en flujo', 'Modificó dato durante originación.', 'FRAUDE');


END

    -- Motivos de escalamiento fotográfico (idempotentes por código)
    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'FOTO_MAX_REINTENTOS_SUPERADO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('FOTO_MAX_REINTENTOS_SUPERADO', 'Máximo de re-cargas de fotografía superado',
         'El cliente superó el número máximo de intentos de re-carga para una foto. Requiere revisión manual del asesor.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'FOTO_RECHAZADA_VARIAS_VECES')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('FOTO_RECHAZADA_VARIAS_VECES', 'Fotografía rechazada en múltiples revisiones',
         'La misma fotografía fue rechazada por el asesor en dos o más revisiones. Se escala para que un supervisor decida.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'LINK_RECARGA_EXPIRADO_SIN_USO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('LINK_RECARGA_EXPIRADO_SIN_USO', 'Link de re-carga expirado sin uso',
         'El link de re-carga de fotografía expiró sin que el cliente	subiera la foto.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'SELFIE_BIOMETRIA_FALLO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('SELFIE_BIOMETRIA_FALLO', 'Falló verificación biométrica de selfie',
         'La verificación biométrica de la selfie (Rekognition) falló más de N intentos.',
         'SISTEMA');

END


-- 10.9 CatalogoTiposFotografia
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoTiposFotografia', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoTiposFotografia] WHERE Codigo = 'FOTO_FRONTAL_DOC')
    BEGIN
        INSERT INTO [cat].[CatalogoTiposFotografia] (Codigo, Nombre, Descripcion, EsObligatoria, OrdenRevision, ServicioAWS)
    VALUES
    (
        'FOTO_FRONTAL_DOC',
        'Foto Frontal de Cédula de Ciudadanía',
        'Fotografía del lado frontal de la cédula. Usada por OCR y Rekognition CompareFaces.',
        1, 1, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'FOTO_TRASERA_DOC',
        'Foto Reverso de Cédula de Ciudadanía',
        'Fotografía del reverso de la cédula. Usada por OCR para extracción de datos complementarios.',
        1, 2, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'SELFIE',
        'Selfie del Titular',
        'Foto del rostro del cliente (prueba de vida). Usada por Rekognition DetectFaces y CompareFaces.',
        1, 3, 'REKOGNITION_DETECT_FACES'
    );

    END
END


-- 10.10 OperadoresFabrica — Seed de prueba
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'fab.OperadoresFabrica', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [fab].[OperadoresFabrica])
    BEGIN
        INSERT INTO [fab].[OperadoresFabrica] (NitOperador, NombreOperador, CorreoOperador, TelefonoOperador, TipoOperador, Activo) VALUES
        ('12345678', 'Juan Pérez Asesor', 'juan.perez@quac.com', '3001234567', 'ASESOR', 1),
         ('87654321', 'María Supervisora', 'maria.supervisor@quac.com', '3007654321', 'SUPERVISOR', 1),
         ('11223344', 'Carlos Revisor Fotos', 'carlos.revisor@quac.com', '3001122334', 'REVISOR_FOTOS', 1);
    END
END


-- ==============================================================================
-- SECCIÓN 10: PARCHES V2.8 — CENTRALES DE RIESGO
-- ==============================================================================
-- Identifica qué central de riesgo se usa por tipo de servicio. Permite cambiar
-- la combinación Datacredito/CIFIN sin tocar código (solo configuración).
--
--   CR-01: Nueva tabla cfg.CentralesRiesgoCfg
--   CR-02: ALTER fab.EvaluacionesRiesgo — columnas CentralConsultada, IdLogCentralExterno
--   CR-03: Seeds iniciales cfg.CentralesRiesgoCfg
--   CR-04: CHECK ampliado CK_EvaluacionesRiesgo_Tipo
-- ==============================================================================


-- CR-01: cfg.CentralesRiesgoCfg
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.CentralesRiesgoCfg') AND type = 'U')
BEGIN
    CREATE TABLE [cfg].[CentralesRiesgoCfg] (
        IdConfig            INT IDENTITY(1,1)   NOT NULL,
        TipoServicio        VARCHAR(30)         NOT NULL,   -- VIABILIDAD | CONTACTABILIDAD
        CentralActiva       VARCHAR(30)         NOT NULL,   -- DATACREDITO | CIFIN | COMBINADO
        NombreServicio      VARCHAR(50)         NOT NULL,   -- PRESELECTA | VARIABLES_ADVISER | RECONOCER | UBICA | COMBINADO_*
        TablaLogExterna     VARCHAR(100)        NOT NULL,   -- ej: dbo.BERP_FABRICASDatacredito_PreselectaDesicion
        Canal               VARCHAR(20)         NULL,       -- TIENDA | WEB | NULL (todos)
        Activa              BIT                 NOT NULL DEFAULT 1,
        FechaVigencia       DATE                NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        Observaciones       NVARCHAR(500)       NULL,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CentralesRiesgoCfg PRIMARY KEY (IdConfig),
        CONSTRAINT CK_CentralesRiesgoCfg_TipoServicio CHECK (
            TipoServicio IN ('VIABILIDAD','CONTACTABILIDAD')
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Central CHECK (
            CentralActiva IN ('DATACREDITO','CIFIN','COMBINADO')
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Servicio CHECK (
            NombreServicio IN (
                'PRESELECTA',
                'VARIABLES_ADVISER',
                'RECONOCER',
                'UBICA',
                'COMBINADO_VIABILIDAD',
                'COMBINADO_CONTACTABILIDAD'
            )
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Canal CHECK (
            Canal IS NULL OR Canal IN ('TIENDA','WEB','HANDOFF')
        )
    );

    CREATE NONCLUSTERED INDEX IX_CentralesRiesgoCfg_Tipo
        ON [cfg].[CentralesRiesgoCfg] (TipoServicio, Activa);


END


-- CR-02: ALTER fab.EvaluacionesRiesgo — añade columnas de central consultada
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'CentralConsultada')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CentralConsultada   VARCHAR(30) NULL;   -- DATACREDITO | CIFIN | COMBINADO

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExterno')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExterno BIGINT NULL;

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExternoSecundaria')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExternoSecundaria BIGINT NULL;

END

IF NOT EXISTS (
    SELECT * FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo')
    AND name = 'CK_EvaluacionesRiesgo_Central'
)
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CONSTRAINT CK_EvaluacionesRiesgo_Central CHECK (
            CentralConsultada IS NULL OR
            CentralConsultada IN ('DATACREDITO','CIFIN','COMBINADO')
        );

END

-- CR-04: Ampliar CHECK TipoEvaluacion para incluir tipos combinados
IF EXISTS (
    SELECT * FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo')
    AND name = 'CK_EvaluacionesRiesgo_Tipo'
)
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo] DROP CONSTRAINT CK_EvaluacionesRiesgo_Tipo;
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (
            TipoEvaluacion IN (
                'LISTAS',
                'BURO',
                'PRESELECTA',
                'VARIABLES_ADVISER',
                'FOSYGA',
                'ANTECEDENTES',
                'RECONOCER',
                'UBICA',
                'VIABILIDAD_COMBINADA',
                'CONTACTABILIDAD_COMBINADA'
            )
        );

END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IX_EvaluacionesRiesgo_Central')
BEGIN
    CREATE NONCLUSTERED INDEX IX_EvaluacionesRiesgo_Central
        ON [fab].[EvaluacionesRiesgo] (CentralConsultada, TipoEvaluacion)
        WHERE CentralConsultada IS NOT NULL;

END


-- CR-03: Seeds cfg.CentralesRiesgoCfg
IF NOT EXISTS (SELECT 1 FROM [cfg].[CentralesRiesgoCfg] WHERE TipoServicio = 'VIABILIDAD' AND CentralActiva = 'DATACREDITO')
BEGIN
    INSERT INTO [cfg].[CentralesRiesgoCfg]
        (TipoServicio, CentralActiva, NombreServicio, TablaLogExterna, Canal, Activa, Observaciones)
    VALUES
        ('VIABILIDAD',       'DATACREDITO', 'PRESELECTA',       'dbo.BERP_FABRICASDatacredito_PreselectaDesicion', NULL, 1, 'Preselecta Datacredito — viabilidad por defecto'),
        ('VIABILIDAD',       'CIFIN',       'VARIABLES_ADVISER', 'dbo.BERP_FABRICASCifinAdviserLog',                NULL, 0, 'VariablesAdviser CIFIN — alternativa a Preselecta'),
        ('CONTACTABILIDAD',  'CIFIN',       'UBICA',             'dbo.BERP_FABRICASCifinUbicaLog',                  NULL, 1, 'UBICA CIFIN — contactabilidad por defecto'),
        ('CONTACTABILIDAD',  'DATACREDITO', 'RECONOCER',         'dbo.BERP_CUPOAprobacion_Reconocer_Log',           NULL, 0, 'Reconocer Datacredito — alternativa a UBICA');

END


-- ==============================================================================
-- ═══════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE EJECUCIÓN
-- ═══════════════════════════════════════════════════════════════════════════════
PRINT '============================================================';
PRINT '  FABRICAS v2.8-PRUEBAS - EJECUCIÓN COMPLETA';
PRINT '============================================================';
PRINT '✓ Script ejecutado exitosamente en modo PRUEBAS';
