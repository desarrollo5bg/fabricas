/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS V2 (PARA ENTORNO DE PRUEBAS)
  Motor:    SQL Server 2019+
  Versión:  2.5-PRUEBAS
  Fecha:    2026-04-22
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  NOTA: Esta versión contiene REPLICAS LOCALES de las tablas externas necesarias
  para ejecutar el script en un entorno de pruebas donde no se tiene acceso
  a las bases de datos QUAC o PRUEBASBD.
  
  TABLAS EXTERNAS REPLICADAS LOCALMENTE:
  - dbo.terceros      (solo columnas necesarias para FK)
  - dbo.bodegas      (solo columnas necesarias para FK)
  - dbo.BERP_FABRICASOperadores (copia completa)
  - dbo.KCRM_CadenaCreditos (solo columnas necesarias para ALTER TABLE)
  
  Las FKs ahora referencian tablas LOCALES en lugar de QUAC.dbo.*
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
    PRINT '✓ Tabla dbo.terceros (réplica local) creada';
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
    PRINT '✓ Tabla dbo.bodegas (réplica local) creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 0.3 BERP_FABRICASOperadores (REPLICA local para pruebas)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.BERP_FABRICASOperadores') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[BERP_FABRICASOperadores] (
        idOperadorFabrica INT IDENTITY(1,1) NOT NULL,
        idTipoFabrica INT NULL,
        usuario VARCHAR(100) NULL,
        nit DECIMAL(18,0) NULL,
        activo BIT NOT NULL DEFAULT 1,  -- Columna añadida por FÁBRICAS
        
        CONSTRAINT PK_BERP_FABRICASOperadores PRIMARY KEY (idOperadorFabrica)
    );
    PRINT '✓ Tabla dbo.BERP_FABRICASOperadores (réplica local) creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 0.4 KCRM_CadenaCreditos (REPLICA local para pruebas)
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
    PRINT '✓ Tabla dbo.KCRM_CadenaCreditos (réplica local) creada';
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
    PRINT '✓ Tabla FasesEstudio creada';
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
    PRINT '✓ Tabla PasosEstudio creada';
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
    PRINT '✓ Tabla CatalogoEstados creada';
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
    PRINT '✓ Tabla TransicionesEstado creada';
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
    PRINT '✓ Tabla ConfiguracionReglasNegocio creada';
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
    PRINT '✓ Tabla CatalogoCanalesOrigen creada';
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
        CelularTercero         VARCHAR(20) NULL,
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
    
    PRINT '✓ Tabla TercerosFabricas creada con FK local a dbo.terceros';
END


-- 2.2 Modificar dbo.KCRM_CadenaCreditos (ya existe localmente)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'EstadoActualFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD EstadoActualFabricas VARCHAR(20) NULL;
    PRINT '✓ Columna EstadoActualFabricas añadida a KCRM_CadenaCreditos';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD MotivoBloqueoFabricas VARCHAR(50) NULL;
    PRINT '✓ Columna MotivoBloqueoFabricas añadida a KCRM_CadenaCreditos';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD FechaCancelacionFabricas DATETIME2 NULL;
    PRINT '✓ Columna FechaCancelacionFabricas añadida a KCRM_CadenaCreditos';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE [dbo].[KCRM_CadenaCreditos] ADD ElegibleReactivacion BIT NOT NULL DEFAULT 0;
    PRINT '✓ Columna ElegibleReactivacion añadida a KCRM_CadenaCreditos';
END


-- 2.3 Modificar dbo.BERP_FABRICASOperadores (ya existe localmente)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.BERP_FABRICASOperadores') AND name = 'Activo')
BEGIN
    ALTER TABLE [dbo].[BERP_FABRICASOperadores] ADD Activo BIT NOT NULL DEFAULT 1;
    PRINT '✓ Columna Activo añadida a BERP_FABRICASOperadores';
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
        IdAsesor               INT                 NULL,       -- FK a dbo.BERP_FABRICASOperadores.idOperadorFabrica
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
        -- FK local a operadores (en lugar de QUAC.dbo.BERP_FABRICASOperadores)
        CONSTRAINT FK_EstudiosCredito_Asesor FOREIGN KEY (IdAsesor) REFERENCES dbo.BERP_FABRICASOperadores(idOperadorFabrica),
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
    
    PRINT '✓ Tabla EstudiosCredito creada con FKs locales';
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
    
    PRINT '✓ Tabla RetosSeguridad creada';
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
    
    PRINT '✓ Tabla EvaluacionesRiesgo creada';
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
    
    PRINT '✓ Tabla RegistrosBiometria creada';
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
        IdAsesorCallCenter       INT                 NULL,
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
    
    PRINT '✓ Tabla ValidacionesContactabilidad creada';
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
    
    PRINT '✓ Tabla ConsentimientosLegales creada';
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
    
    PRINT '✓ Tabla EvidenciasFabrica creada';
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
    
    PRINT '✓ Tabla HistorialEstados creada';
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
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        FechaCambio         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_AuditoriaCambiosDatos PRIMARY KEY (IdAuditoria),
        CONSTRAINT FK_Audit_Request FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_AuditoriaCambiosDatos_TipoUsuario CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CLIENTE','ADMINISTRADOR'))
    );
    
    CREATE INDEX IX_AuditoriaCambiosDatos_Cliente ON [aud].[AuditoriaCambiosDatos](NitTercero, FechaCambio);
    CREATE INDEX IX_AuditoriaCambiosDatos_Estudio ON [aud].[AuditoriaCambiosDatos](IdEstudio) WHERE IdEstudio IS NOT NULL;
    
    PRINT '✓ Tabla AuditoriaCambiosDatos creada';
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
    
    PRINT '✓ Tabla RegistroServiciosExternos creada';
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
    PRINT '✓ Tabla CatalogoReglasFraude creada';
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
    PRINT '✓ Tabla CatalogoMotivosEscalamiento creada';
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
        AccionTomada        VARCHAR(20)         NOT NULL DEFAULT 'PENDIENTE',
        IdUsuarioResolucion INT                 NULL,
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

    PRINT '✓ Tabla AlertasFraude creada';
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
        EscaladoPorSistema      BIT                     NOT NULL DEFAULT 1,
        IdUsuarioEscala         INT                     NULL,
        IdAsesorAsignado        INT                     NULL,
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

    PRINT '✓ Tabla EscalamientosFabrica creada';
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

    PRINT '✓ Tabla LogValidacionesOTP creada';
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

    PRINT '✓ Tabla HistorialDatosSensibles creada';
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
    PRINT '✓ ValidacionesContactabilidad: FK FK_ValidContact_AlertaFraude añadida';
END


-- ==============================================================================
-- SECCIÓN 6: PARCHES V2.4 — ValidacionesAsesor
-- ==============================================================================

-- ValidacionesAsesor (CON FKs LOCALES)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ValidacionesAsesor') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[ValidacionesAsesor] (
        IdValidacion            BIGINT IDENTITY(1,1)    NOT NULL,
        IdAsesor                INT                     NOT NULL,   -- FK → dbo.BERP_FABRICASOperadores
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
        -- FK local al operador (en lugar de QUAC.dbo.BERP_FABRICASOperadores)
        CONSTRAINT FK_ValidacionesAsesor_Asesor
            FOREIGN KEY (IdAsesor)
            REFERENCES dbo.BERP_FABRICASOperadores (idOperadorFabrica)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
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

    PRINT '✓ Tabla ValidacionesAsesor creada con FKs locales';
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
    PRINT '✓ EstudiosCredito: FK FK_EstudiosCredito_ValidacionAsesor añadida';
END


-- ==============================================================================
-- SECCIÓN 7: PARCHES V2.3 — Gestión de Fotografías
-- ==============================================================================

-- CatalogoTiposFotografia
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoTiposFotografia') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoTiposFotografia] (
        IdTipoFoto          INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(20)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Descripcion         NVARCHAR(300)       NULL,
        EsObligatorio       BIT                 NOT NULL DEFAULT 1,
        OrdenSecuencia      INT                 NOT NULL DEFAULT 0,
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CatalogoTiposFotografia PRIMARY KEY (IdTipoFoto),
        CONSTRAINT UQ_CatalogoTiposFotografia_Codigo UNIQUE (Codigo)
    );
    PRINT '✓ Tabla CatalogoTiposFotografia creada';
END


-- FotografiasEstudio
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.FotografiasEstudio') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[FotografiasEstudio] (
        IdFotografia        BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio           BIGINT                  NOT NULL,
        IdTipoFoto          INT                     NOT NULL,
        UrlArchivo          NVARCHAR(500)           NOT NULL,
        NombreArchivo       NVARCHAR(200)           NOT NULL,
        ContentType         VARCHAR(100)            NULL,
        TamanoBytes         BIGINT                  NULL,
        HashArchivo         VARCHAR(64)             NULL,
        Estado              VARCHAR(20)             NOT NULL DEFAULT 'PENDIENTE',
        IntentosSubida      INT                     NOT NULL DEFAULT 0,
        FechaSubida         DATETIME2(3)            NULL,
        FechaVerificacion   DATETIME2(3)            NULL,
        ResultadoVerificacion VARCHAR(30)            NULL,
        MensajeVerificacion  NVARCHAR(500)           NULL,
        FechaCreacion       DATETIME2(3)              NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_FotografiasEstudio PRIMARY KEY (IdFotografia),
        CONSTRAINT FK_FotografiasEstudio_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_FotografiasEstudio_Tipo FOREIGN KEY (IdTipoFoto) REFERENCES [cat].[CatalogoTiposFotografia](IdTipoFoto),
        CONSTRAINT CK_FotografiasEstudio_Estado CHECK (Estado IN ('PENDIENTE','EN_PROCESO','APROBADA','RECHAZADA','ERROR'))
    );

    CREATE INDEX IX_FotografiasEstudio_Estudio ON [fab].[FotografiasEstudio](IdEstudio, IdTipoFoto);
    CREATE INDEX IX_FotografiasEstudio_Estado ON [fab].[FotografiasEstudio](Estado, FechaCreacion);

    PRINT '✓ Tabla FotografiasEstudio creada';
END


-- RevisionesFotografia
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.RevisionesFotografia') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[RevisionesFotografia] (
        IdRevision           BIGINT IDENTITY(1,1) NOT NULL,
        IdFotografia        BIGINT              NOT NULL,
        Resultado           VARCHAR(20)         NOT NULL,
        MotivoRechazo       VARCHAR(100)        NULL,
        Comentarios        NVARCHAR(500)        NULL,
        RevisadoPor         VARCHAR(100)        NOT NULL,
        FechaRevision      DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_RevisionesFotografia PRIMARY KEY (IdRevision),
        CONSTRAINT FK_RevisionesFotografia_Foto FOREIGN KEY (IdFotografia) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT CK_RevisionesFotografia_Resultado CHECK (Resultado IN ('APROBADA','RECHAZADA'))
    );

    CREATE INDEX IX_RevisionesFotografia_Foto ON [fab].[RevisionesFotografia](IdFotografia, FechaRevision);

    PRINT '✓ Tabla RevisionesFotografia creada';
END


-- SolicitudesRecarga
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.SolicitudesRecarga') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[SolicitudesRecarga] (
        IdSolicitud         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        IdTipoFoto          INT                 NULL,
        UrlTemporal        NVARCHAR(500)       NOT NULL,
        TokenAcceso       VARCHAR(64)         NOT NULL,
        FechaSolicitud    DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaExpiracion   DATETIME2(3)        NOT NULL,
        Resultado         VARCHAR(20)         NULL,
        FechaProcesamiento DATETIME2(3)    NULL,

        CONSTRAINT PK_SolicitudesRecarga PRIMARY KEY (IdSolicitud),
        CONSTRAINT FK_SolicitudesRecarga_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_SolicitudesRecarga_Resultado CHECK (
            Resultado IS NULL OR Resultado IN ('PENDIENTE','EXITOSA','FALLIDA','EXPIRADA')
        )
    );

    CREATE INDEX IX_SolicitudesRecarga_Estudio ON [fab].[SolicitudesRecarga](IdEstudio, IdTipoFoto);
    CREATE INDEX IX_SolicitudesRecarga_Token ON [fab].[SolicitudesRecarga](TokenAcceso);

    PRINT '✓ Tabla SolicitudesRecarga creada';
END


-- HistorialFotografias
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.HistorialFotografias') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[HistorialFotografias] (
        IdHistorial         BIGINT IDENTITY(1,1) NOT NULL,
        IdFotografia        BIGINT              NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        CampoCambiado       VARCHAR(30)         NOT NULL,
        ValorAnterior      NVARCHAR(200)       NULL,
        ValorNuevo         NVARCHAR(200)       NULL,
        CausaCambio        VARCHAR(50)         NULL,
        Observaciones      NVARCHAR(500)        NULL,
        FechaCambio        DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_HistorialFotografias PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_HistorialFotografias_Foto FOREIGN KEY (IdFotografia) REFERENCES [fab].[FotografiasEstudio](IdFotografia)
    );

    CREATE INDEX IX_HistorialFotografias_Foto ON [fab].[HistorialFotografias](IdFotografia, FechaCambio);

    PRINT '✓ Tabla HistorialFotografias creada';
END


-- RegistrosBiometria — FKs a FotografiasEstudio
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
    PRINT '✓ FKs a FotografiasEstudio añadidas a RegistrosBiometria';
END


-- ==============================================================================
-- SECCIÓN 8: PARCHES V2.5 — AuditoriaLogins
-- ==============================================================================

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.AuditoriaLogins') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[AuditoriaLogins] (
        IdAuditoria     BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio       BIGINT              NULL,
        NitTercero      VARCHAR(20)         NOT NULL,
        Canal           VARCHAR(20)         NOT NULL,
        TipoLogin      VARCHAR(20)         NOT NULL,
        Resultado       VARCHAR(20)         NOT NULL,
        DireccionIP     VARCHAR(45)         NULL,
        UserAgent      NVARCHAR(500)       NULL,
        TokenAcceso    VARCHAR(64)         NULL,
        FechaLogin    DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_AuditoriaLogins PRIMARY KEY (IdAuditoria),
        CONSTRAINT CK_AuditoriaLogins_Resultado CHECK (Resultado IN ('EXITOSO','FALLIDO','BLOQUEADO','EXPIRADO'))
    );

    CREATE INDEX IX_AuditoriaLogins_Estudio ON [aud].[AuditoriaLogins](IdEstudio, FechaLogin);
    CREATE INDEX IX_AuditoriaLogins_Cliente ON [aud].[AuditoriaLogins](NitTercero, FechaLogin);

    PRINT '✓ Tabla AuditoriaLogins creada';
END


-- ==============================================================================
-- ═══════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE EJECUCIÓN
-- ==============================================================================
PRINT '';
PRINT '============================================================';
PRINT '  FABRICAS v2.5-PRUEBAS - EJECUCIÓN COMPLETA';
PRINT '============================================================';
PRINT '';
PRINT 'Tablas creadas/modificadas:';
PRINT '  - dbo.terceros (réplica local)';
PRINT '  - dbo.bodegas (réplica local)';
PRINT '  - dbo.BERP_FABRICASOperadores (réplica local)';
PRINT '  - dbo.KCRM_CadenaCreditos (réplica local)';
PRINT '  - cfg.FasesEstudio';
PRINT '  - cfg.PasosEstudio';
PRINT '  - cfg.CatalogoEstados';
PRINT '  - cfg.TransicionesEstado';
PRINT '  - cfg.ConfiguracionReglasNegocio';
PRINT '  - cat.CatalogoCanalesOrigen';
PRINT '  - cat.CatalogoReglasFraude';
PRINT '  - cat.CatalogoMotivosEscalamiento';
PRINT '  - cat.CatalogoTiposFotografia';
PRINT '  - fab.TercerosFabricas';
PRINT '  - fab.EstudiosCredito';
PRINT '  - fab.RetosSeguridad';
PRINT '  - fab.EvaluacionesRiesgo';
PRINT '  - fab.RegistrosBiometria';
PRINT '  - fab.ValidacionesContactabilidad';
PRINT '  - fab.ConsentimientosLegales';
PRINT '  - fab.EvidenciasFabrica';
PRINT '  - fab.EscalamientosFabrica';
PRINT '  - fab.ValidacionesAsesor';
PRINT '  - fab.FotografiasEstudio';
PRINT '  - fab.RevisionesFotografia';
PRINT '  - fab.SolicitudesRecarga';
PRINT '  - fab.HistorialFotografias';
PRINT '  - aud.HistorialEstados';
PRINT '  - aud.AuditoriaCambiosDatos';
PRINT '  - aud.RegistroServiciosExternos';
PRINT '  - aud.AlertasFraude';
PRINT '  - aud.LogValidacionesOTP';
PRINT '  - aud.HistorialDatosSensibles';
PRINT '  - aud.AuditoriaLogins';
PRINT '';
PRINT 'NOTA: Los seeds están en FABRICASv2_SEEDS.sql';
PRINT '';
PRINT '✓ Script ejecutado exitosamente en modo PRUEBAS';
PRINT '';
PRINT '============================================================';
PRINT '  FABRICAS v2.5-PRUEBAS - EJECUCIÓN COMPLETA';
PRINT '============================================================';
PRINT '';
PRINT 'Tablas creadas/modificadas:';
PRINT '  - dbo.terceros (réplica local)';
PRINT '  - dbo.bodegas (réplica local)';
PRINT '  - dbo.BERP_FABRICASOperadores (réplica local)';
PRINT '  - dbo.KCRM_CadenaCreditos (réplica local)';
PRINT '  - cfg.FasesEstudio';
PRINT '  - cfg.PasosEstudio';
PRINT '  - cfg.CatalogoEstados';
PRINT '  - cfg.TransicionesEstado';
PRINT '  - cfg.ConfiguracionReglasNegocio';
PRINT '  - cat.CatalogoCanalesOrigen';
PRINT '  - cat.CatalogoReglasFraude';
PRINT '  - cat.CatalogoMotivosEscalamiento';
PRINT '  - cat.CatalogoTiposFotografia';
PRINT '  - fab.TercerosFabricas';
PRINT '  - fab.EstudiosCredito';
PRINT '  - fab.RetosSeguridad';
PRINT '  - fab.EvaluacionesRiesgo';
PRINT '  - fab.RegistrosBiometria';
PRINT '  - fab.ValidacionesContactabilidad';
PRINT '  - fab.ConsentimientosLegales';
PRINT '  - fab.EvidenciasFabrica';
PRINT '  - fab.EscalamientosFabrica';
PRINT '  - fab.ValidacionesAsesor';
PRINT '  - fab.FotografiasEstudio';
PRINT '  - fab.RevisionesFotografia';
PRINT '  - fab.SolicitudesRecarga';
PRINT '  - fab.HistorialFotografias';
PRINT '  - aud.HistorialEstados';
PRINT '  - aud.AuditoriaCambiosDatos';
PRINT '  - aud.RegistroServiciosExternos';
PRINT '  - aud.AlertasFraude';
PRINT '  - aud.LogValidacionesOTP';
PRINT '  - aud.HistorialDatosSensibles';
PRINT '  - aud.AuditoriaLogins';
PRINT '';
PRINT '✓ Script ejecutado exitosamente en modo PRUEBAS';
PRINT '';
