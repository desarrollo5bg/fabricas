/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — MODELO DE DATOS V2
  Motor:    SQL Server 2019+
  Versión:  2.5
  Fecha:    2026-04-15
  Autor:    Arquitectura de Datos — QUAC FinTech
  
   ESTRUCTURA DEL SCRIPT:
   ─────────────────────────────────────────────────────────────────────────────
   1. TABLAS DE CONFIGURACIÓN (6 tablas)      → Parametrización del flujo
   2. MODIFICACIÓN DE TABLAS EXISTENTES        → ALTER TABLE a tablas prod.
      2.1 NUEVAS TABLAS DE OPERADORES (GAP-19) → OperadoresFabrica, DisponibilidadOperadores
   3. TABLAS TRANSACCIONALES (9 tablas)        → Operaciones del proceso
   4. TABLAS DE AUDITORÍA (3 tablas)           → Trazabilidad inmutable
   5. PARCHES V2.2 — Architect Audit    → Tablas y columnas de fraude/escalamiento
   6. DATOS SEMILLA (SEEDS)                    → Catálogos iniciales
    7. PARCHES V2.3 — GESTIÓN DE FOTOGRAFÍAS    → Ciclo de vida de fotos, revisión, re-carga
    8. PARCHES V2.4 — CORRECCIONES ARQUITECTURA → ValidacionesAsesor, IdBodega, reglas OTP/JWT
     9. PARCHES V2.5 — 18 AUDIT GAPS            → Correcciones de auditoría v2.5
   10. PARCHES V2.6 — TRAZABILIDAD OPERADORES → Consolidación de NITs, nuevas tablas de operadores (GAP-19)
  
   NOTAS:
   - Las tablas QUAC.dbo.terceros, QUAC.dbo.bodegas, PRUEBASBD.dbo.kcrm_VendedoresExternos,
     QUAC.dbo.KCRM_CadenaCreditos YA EXISTEN
   - QUAC.dbo.BERP_FABRICASOperadores YA NO ES MODIFICADA — reemplazado por fab.OperadoresFabrica
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

  CAMBIOS v2.2 — Architect Audit (2026-04-10):
  - SA-01: Nueva tabla CatalogoMotivosEscalamiento (catálogo tipificado de razones)
  - SA-02: Nueva tabla EscalamientosFabrica (trazabilidad completa para asesor)
  - SA-03: Nueva tabla LogValidacionesOTP (log granular de intentos, INSERT-ONLY)
  - SA-04: Nueva tabla HistorialDatosSensibles (mutaciones email/cel con contexto)
  - SA-05: Nueva tabla AlertasFraude (registro inmutable de alertas, INSERT-ONLY)
  - SA-06: Nueva tabla CatalogoReglasFraude (tipificación de reglas de detección)
  - SA-07: EstudiosCredito +EliminadoLogico +IdCorrelacion +IdEscalamientoActivo
  - SA-08: HistorialEstados +IdCorrelacion
  - SA-09: RetosSeguridad +DireccionEnvio
  - SA-10: ValidacionesContactabilidad +IdAlertaFraude +FK
  - SA-11: CatalogoEstados: estados REVISION_FABRICA y BLOQUEADO_FRAUDE + 6 transiciones

  CAMBIOS v2.4 — Correcciones de Arquitectura (2026-04-15):
  - C-01: Auth — Reglas de negocio OTP_EXPIRACION_MINUTOS, OTP_MAXIMO_INTENTOS, JWT_ORIGEN_WEB, JWT_ORIGEN_BODEGA en ConfiguracionReglasNegocio
  - C-02: IdTienda → IdBodega en EstudiosCredito + renombre índice IX_EstudiosCredito_Tienda → IX_EstudiosCredito_Bodega
  - C-03: Nueva tabla ValidacionesAsesor (log de validación biométrica de identidad del asesor)
  - C-04: IdValidacionAsesor BIGINT NULL FK → ValidacionesAsesor (columna en CREATE TABLE; FK como ALTER por dependencia circular)
  - C-05: NitComercio VARCHAR(20) NOT NULL añadido a EstudiosCredito (NIT del comercio donde se origina el cupo)

  CAMBIOS v2.5 — 18 Audit Gaps (2026-04-15):
  - GAP-01: SolicitudesRecarga.IdTipoFoto cambiado de NOT NULL a NULL (handoff biométrico)
  - GAP-02: HistorialEstados.TipoUsuario CHECK ampliado con 'CLIENTE' y 'ADMINISTRADOR'
  - GAP-03: EstudiosCredito +CelularCliente VARCHAR(20) NULL (envío de OTP)
  - GAP-04: ConfiguracionReglasNegocio: eliminadas semillas duplicadas OTP_MAXIMO_INTENTOS y OTP_EXPIRACION_MINUTOS; JWT_ORIGEN_BODEGA renombrado a JWT_ORIGEN_TIENDA
  - GAP-05: ConfiguracionReglasNegocio +CHECK CK_ConfiguracionReglasNegocio_Categoria
  - GAP-06: TercerosFabricas: todos los DATETIME2 sin precisión → DATETIME2(3)
  - GAP-07: FotografiasEstudio REDISEÑADA (tabla unificada biométrica); EvidenciasFabrica conservada sin valores fotográficos en CHECK
  - GAP-08: AuditoriaCambiosDatos +CHECK CK_AuditoriaCambiosDatos_TipoUsuario
  - GAP-09: TercerosFabricas.NombreTercero VARCHAR→NVARCHAR(200)
  - GAP-10: Seeds de TransicionesEstado: patrón IF NOT EXISTS idempotente (ya aplicado en v2.2)
  - GAP-11: CatalogoCanalesOrigen: SYSDATETIME() → GETDATE()
  - GAP-12: EstudiosCredito +IX_EstudiosCredito_EscalamientoActivo
  - GAP-13: RegistrosBiometria.TipoVerificacion CHECK ampliado con 'PRUEBA_VIDA_HANDOFF'
  - GAP-14: ValidacionesAsesor +IX_ValidacionesAsesor_Exitosas (índice filtrado hot-path)
  - GAP-15: Nueva tabla AuditoriaLogins
  - GAP-16: SolicitudesRecarga: índice IX_SolicitudesRecarga_Estudio no incluye IdTipoFoto en clave
  - GAP-17: JWT_ORIGEN_TIENDA seed (ya cubierto por GAP-04)
  - GAP-18: TercerosFabricas +CelularPrincipal, +CelularWhatsApp
  - GAP-19: OperadoresFabrica +DisponibilidadOperadores (Trazabilidad inmutable de operadores)
  - GAP-20: EstudiosCredito +RenunciaCupo BIT NOT NULL DEFAULT 0 (Eliminación voluntaria)
  - GAP-21: EvaluacionesRiesgo +MoraComerciosAliados BIT NULL
  - GAP-22: CatalogoReglasFraude +DUPLICIDAD_EMAIL, +DUPLICIDAD_CELULAR (Políticas de duplicidad)
  - GAP-23: ConfiguracionReglasNegocio +VENTANA_REACTIVACION_CUPO_DIAS, +VENTANA_ELIMINACION_RECIENTE_DIAS
  - GAP-24: Documentación actualizada con gaps v2.7

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
   CAMBIOS v2.6 — Trazabilidad Inmutable de Operadores (GAP-19):
   - GAP-19: Consolidación de columnas NIT de operadores a un naming estándar (NitAsesor).
     Todas las referencias a operadores/asesores usan NitAsesor para consistencia.
     Adición de nuevas tablas fab.OperadoresFabrica y fab.DisponibilidadOperadores.
     Esto permite mantener una trazabilidad inmutable de la cédula del operador que realiza una acción, 
     incluso si el IdOperador/usuario interno cambia de dueño en el ERP.

================================================================================
*/

-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- ==============================================================================
-- CREACIÓN DE ESQUEMAS LÓGICOS
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'cfg') EXEC('CREATE SCHEMA cfg');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'cat') EXEC('CREATE SCHEMA cat');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fab') EXEC('CREATE SCHEMA fab');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'aud') EXEC('CREATE SCHEMA aud');


-- SECCIÓN 1: TABLAS DE CONFIGURACIÓN (MAQUINA DE ESTADOS)
-- ==============================================================================
-- Estas tablas definen el flujo, estados y reglas de negocio.
-- Se crean desde cero ya que no existen en el sistema actual.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.1 FasesEstudio: Las 7 fases macro del proceso de otorgamiento
-- ─────────────────────────────────────────────────────────────────────────────
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.2 PasosEstudio: Los 13 pasos individuales del flujo
-- ─────────────────────────────────────────────────────────────────────────────
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.3 CatalogoEstados: Todos los estados posibles del estudio
-- ─────────────────────────────────────────────────────────────────────────────
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
        CONSTRAINT UQ_CatalogoEstados_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatalogoEstados_Grupo CHECK (Grupo IN ('INICIAL','PROCESO','TERMINAL','BLOQUEO','REACTIVACION'))
    );
    PRINT '✓ Tabla CatalogoEstados creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.4 TransicionesEstado: Máquina de estados - transiciones válidas
-- ─────────────────────────────────────────────────────────────────────────────
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.5 ConfiguracionReglasNegocio: Parámetros configurables del sistema
-- ─────────────────────────────────────────────────────────────────────────────
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
        CONSTRAINT CK_ConfiguracionReglasNegocio_Categoria CHECK (  -- GAP-05
            Categoria IN ('ENFRIAMIENTO','GENERAL','OTP','BIOMETRIA','RIESGO','FOTOS','AUTH')
        )
    );
    PRINT '✓ Tabla ConfiguracionReglasNegocio creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.6 CatalogoCanalesOrigen: Catálogo de canales por los que ingresa el cliente
--     G-DB-01: Tabla dominio para EstudiosCredito.IdCanal
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoCanalesOrigen') AND type in (N'U'))
BEGIN
    CREATE TABLE [cat].[CatalogoCanalesOrigen] (
        IdCanal             INT IDENTITY(1,1)   NOT NULL,
        Codigo              VARCHAR(20)         NOT NULL,
        Nombre              NVARCHAR(100)       NOT NULL,
        Descripcion         NVARCHAR(300)       NULL,
        Activo              BIT                 NOT NULL DEFAULT 1,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),    -- GAP-11: GETDATE() estándar
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),    -- GAP-11: GETDATE() estándar
        
        CONSTRAINT PK_CatalogoCanalesOrigen PRIMARY KEY (IdCanal),
        CONSTRAINT UQ_CatalogoCanalesOrigen_Codigo UNIQUE (Codigo)
    );
    PRINT '✓ Tabla CatalogoCanalesOrigen creada';
END



-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 2: MODIFICACIÓN DE TABLAS EXISTENTES EN PRODUCCIÓN (ALTER TABLE)
-- ==============================================================================
-- IMPORTANTE: Esta sección SOLO contiene ALTER TABLE sobre tablas que YA EXISTEN
-- en producción (QUAC.dbo.KCRM_CadenaCreditos, QUAC.dbo.BERP_FABRICASOperadores).
-- Las nuevas tablas de este proyecto se crean con su DDL completo en las secciones
-- siguientes. NO hay ALTER TABLE para tablas creadas en este mismo script.

-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1 Nueva Tabla: TercerosFabricas — Fuente de Verdad para Clientes
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Tabla propia del proceso fábricas que actúa como fuente de verdad
-- para los datos de clientes. Se integra con terceros mediante NIT como FK.
-- Estrategia: Leer de terceros para validar existencia, escribir en esta tabla
-- para el proceso de originación. Sincronización inversa hacia terceros según
-- reglas de negocio (no se altera la estructura de terceros).

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.TercerosFabricas') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[TercerosFabricas] (
        IdTerceroFabricas       INT IDENTITY(1,1) NOT NULL,
        NitTercero              VARCHAR(20) NOT NULL,
        NombreTercero           NVARCHAR(200) NULL,          -- GAP-09: NVARCHAR para soportar ñ y acentos
        EstadoTercero           VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
        TieneCupoActivo        BIT NOT NULL DEFAULT 0,
        EstaBloqueadoFabricas  BIT NOT NULL DEFAULT 0,
        MotivoBloqueo          VARCHAR(100) NULL,
        FechaBloqueo           DATETIME2(3) NULL,            -- GAP-06: precisión explícita (3)
        FechaDesbloqueo        DATETIME2(3) NULL,            -- GAP-06: precisión explícita (3)
        TieneRegistroBiometrico BIT NOT NULL DEFAULT 0,
        FechaRegistroBiometrico DATETIME2(3) NULL,           -- GAP-06: precisión explícita (3)
        PuntajeCredito         DECIMAL(5,2) NULL,
        FechaUltimaEvaluacion  DATETIME2(3) NULL,            -- GAP-06: precisión explícita (3)
        CelularPrincipal       VARCHAR(20) NULL,             -- GAP-18: Teléfono para llamadas/SMS
        CelularWhatsApp        VARCHAR(20) NULL,             -- GAP-18: Teléfono exclusivo para WhatsApp
        FechaCreacion          DATETIME2(3) NOT NULL DEFAULT GETDATE(),  -- GAP-06+11: DATETIME2(3) y GETDATE()
        FechaModificacion      DATETIME2(3) NOT NULL DEFAULT GETDATE(),  -- GAP-06+11: DATETIME2(3) y GETDATE()
        CONSTRAINT PK_TercerosFabricas PRIMARY KEY CLUSTERED (IdTerceroFabricas),
        CONSTRAINT UQ_TercerosFabricas_Nit UNIQUE (NitTercero),
        CONSTRAINT FK_TercerosFabricas_Terceros FOREIGN KEY (NitTercero)
            REFERENCES QUAC.dbo.terceros (nit) ON UPDATE NO ACTION ON DELETE NO ACTION
    );
    
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Nit ON [fab].[TercerosFabricas] (NitTercero);
    CREATE NONCLUSTERED INDEX IX_TercerosFabricas_Estado ON [fab].[TercerosFabricas] (EstadoTercero, EstaBloqueadoFabricas);
    
    PRINT '✓ Tabla TercerosFabricas creada exitosamente';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1b OperadoresFabrica — Registro maestro de operadores/asesores de la fábrica
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Tabla propia que reemplaza/complementa BERP_FABRICASOperadores con
-- información sobre los operadores/asesores que trabajan en la fábrica de crédito.
-- La trazabilidad immutable se logra mediante NitAsesor en las tablas transaccionales.

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.OperadoresFabrica') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[OperadoresFabrica] (
        IdOperador              INT IDENTITY(1,1)   NOT NULL,
        NitOperador             VARCHAR(20)         NOT NULL,   -- Cédula única del operador (trazabilidad principal)
        NombreOperador          NVARCHAR(200)       NOT NULL,
        CorreoOperador          NVARCHAR(100)       NULL,
        TelefonoOperador        VARCHAR(20)         NULL,
        TipoOperador            VARCHAR(20)         NOT NULL,   -- ASESOR, SUPERVISOR, GERENTE, REVISOR_FOTOS, CALL_CENTER
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
    
    PRINT '✓ Tabla OperadoresFabrica creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1c DisponibilidadOperadores — Registro de disponibilidad/conexiones de operadores
-- ─────────────────────────────────────────────────────────────────────────────
-- Objetivo: Reemplaza BERP_FABRICASOperadorEstados. Registra cuándo un operador
-- se conecta y se desconecta del sistema para tomar tickets/casos.
-- Nota: activarse y desactivarse es una acción que realiza solo 1-2 veces en su jornada,
-- por lo que no requiere logging granular sino snapshots de estado actual.

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.DisponibilidadOperadores') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[DisponibilidadOperadores] (
        IdDisponibilidad        BIGINT IDENTITY(1,1) NOT NULL,
        IdOperador              INT                 NOT NULL,   -- FK a OperadoresFabrica
        NitOperador             VARCHAR(20)         NOT NULL,   -- Trazabilidad inmutable
        EstadoDisponibilidad    VARCHAR(20)         NOT NULL,   -- CONECTADO, DESCONECTADO, EN_PAUSA, NO_DISPONIBLE
        FechaConexion           DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaDesconexion        DATETIME2(3)        NULL,
        DireccionIP             VARCHAR(45)         NULL,       -- IP de conexión para auditoría
        Observaciones           NVARCHAR(500)       NULL,
        
        CONSTRAINT PK_DisponibilidadOperadores PRIMARY KEY (IdDisponibilidad),
        CONSTRAINT FK_Disponibilidad_Operador FOREIGN KEY (IdOperador) 
            REFERENCES [fab].[OperadoresFabrica](IdOperador),
        CONSTRAINT CK_Disponibilidad_Estado CHECK (
            EstadoDisponibilidad IN ('CONECTADO','DESCONECTADO','EN_PAUSA','NO_DISPONIBLE')
        )
    );
    
    CREATE NONCLUSTERED INDEX IX_DisponibilidadOperadores_Operador ON [fab].[DisponibilidadOperadores](IdOperador, FechaConexion);
    CREATE NONCLUSTERED INDEX IX_DisponibilidadOperadores_Estado ON [fab].[DisponibilidadOperadores](EstadoDisponibilidad, FechaConexion)
        WHERE EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA');
    
    PRINT '✓ Tabla DisponibilidadOperadores creada';
END


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


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD MotivoBloqueoFabricas VARCHAR(50) NULL;
    PRINT '✓ Columna MotivoBloqueoFabricas añadida a KCRM_CadenaCreditos';
END


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD FechaCancelacionFabricas DATETIME2 NULL;
    PRINT '✓ Columna FechaCancelacionFabricas añadida a KCRM_CadenaCreditos';
END


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'QUAC.dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE QUAC.dbo.KCRM_CadenaCreditos ADD ElegibleReactivacion BIT NOT NULL DEFAULT 0;
    PRINT '✓ Columna ElegibleReactivacion añadida a KCRM_CadenaCreditos';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.3 NOTA: BERP_FABRICASOperadores ya no es modificada
-- ─────────────────────────────────────────────────────────────────────────────
-- Se han creado nuevas tablas fab.OperadoresFabrica y fab.DisponibilidadOperadores
-- para reemplazar el modelo anterior. Ver Sección 3.8 (nuevas tablas de operadores).



-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 3: TABLAS TRANSACCIONALES
-- ==============================================================================
-- Estas tablas registran las operaciones del proceso de originación de crédito.
-- Dependen de las tablas de configuración creadas anteriormente.

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.1 EstudiosCredito: Tabla central que orquesta el flujo
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EstudiosCredito') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EstudiosCredito] (
        IdEstudio               BIGINT IDENTITY(1,1) NOT NULL,
        
        -- Referencia al cliente (terceros)
        NitTercero              VARCHAR(20)         NOT NULL,
        NitComercio             VARCHAR(20)         NOT NULL,   -- NIT del comercio donde se origina el cupo
        CelularCliente          VARCHAR(20)         NULL,       -- GAP-03: Celular del cliente para envío de OTP (SMS/WhatsApp)
        
        -- Referencias a entidades existentes
        IdBodega               INT                 NULL,       -- FK a QUAC.dbo.bodegas.id
        IdAsesor               INT                 NULL,       -- FK a fab.OperadoresFabrica.IdOperador
        NitAsesor              VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del asesor en el momento del estudio
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
        RenunciaCupo           BIT                 NOT NULL DEFAULT 0, -- GAP-20: Marcación si el cliente solicita eliminar/renunciar a su cupo
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
        
        -- Control de concurrencia y trazabilidad distribuida (SA-07)
        EliminadoLogico        BIT                 NOT NULL DEFAULT 0,   -- Soft delete: cierra el estudio sin borrar históricos
        IdCorrelacion          VARCHAR(64)         NULL,                  -- Correlation-ID del request HTTP original
        IdEscalamientoActivo   BIGINT              NULL,                  -- FK lógica → EscalamientosFabrica (FK física genera circular ref)
        
        -- Fotografías — resumen desnormalizado para gate de aprobación (PH-06)
        FotografiasAprobadas   INT                 NOT NULL DEFAULT 0,   -- Contador desnormalizado: 0-3. Gate: = 3 para aprobar crédito
        EstadoRevisionFotos    VARCHAR(15)         NOT NULL DEFAULT 'PENDIENTE',  -- PENDIENTE, EN_REVISION, APROBADO, CON_RECHAZOS
        
        -- Validación biométrica del asesor que inició la sesión (C-04)
        IdValidacionAsesor     BIGINT              NULL,                  -- FK → ValidacionesAsesor.IdValidacion (NULL en canal WEB)
        
        CONSTRAINT PK_EstudiosCredito PRIMARY KEY (IdEstudio),
        CONSTRAINT FK_EstudiosCredito_Estado FOREIGN KEY (IdEstadoActual) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_EstudiosCredito_Paso FOREIGN KEY (IdPasoActual) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT FK_EstudiosCredito_Canal FOREIGN KEY (IdCanal) REFERENCES [cat].[CatalogoCanalesOrigen](IdCanal),  -- G-DB-01
        CONSTRAINT FK_EstudiosCredito_Tercero FOREIGN KEY (NitTercero) REFERENCES [fab].[TercerosFabricas](NitTercero),  -- G-DB-02
        CONSTRAINT CK_EstudiosCredito_TipoCierre CHECK (TipoCierre IS NULL OR TipoCierre IN ('EXPRESS','NORMAL','FABRICA')),  -- GT-04
        CONSTRAINT CK_EstudiosCredito_EstadoRevisionFotos CHECK (EstadoRevisionFotos IN ('PENDIENTE','EN_REVISION','APROBADO','CON_RECHAZOS'))  -- PH-06
    );
    
    CREATE INDEX IX_EstudiosCredito_Cliente ON [fab].[EstudiosCredito](NitTercero);
    CREATE INDEX IX_EstudiosCredito_NitComercio ON [fab].[EstudiosCredito](NitComercio);
    CREATE INDEX IX_EstudiosCredito_Estado ON [fab].[EstudiosCredito](IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_Asesor ON [fab].[EstudiosCredito](IdAsesor) WHERE IdAsesor IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_Bodega ON [fab].[EstudiosCredito](IdBodega) WHERE IdBodega IS NOT NULL;  -- C-02: renombrado de IX_EstudiosCredito_Tienda
    CREATE INDEX IX_EstudiosCredito_Canal ON [fab].[EstudiosCredito](IdCanal) WHERE IdCanal IS NOT NULL;  -- G-DB-01
    CREATE INDEX IX_EstudiosCredito_FechaInicio ON [fab].[EstudiosCredito](FechaInicio);
    CREATE INDEX IX_EstudiosCredito_ClienteFecha ON [fab].[EstudiosCredito](NitTercero, FechaInicio) INCLUDE (IdEstadoActual);
    CREATE INDEX IX_EstudiosCredito_CallCenter ON [fab].[EstudiosCredito](RequiereCallCenter, IdEstadoActual) WHERE RequiereCallCenter = 1;
    CREATE INDEX IX_EstudiosCredito_SlugWeb ON [fab].[EstudiosCredito](SlugPasoWeb) WHERE SlugPasoWeb IS NOT NULL;  -- G-DB-07
    CREATE INDEX IX_EstudiosCredito_Correlacion ON [fab].[EstudiosCredito](IdCorrelacion) WHERE IdCorrelacion IS NOT NULL;  -- SA-07
    CREATE INDEX IX_EstudiosCredito_RevisionFotos ON [fab].[EstudiosCredito](EstadoRevisionFotos, IdEstadoActual)  -- PH-06
        WHERE EstadoRevisionFotos IN ('EN_REVISION','CON_RECHAZOS');
    CREATE INDEX IX_EstudiosCredito_ValidacionAsesor ON [fab].[EstudiosCredito](IdValidacionAsesor)  -- C-04
        WHERE IdValidacionAsesor IS NOT NULL;
    CREATE INDEX IX_EstudiosCredito_EscalamientoActivo ON [fab].[EstudiosCredito](IdEscalamientoActivo)  -- GAP-12
        WHERE IdEscalamientoActivo IS NOT NULL;
    
    PRINT '✓ Tabla EstudiosCredito creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.2 RetosSeguridad: OTP, tokenización y retos de verificación
-- ─────────────────────────────────────────────────────────────────────────────
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
        
        -- G-DB-05: Seguimiento de reenvíos del token
        NumeroReenvios      INT                 NOT NULL DEFAULT 0,   -- Cantidad de veces que se reenvió el token
        UltimoReenvio       DATETIME2(3)        NULL,                  -- Fecha y hora del último reenvío realizado
        
        -- SA-09: Dirección exacta a la que se envió el token (puede diferir si hubo cambio de email)
        DireccionEnvio      NVARCHAR(200)       NULL,   -- Email o celular exacto al que se envió el token
        
        CONSTRAINT PK_RetosSeguridad PRIMARY KEY (IdReto),
        CONSTRAINT FK_RetosSeguridad_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_RetosSeguridad_Canal CHECK (CanalEnvio IN ('WHATSAPP','EMAIL','SMS'))
    );
    
    CREATE INDEX IX_RetosSeguridad_ClienteFecha ON [fab].[RetosSeguridad](NitTercero, FechaEnvio);
    CREATE INDEX IX_RetosSeguridad_Estudio ON [fab].[RetosSeguridad](IdEstudio);
    
    PRINT '✓ Tabla RetosSeguridad creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.3 EvaluacionesRiesgo: Listas restrictivas, buró, Preselecta, FOSYGA
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EvaluacionesRiesgo] (
        IdEvaluacion                BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                  BIGINT              NOT NULL,
        IdPaso                     INT                 NULL,
        TipoEvaluacion             VARCHAR(30)         NOT NULL,
        
        -- Resultados clave
        CoincidenciaListasRestrictivas BIT            NOT NULL DEFAULT 0,
        ScoreBuro                  INT                 NULL,
        MoraComerciosAliados       BIT                 NULL,       -- GAP-21: Validación si presenta mora en otros comercios
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
        CONSTRAINT FK_EvaluacionesRiesgo_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_EvaluacionesRiesgo_Paso FOREIGN KEY (IdPaso) REFERENCES [cfg].[PasosEstudio](IdPaso),
        -- G-DB-03: Ampliado para incluir ANTECEDENTES y UBICA
        CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (TipoEvaluacion IN ('LISTAS','BURO','PRESELECTA','FOSYGA','ANTECEDENTES','UBICA')),
        CONSTRAINT CK_EvaluacionesRiesgo_Resultado CHECK (Resultado IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR'))
    );
    
    CREATE INDEX IX_EvaluacionesRiesgo_Estudio ON [fab].[EvaluacionesRiesgo](IdEstudio);
    CREATE INDEX IX_EvaluacionesRiesgo_Tipo ON [fab].[EvaluacionesRiesgo](TipoEvaluacion, Resultado);
    
    PRINT '✓ Tabla EvaluacionesRiesgo creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.4 RegistrosBiometria: Biometría facial, OCR, prueba de vida
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.RegistrosBiometria') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[RegistrosBiometria] (
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
        
        -- PH-07: FKs directas a las fotografías usadas en Rekognition
        -- (FotografiasEstudio se crea en Sección 7 — FKs físicas se añaden como ALTER posterior)
        IdFotografiaFrontal     BIGINT              NULL,   -- FK → FotografiasEstudio (FOTO_FRONTAL_DOC usada en Rekognition)
        IdFotografiaReverso     BIGINT              NULL,   -- FK → FotografiasEstudio (FOTO_TRASERA_DOC usada en OCR)
        IdFotografiaSelfie      BIGINT              NULL,   -- FK → FotografiasEstudio (SELFIE usada en CompareFaces/DetectFaces)
        
        CONSTRAINT PK_RegistrosBiometria PRIMARY KEY (IdBiometria),
        CONSTRAINT FK_RegistrosBiometria_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_RegistrosBiometria_Tipo CHECK (TipoVerificacion IN ('ONBOARDING','AUTENTICACION','PRUEBA_VIDA_HANDOFF')),  -- GAP-13: añadido PRUEBA_VIDA_HANDOFF
        CONSTRAINT CK_RegistrosBiometria_Estado CHECK (EstadoProceso IN ('EXITOSO','FALLIDO','REVISION_MANUAL'))
    );
    
    CREATE INDEX IX_RegistrosBiometria_Estudio ON [fab].[RegistrosBiometria](IdEstudio);
    CREATE INDEX IX_RegistrosBiometria_FotoFrontal ON [fab].[RegistrosBiometria](IdFotografiaFrontal)
        WHERE IdFotografiaFrontal IS NOT NULL;   -- PH-07
    CREATE INDEX IX_RegistrosBiometria_FotoReverso ON [fab].[RegistrosBiometria](IdFotografiaReverso)
        WHERE IdFotografiaReverso IS NOT NULL;   -- PH-07
    CREATE INDEX IX_RegistrosBiometria_FotoSelfie ON [fab].[RegistrosBiometria](IdFotografiaSelfie)
        WHERE IdFotografiaSelfie IS NOT NULL;    -- PH-07
    
    PRINT '✓ Tabla RegistrosBiometria creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 3.5 ValidacionesContactabilidad: UBICA y gestión manual
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ValidacionesContactabilidad') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[ValidacionesContactabilidad] (
        IdValidacion              BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio                 BIGINT              NOT NULL,
        ScoreUbica                VARCHAR(30)         NULL,
        EsActivacionAutomatica    BIT                 NOT NULL DEFAULT 0,
        
        -- G-DB-04: Estado granular de UBICA para enrutamiento preciso
        EstadoUbica               VARCHAR(30)         NULL,   -- Estado detallado retornado por UBICA
        
        -- Gestión manual
        EstadoVerificacionManual  VARCHAR(20)         NULL,
        IdAsesor                 INT                 NULL,
        NitAsesor                VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del asesor en el momento de la verificación
        ComentariosAgente         NVARCHAR(500)       NULL,
        
        -- SA-10: Vínculo con alerta de fraude (FK física añadida tras crear AlertasFraude en Sección 5)
        IdAlertaFraude            BIGINT              NULL,   -- FK → AlertasFraude (si esta validación generó o está asociada a una alerta)
        
        FechaVerificacion         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ValidacionesContactabilidad PRIMARY KEY (IdValidacion),
        CONSTRAINT FK_ValidContact_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
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
    
    CREATE INDEX IX_ValidContact_Estudio ON [fab].[ValidacionesContactabilidad](IdEstudio);
    CREATE INDEX IX_ValidContact_Pendientes ON [fab].[ValidacionesContactabilidad](EstadoVerificacionManual) 
        WHERE EstadoVerificacionManual = 'PENDIENTE';
    CREATE INDEX IX_ValidContact_EstadoUbica ON [fab].[ValidacionesContactabilidad](EstadoUbica)  -- G-DB-04
        WHERE EstadoUbica IS NOT NULL;
    CREATE INDEX IX_ValidContact_AlertaFraude ON [fab].[ValidacionesContactabilidad](IdAlertaFraude)  -- SA-10
        WHERE IdAlertaFraude IS NOT NULL;
    
    PRINT '✓ Tabla ValidacionesContactabilidad creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.6 ConsentimientosLegales: Trazabilidad de aceptaciones
-- ─────────────────────────────────────────────────────────────────────────────
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
        
        -- G-DB-09: Tipo de firma utilizado para el consentimiento
        TipoFirma            VARCHAR(20)         NOT NULL DEFAULT 'CHECKBOX',
        
        FechaAceptacion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_ConsentimientosLegales PRIMARY KEY (IdConsentimiento),
        CONSTRAINT FK_Consentimientos_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        -- G-DB-09: Tipos de firma admitidos
        CONSTRAINT CK_Consentimientos_TipoFirma CHECK (
            TipoFirma IN ('OTP_SMS','OTP_EMAIL','OTP_WHATSAPP','CHECKBOX','FIRMA_DIGITAL')
        )
    );
    
    CREATE INDEX IX_Consentimientos_Estudio ON [fab].[ConsentimientosLegales](IdEstudio);
    CREATE INDEX IX_Consentimientos_Cliente ON [fab].[ConsentimientosLegales](NitTercero);
    
    PRINT '✓ Tabla ConsentimientosLegales creada';
END

-- ─────────────────────────────────────────────────────────────────────────────
-- 3.7 EvidenciasFabrica: Archivos adjuntos y evidencias para revisión manual
--     GT-08: Tabla de evidencias/adjuntos para el proceso de revisión en fábrica
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EvidenciasFabrica') AND type in (N'U'))
BEGIN
    CREATE TABLE [fab].[EvidenciasFabrica] (
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
        NitSubidoPor        VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del usuario que subió la evidencia
        Observaciones       NVARCHAR(500)           NULL,       -- Notas adicionales del asesor o sistema
        
        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),  -- GAP-11: GETDATE() estándar
        
        CONSTRAINT PK_EvidenciasFabrica PRIMARY KEY (IdEvidencia),
        CONSTRAINT FK_EvidenciasFabrica_Estudio FOREIGN KEY (IdEstudioCredito) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_EvidenciasFabrica_Tipo CHECK (
            TipoEvidencia IN ('COMPROBANTE','NOTA_ASESOR','DOCUMENTO_SOPORTE','OTRO')  -- GAP-07: FOTO_DOCUMENTO y SELFIE eliminados; fotos van a FotografiasEstudio
        )
    );
    
    -- Índice principal para consultas por estudio
    CREATE INDEX IX_EvidenciasFabrica_Estudio ON [fab].[EvidenciasFabrica](IdEstudioCredito);
    -- Índice para filtrar por tipo de evidencia dentro de un estudio
    CREATE INDEX IX_EvidenciasFabrica_EstudioTipo ON [fab].[EvidenciasFabrica](IdEstudioCredito, TipoEvidencia);
    -- Índice para auditoría por usuario que subió el archivo
    CREATE INDEX IX_EvidenciasFabrica_SubidoPor ON [fab].[EvidenciasFabrica](SubidoPor, FechaCreacion);
    
    PRINT '✓ Tabla EvidenciasFabrica creada';
END



-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 4: TABLAS DE AUDITORÍA (TRAZABILIDAD INMUTABLE)
-- ==============================================================================
-- Estas tablas registran todos los cambios y son de solo INSERT.
-- Fundamental para auditoría, debugging y cumplimiento regulatorio.

-- ─────────────────────────────────────────────────────────────────────────────
-- 4.1 HistorialEstados: Máquina de estados inmutable
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.HistorialEstados') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[HistorialEstados] (
        IdHistorial         BIGINT IDENTITY(1,1) NOT NULL,
        IdEstudio           BIGINT              NOT NULL,
        IdEstadoAnterior    INT                 NULL,
        IdEstadoNuevo       INT                 NOT NULL,
        IdPasoRelacionado   INT                 NULL,
        
        -- Quién y por qué
        IdUsuarioAccion     INT                 NULL,
        NitAsesor           VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del operador que realizó la transición
        TipoUsuario         VARCHAR(20)         NOT NULL DEFAULT 'SISTEMA',
        MotivoTransicion    NVARCHAR(500)       NULL,
        
        -- SA-08: Correlation-ID propagado desde el request para trazabilidad distribuida
        IdCorrelacion       VARCHAR(64)         NULL,   -- Correlation-ID propagado desde el request
        
        FechaTransicion     DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        
        CONSTRAINT PK_HistorialEstados PRIMARY KEY (IdHistorial),
        CONSTRAINT FK_Hist_Request FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_Hist_EstAnterior FOREIGN KEY (IdEstadoAnterior) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_Hist_EstNuevo FOREIGN KEY (IdEstadoNuevo) REFERENCES [cfg].[CatalogoEstados](IdEstado),
        CONSTRAINT FK_Hist_Paso FOREIGN KEY (IdPasoRelacionado) REFERENCES [cfg].[PasosEstudio](IdPaso),
        CONSTRAINT CK_HistorialEstados_TipoUsr CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CALL_CENTER','CLIENTE','ADMINISTRADOR'))  -- GAP-02: añadidos CLIENTE y ADMINISTRADOR
    );
    
    CREATE INDEX IX_HistorialEstados_Estudio ON [aud].[HistorialEstados](IdEstudio, FechaTransicion);
    CREATE INDEX IX_HistorialEstados_EstadoFecha ON [aud].[HistorialEstados](IdEstadoNuevo, FechaTransicion);
    
    PRINT '✓ Tabla HistorialEstados creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.2 AuditoriaCambiosDatos: Registro de cambios en datos mutables
-- ─────────────────────────────────────────────────────────────────────────────
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
        CONSTRAINT CK_AuditoriaCambiosDatos_TipoUsuario CHECK (TipoUsuario IN ('SISTEMA','ASESOR','CLIENTE','ADMINISTRADOR'))  -- GAP-08
    );
    
    CREATE INDEX IX_AuditoriaCambiosDatos_Cliente ON [aud].[AuditoriaCambiosDatos](NitTercero, FechaCambio);
    CREATE INDEX IX_AuditoriaCambiosDatos_Estudio ON [aud].[AuditoriaCambiosDatos](IdEstudio) WHERE IdEstudio IS NOT NULL;
    
    PRINT '✓ Tabla AuditoriaCambiosDatos creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.3 RegistroServiciosExternos: Logging de invocaciones a servicios
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.RegistroServiciosExternos') AND type in (N'U'))
BEGIN
    CREATE TABLE [aud].[RegistroServiciosExternos] (
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
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 5: PARCHES V2.2 — GAPS DEL ESCENARIO DE ESTRÉS (Architect Audit)
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
--   SA-07: ALTER EstudiosCredito        — IdEscalamiento + EliminadoLogico + IdCorrelacion
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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoReglasFraude') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoReglasFraude] (
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.2  CatalogoMotivosEscalamiento — tipificación de razones de escalamiento manual
--      SA-01: Tabla de dominio para EscalamientosFabrica.IdMotivoEscalamiento
--
--      Justificación: sin este catálogo, el motivo sería texto libre en
--      HistorialEstados.MotivoTransicion. El asesor no puede filtrar ni el
--      sistema puede disparar reglas sobre texto libre. Este catálogo permite
--      dashboards de volumen por motivo y SLA diferenciados por tipo.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cat.CatalogoMotivosEscalamiento') AND type = N'U')
BEGIN
    CREATE TABLE [cat].[CatalogoMotivosEscalamiento] (
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.3  AlertasFraude — registro inmutable de alertas disparadas por reglas de negocio
--      SA-05: Tabla INSERT-ONLY. Una alerta no se cierra ni modifica; se crea
--             una nueva con AccionTomada = 'DESCARTADA' si el asesor la descarta.
--
--      Permite al asesor ver: CUÁNTAS alertas disparó este estudio, CUÁL regla
--      las generó, CUÁNDO, y QUÉ datos contextuales dispararon la alerta.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.AlertasFraude') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[AlertasFraude] (
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
        IdAsesor            INT                 NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador
        NitAsesor           VARCHAR(20)         NULL,       -- GAP-19: CC inmutable del operador que resolvió la alerta
        NotasResolucion     NVARCHAR(500)       NULL,
        FechaResolucion     DATETIME2(3)        NULL,

        FechaAlerta         DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.EscalamientosFabrica') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[EscalamientosFabrica] (
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
        IdAsesor                INT                     NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador (si fue manual)
        NitAsesor               VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del operador que escaló
        
        -- Resolución
        IdAsesorAsignado        INT                     NULL,       -- FK lógica a fab.OperadoresFabrica.IdOperador
        NitAsesorAsignado       VARCHAR(20)             NULL,       -- GAP-19: CC inmutable del asesor asignado
        FechaAsignacion         DATETIME2(3)            NULL,
        EstadoEscalamiento      VARCHAR(20)             NOT NULL DEFAULT 'ABIERTO',  -- ABIERTO, EN_GESTION, RESUELTO, CERRADO_SIN_RESOLUCION
        ResultadoGestion        VARCHAR(20)             NULL,       -- APROBADO, RECHAZADO, DEVUELTO_FLUJO
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.5  LogValidacionesOTP — log granular de cada intento individual de OTP
--      SA-03: RetosSeguridad registra el RETO (un token). Esta tabla registra
--             cada INTENTO individual de validación: correcto, fallido, expirado.
--
--      CRÍTICO: La columna RetosSeguridad.NumeroIntentos es un contador, no un log.
--      No permite reconstruir "intento 1 falló a las 10:01, intento 2 expiró a las 10:06"
--      ni vincular un intento fallido específico con el cambio de email subsiguiente.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.LogValidacionesOTP') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[LogValidacionesOTP] (
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
        CONSTRAINT FK_LogOTP_Reto FOREIGN KEY (IdReto) REFERENCES [fab].[RetosSeguridad](IdReto),
        CONSTRAINT FK_LogOTP_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT CK_LogOTP_Resultado CHECK (ResultadoIntento IN ('EXITOSO','FALLIDO_HASH','EXPIRADO','CANCELADO'))
    );

    CREATE INDEX IX_LogOTP_Reto ON [aud].[LogValidacionesOTP](IdReto, NumeroIntento);
    CREATE INDEX IX_LogOTP_Estudio ON [aud].[LogValidacionesOTP](IdEstudio, FechaIntento);
    CREATE INDEX IX_LogOTP_Cliente ON [aud].[LogValidacionesOTP](NitTercero, FechaIntento);

    PRINT '✓ Tabla LogValidacionesOTP creada';
END


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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'aud.HistorialDatosSensibles') AND type = N'U')
BEGIN
    CREATE TABLE [aud].[HistorialDatosSensibles] (
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
        CONSTRAINT FK_HistDatosSensibles_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_HistDatosSensibles_Reto FOREIGN KEY (IdRetoActivoAlCambio) REFERENCES [fab].[RetosSeguridad](IdReto),
        CONSTRAINT CK_HistDatosSensibles_Actor CHECK (TipoActor IN ('CLIENTE','ASESOR','SISTEMA'))
    );

    CREATE INDEX IX_HistDatosSensibles_Estudio ON [aud].[HistorialDatosSensibles](IdEstudio, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_Cliente ON [aud].[HistorialDatosSensibles](NitTercero, FechaCambio);
    CREATE INDEX IX_HistDatosSensibles_PostOTP ON [aud].[HistorialDatosSensibles](IdEstudio, EsPostFalloOTP)
        WHERE EsPostFalloOTP = 1;   -- Índice filtrado para detección rápida de patrón de fraude

    PRINT '✓ Tabla HistorialDatosSensibles creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.7  EstudiosCredito — columnas de control incorporadas en CREATE TABLE
--      SA-07: EliminadoLogico, IdCorrelacion e IdEscalamientoActivo ya están
--             definidos directamente en el CREATE TABLE de la Sección 3.1.
--             la máquina de estados y las reglas de negocio del servicio ya
--             previenen duplicados sin necesidad de control en base de datos.
-- ─────────────────────────────────────────────────────────────────────────────
-- (sin ALTER TABLE — columnas consolidadas en CREATE TABLE, Sección 3.1)


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.8  HistorialEstados — IdCorrelacion incorporado en CREATE TABLE
--      SA-08: La columna IdCorrelacion ya está definida directamente en el
--             CREATE TABLE de HistorialEstados (Sección 4.1).
-- ─────────────────────────────────────────────────────────────────────────────
-- (sin ALTER TABLE — columna consolidada en CREATE TABLE, Sección 4.1)


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.9  RetosSeguridad — DireccionEnvio incorporada en CREATE TABLE
--      SA-09: La columna DireccionEnvio ya está definida directamente en el
--             CREATE TABLE de RetosSeguridad (Sección 3.2).
-- ─────────────────────────────────────────────────────────────────────────────
-- (sin ALTER TABLE — columna consolidada en CREATE TABLE, Sección 3.2)


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.10 ValidacionesContactabilidad — IdAlertaFraude y FK física (SA-10)
--      La columna IdAlertaFraude ya está definida en el CREATE TABLE (Sección 3.5).
--      La FK física se añade aquí como ALTER porque AlertasFraude se crea en la
--      Sección 5.3, DESPUÉS de ValidacionesContactabilidad — dependencia forward.
-- ─────────────────────────────────────────────────────────────────────────────

-- Añadir FK para IdAlertaFraude (AlertasFraude ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.ValidacionesContactabilidad')
      AND name = 'FK_ValidContact_AlertaFraude'
)
BEGIN
    ALTER TABLE ValidacionesContactabilidad
        ADD CONSTRAINT FK_ValidContact_AlertaFraude
        FOREIGN KEY (IdAlertaFraude) REFERENCES [aud].[AlertasFraude](IdAlerta);
    PRINT '✓ ValidacionesContactabilidad: FK FK_ValidContact_AlertaFraude añadida';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.11 NUEVO ESTADO: REVISION_FABRICA — estado faltante en CatalogoEstados
--      CRÍTICO: El escenario de estrés requiere un estado para "en revisión manual
--      por la fábrica de crédito". El estado PENDIENTE_CALL es para call center,
--      no para revisión por asesor de fábrica.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'REVISION_FABRICA')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('REVISION_FABRICA', 'En Revisión Manual — Fábrica de Crédito', 'PROCESO', 0, 0,
            'Estudio derivado a revisión manual por asesor de fábrica de crédito, usualmente por alerta de fraude o anomalía en el flujo');
    PRINT '✓ Estado REVISION_FABRICA insertado en CatalogoEstados';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.12 NUEVO ESTADO: BLOQUEADO_FRAUDE — estado terminal por sospecha de fraude
--      Permite cerrar un estudio por sospecha de fraude confirmada sin rechazarlo
--      por razones de riesgo crediticio (son categorizaciones distintas).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'BLOQUEADO_FRAUDE')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('BLOQUEADO_FRAUDE', 'Bloqueado por Sospecha de Fraude', 'TERMINAL', 1, 0,
            'Solicitud bloqueada por detección de patrón de fraude. Requiere investigación por área de seguridad.');
    PRINT '✓ Estado BLOQUEADO_FRAUDE insertado en CatalogoEstados';
END


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
    INSERT INTO [cfg].[FasesEstudio] (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
    ('IDENTIFICACION',          'Identificación del Cliente',       1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
    ('DATOS_CLIENTE',           'Datos del Cliente',                2, 'Captura o actualización de datos personales y de contacto'),
    ('CONSENTIMIENTO_LEGAL',    'Consentimiento Legal',             3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
    ('VALIDACIONES_RIESGO',     'Validaciones de Riesgo',           4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
    ('LIMITE_CREDITO',          'Límite de Crédito',                5, 'Cálculo y presentación del cupo preaprobado'),
    ('VERIFICACION_IDENTIDAD',  'Verificación de Identidad',        6, 'Biometría facial, OCR de documento, prueba de vida'),
    ('ACTIVACION',              'Activación del Cupo',              7, 'Validación UBICA, activación automática o gestión manual Call Center');
    
    PRINT '✓ Seeds insertados en FasesEstudio';
END


-- ==============================================================================
-- SECCIÓN 6.2 (ACTUALIZADA): ESTADOS DEL PROCESO DE CRÉDITO
-- Total: 23 estados — cubre pre-estudio, estudo formal, reactivarón y rechazos específicos
-- ==============================================================================
-- AGRUPACIÓN POR GRUPO:
--   INICIAL     = Estados de entrada (antes de Preselecta)
--   PROCESO     = Estados transaccionales mientras el estudio está activo
--   TERMINAL    = Estados de cierre (viables y no viables)
--   BLOQUEO     = Estados de bloqueo (cupo activo, mora, fraude)
--   REACTIVACION= Estados de reactivación de cupos cancelados
--
--  NUEVOS ESTADOS v2.6:
--    - CUPO_YA_ACTIVO, DESBLOQUEADO, REACTIVADO
--    - NO_APLICA_MORA, NO_VIABLE_ANTECEDENTES_PREVIO, EXPIRADO_PREVIO
--    - NO_VIABLE_ANTECEDENTES, NO_VIABLE_CENTRALES, NO_APLICA_CUPO
--    - PENDIENTE_VALIDACION_AUTOMATICA, EN_FABRICA
--
--  NOTA: Se insertan de uno en uno para compatibilidad con datos existentes
--        (el bulk insert IF NOT EXISTS no funciona si ya hay datos de versiones anteriores)
-- ─────────────────────────────────────────────────────────────────────────────

 -- INICIAL: Borrador (validación previa)
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'BORRADOR')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('BORRADOR', 'En Validación Previa', 'INICIAL', 0, 0,
     'El cliente se encuentra en pasos iniciales: identificación, creación, validacion de cupo o preparacion para estudio.');
    PRINT '✓ Estado BORRADOR insertado';
END

 -- INICIAL: Pendiente Cliente Previo
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_CLIENTE_PREVIO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_CLIENTE_PREVIO', 'Pendiente Cliente — Previo', 'INICIAL', 0, 1,
     'Se requiere una accion del cliente antes de crear la solicitud formal: completar datos, corregir correo, recibir token, validar identidad, etc.');
    PRINT '✓ Estado PENDIENTE_CLIENTE_PREVIO insertado';
END

 -- INICIAL: Expirado Previo
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'EXPIRADO_PREVIO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('EXPIRADO_PREVIO', 'Expirada — Previo', 'INICIAL', 1, 0,
     'El proceso previo no continuo dentro del tiempo permitido o agoto intentos criticos antes de solicitud formal.');
    PRINT '✓ Estado EXPIRADO_PREVIO insertado';
END

 -- BLOQUEO: Cupo Ya Activo
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'CUPO_YA_ACTIVO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('CUPO_YA_ACTIVO', 'Cupo Ya Activo', 'BLOQUEO', 1, 0,
     'El cliente ya cuenta con cupo disponible y no requiere nuevo estudio.');
    PRINT '✓ Estado CUPO_YA_ACTIVO insertado';
END

 -- BLOQUEO: No Aplica Por Mora
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'NO_APLICA_MORA')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('NO_APLICA_MORA', 'No Aplica — Por Mora', 'BLOQUEO', 1, 0,
     'No puede continuar por cartera en mora u otra restriccion previa.');
    PRINT '✓ Estado NO_APLICA_MORA insertado';
END

 -- REACTIVACION: Desbloqueado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'DESBLOQUEADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('DESBLOQUEADO', 'Desbloqueado', 'REACTIVACION', 0, 0,
     'Se rehabilito un cupo bloqueado sin iniciar una nueva solicitud formal.');
    PRINT '✓ Estado DESBLOQUEADO insertado';
END

 -- REACTIVACION: Reactivado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'REACTIVADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('REACTIVADO', 'Reactivado', 'REACTIVACION', 0, 0,
     'Se reactivo un cupo eliminado previamente bajo reglas definidas.');
    PRINT '✓ Estado REACTIVADO insertado';
END

 -- PROCESO: En Progreso
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'EN_PROGRESO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('EN_PROGRESO', 'En Proceso', 'PROCESO', 0, 1,
     'La solicitud avanza normalmente entre validaciones, reglas y bloques del flujo.');
    PRINT '✓ Estado EN_PROGRESO insertado';
END

 -- PROCESO: Pausado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PAUSADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PAUSADO', 'Pausado', 'PROCESO', 0, 0,
     'El cliente se retiro de la tienda o del portal; estudio en espera de reanudacion.');
    PRINT '✓ Estado PAUSADO insertado';
END

 -- PROCESO: Pendiente Cliente
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_CLIENTE')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_CLIENTE', 'Pendiente Cliente', 'PROCESO', 0, 1,
     'Se requiere accion del cliente para continuar: direccion, captura documental, biometria, token final, etc.');
    PRINT '✓ Estado PENDIENTE_CLIENTE insertado';
END

 -- PROCESO: Pendiente OTP
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_OTP')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_OTP', 'Pendiente Validacion OTP', 'PROCESO', 0, 1,
     'Esperando que el cliente valide el token de seguridad.');
    PRINT '✓ Estado PENDIENTE_OTP insertado';
END

 -- PROCESO: Pendiente Biometria
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_BIOMETRIA')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_BIOMETRIA', 'Pendiente Biometria', 'PROCESO', 0, 1,
     'Esperando captura y validacion biometrica.');
    PRINT '✓ Estado PENDIENTE_BIOMETRIA insertado';
END

 -- PROCESO: Pendiente Fotos
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_FOTOS')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_FOTOS', 'Pendiente Envio de Fotos', 'PROCESO', 0, 1,
     'Esperando que el cliente envie fotos para validacion manual.');
    PRINT '✓ Estado PENDIENTE_FOTOS insertado';
END

 -- PROCESO: Fotos en Revision
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'FOTOS_EN_REVISION')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('FOTOS_EN_REVISION', 'Fotos en Revision Manual', 'PROCESO', 0, 0,
     'Fotos recibidas, en revision manual por el equipo de credito.');
    PRINT '✓ Estado FOTOS_EN_REVISION insertado';
END

 -- PROCESO: Pendiente Validacion Automatica
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('PENDIENTE_VALIDACION_AUTOMATICA', 'Pendiente Validacion Automatica', 'PROCESO', 0, 1,
     'La solicitud esta esperando respuesta de motores, integraciones o procesos automaticos externos.');
    PRINT '✓ Estado PENDIENTE_VALIDACION_AUTOMATICA insertado';
END

 -- PROCESO: En Fabrica
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'EN_FABRICA')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('EN_FABRICA', 'En Fabrica de Soporte', 'PROCESO', 0, 0,
     'Caso enviado a gestion manual por excepcion, novedad o validacion no concluyente.');
    PRINT '✓ Estado EN_FABRICA insertado';
END

 -- PROCESO: Cupo Preaprobado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'CUPO_PREAPROBADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('CUPO_PREAPROBADO', 'Cupo Preaprobado', 'PROCESO', 0, 1,
     'Cupo calculado exitosamente, pendiente verificacion de identidad.');
    PRINT '✓ Estado CUPO_PREAPROBADO insertado';
END

 -- PROCESO: Revision Fabrica (ya existe en secciones anteriores, no duplicar)
-- Este estado ya se inserta en seccion 5.11, aqui solo verificamos que exista para logs

 -- TERMINAL: Aprobado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'APROBADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES ('APROBADO', 'Cupo Activado', 'TERMINAL', 1, 0,
     'Solicitud aprobada y cupo activado exitosamente.');
    PRINT '✓ Estado APROBADO insertado';
END

 -- TERMINAL: Rechazado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'RECHAZADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('RECHAZADO','Rechazado','TERMINAL',1,0,'Solicitud rechazada por alguna validacion.');
    PRINT '✓ Estado RECHAZADO insertado';
END

 -- TERMINAL: No Viable Antecedentes Previo
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('NO_VIABLE_ANTECEDENTES_PREVIO','No Viable — Antecedentes (Previo)','TERMINAL',1,0,
     'Rechazo en validaciones previas por antecedentes o reportes negativos.');
    PRINT '✓ Estado NO_VIABLE_ANTECEDENTES_PREVIO insertado';
END

 -- TERMINAL: No Viable Antecedentes
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'NO_VIABLE_ANTECEDENTES')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('NO_VIABLE_ANTECEDENTES','No Viable — Antecedentes','TERMINAL',1,0,
     'Rechazo por antecedentes negativos en solicitud formal.');
    PRINT '✓ Estado NO_VIABLE_ANTECEDENTES insertado';
END

 -- TERMINAL: No Viable Centrales
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'NO_VIABLE_CENTRALES')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('NO_VIABLE_CENTRALES','No Viable — Centrales','TERMINAL',1,0,
     'Rechazo por modelo de viabilidad, centrales o preselecta.');
    PRINT '✓ Estado NO_VIABLE_CENTRALES insertado';
END

 -- TERMINAL: No Aplica Para Cupo
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'NO_APLICA_CUPO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('NO_APLICA_CUPO','No Aplica — Para Cupo','TERMINAL',1,0,
     'Cumple viabilidad base, pero no supera reglas complementarias definidas para otorgamiento.');
    PRINT '✓ Estado NO_APLICA_CUPO insertado';
END

 -- TERMINAL: Bloqueado Fraude (ya existe en secciones anteriores)

 -- TERMINAL: Expirado
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'EXPIRADO')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('EXPIRADO','Expirada','TERMINAL',1,0,'No retomo dentro del tiempo permitido.');
    PRINT '✓ Estado EXPIRADO insertado';
END

 -- TERMINAL: Cancelado Cliente
IF NOT EXISTS (SELECT 1 FROM CatalogoEstados WHERE Codigo = 'CANCELADO_CLIENTE')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo,Nombre,Grupo,EsTerminal,PermitePausa,Descripcion)
    VALUES ('CANCELADO_CLIENTE','Cancelada por Cliente','TERMINAL',1,0,
     'El cliente desistio voluntariamente durante la solicitud formal.');
    PRINT '✓ Estado CANCELADO_CLIENTE insertado';
END

PRINT '✓ Seeds v2.6 insertados en CatalogoEstados (23 estados)';


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.3 Insertar PasosEstudio (13 pasos)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM PasosEstudio)
BEGIN
    INSERT INTO [cfg].[PasosEstudio] (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, ServicioExterno, EsAutomatico, RequiereIntervencion, TiempoTimeoutSeg, Descripcion) VALUES
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.4 Insertar TransicionesEstado (transiciones válidas v2.6)
--      Usa códigos de estado para evitar dependencia de IDs hardcoded
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM TransicionesEstado)
BEGIN
    -- Transiciones desde BORRADOR (validación previa)
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Iniciar procesamiento del estudio'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'BORRADOR' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cancelación voluntaria antes de iniciar'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'BORRADOR' AND eDestino.Codigo = 'CANCELADO_CLIENTE';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente se retracta en validación previa'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'BORRADOR' AND eDestino.Codigo = 'PENDIENTE_CLIENTE_PREVIO';
    
    -- Transiciones desde PENDIENTE_CLIENTE_PREVIO
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente completa datos pendientes'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND eDestino.Codigo = 'BORRADOR';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cancelación voluntaria en previo'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND eDestino.Codigo = 'CANCELADO_CLIENTE';
    
    -- Transiciones desde EN_PROGRESO (estudio activo)
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente se retira, pausar estudio'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'PAUSADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Esperando validación OTP'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'PENDIENTE_OTP';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Esperando biométrica'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'PENDIENTE_BIOMETRIA';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Esperando fotos del cliente'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'PENDIENTE_FOTOS';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Esperando respuesta de servicio externo'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cupo preaprobado confirmado'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'CUPO_PREAPROBADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Todas las validaciones aprobadas'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'APROBADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Rechazado por validación de riesgo'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'RECHAZADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Rechazo por antecedentes'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'NO_VIABLE_ANTECEDENTES';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Rechazo por centrales/preselecta'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'NO_VIABLE_CENTRALES';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'No aplica para cupo: no supera reglas complementarias'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'NO_APLICA_CUPO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Derivar a fábrica de soporte'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'EN_FABRICA';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Fraude detectado'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'BLOQUEADO_FRAUDE';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cancelación voluntaria durante el proceso'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'CANCELADO_CLIENTE';
    
    -- Transiciones desde PAUSADO
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente regresa, reanudar estudio'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PAUSADO' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Estudio expiró por inactividad'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PAUSADO' AND eDestino.Codigo = 'EXPIRADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cancelación voluntaria mientras pausado'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PAUSADO' AND eDestino.Codigo = 'CANCELADO_CLIENTE';
    
    -- Transiciones desde PENDIENTE_OTP
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'OTP validado exitosamente'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_OTP' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente se retira, pausar'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_OTP' AND eDestino.Codigo = 'PAUSADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'OTP fallido, intentos agotados'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_OTP' AND eDestino.Codigo = 'RECHAZADO';
    
    -- Transiciones desde PENDIENTE_BIOMETRIA
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Biometría validada exitosamente'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_BIOMETRIA' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Cliente se retira, pausar'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_BIOMETRIA' AND eDestino.Codigo = 'PAUSADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Biometría fallida, derivar a fábrica'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_BIOMETRIA' AND eDestino.Codigo = 'EN_FABRICA';
    
    -- Transiciones desde PENDIENTE_FOTOS
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Fotos recibidas, en revisión'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_FOTOS' AND eDestino.Codigo = 'FOTOS_EN_REVISION';
    
    -- Transiciones desde FOTOS_EN_REVISION
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Asesor aprueba fotos: proceso se reanuda'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'FOTOS_EN_REVISION' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Asesor rechaza fotos: nueva solicitud'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'FOTOS_EN_REVISION' AND eDestino.Codigo = 'PENDIENTE_FOTOS';
    
    -- Transiciones desde EN_FABRICA
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Fábrica resuelve: reanudar flujo'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_FABRICA' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Fábrica determina rechazo'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_FABRICA' AND eDestino.Codigo = 'RECHAZADO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Fábrica detecta fraude'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_FABRICA' AND eDestino.Codigo = 'BLOQUEADO_FRAUDE';
    
    -- Transiciones desde PENDIENTE_VALIDACION_AUTOMATICA
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 0, 'Validación automática exitosa'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND eDestino.Codigo = 'EN_PROGRESO';
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Validación automática fallida'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND eDestino.Codigo = 'EN_FABRICA';
    
    -- Transiciones especiales de rechazos específicos
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT eOrigen.IdEstado, eDestino.IdEstado, 1, 'Preselecta rechaza por antecedentes'
    FROM CatalogoEstados eOrigen, CatalogoEstados eDestino
    WHERE eOrigen.Codigo = 'EN_PROGRESO' AND eDestino.Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO';
    
    PRINT '✓ Seeds v2.6 insertados en TransicionesEstado';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.5 Insertar ConfiguracionReglasNegocio (reglas iniciales)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio)
BEGIN
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.6 Insertar CatalogoCanalesOrigen (canales iniciales)
--     G-DB-01: Seeds para los 3 canales base del sistema
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoCanalesOrigen)
BEGIN
    INSERT INTO [cat].[CatalogoCanalesOrigen] (Codigo, Nombre, Descripcion, Activo) VALUES
    ('WEB',      'Canal Web',      'Originación a través del portal web o app del cliente',              1),
    ('TIENDA',   'Canal Tienda',   'Originación presencial en punto de venta asistida por asesor',       1),
    ('EXTERNO',  'Canal Externo',  'Originación por fuerza de ventas externas o aliados comerciales',    1);
    
    PRINT '✓ Seeds insertados en CatalogoCanalesOrigen';
END



-- ─────────────────────────────────────────────────────────────────────────────
-- 6.7 Insertar CatalogoReglasFraude (reglas de detección de fraude)
--     SA-06: Seeds para las reglas de fraude del escenario de estrés
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoReglasFraude)
BEGIN
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('DUPLICIDAD_EMAIL',
        'Email Duplicado',
        'El correo electrónico ya se encuentra registrado con otro tercero.',
        'MEDIO', 'NOTIFICAR'),
    ('DUPLICIDAD_CELULAR',
        'Celular Duplicado',
        'El número de celular ya se encuentra registrado con otro tercero.',
        'ALTO', 'BLOQUEAR'),
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.8 Insertar CatalogoMotivosEscalamiento (motivos de escalamiento a fábrica)
--     SA-01: Seeds para los motivos del escenario de estrés y casos comunes
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoMotivosEscalamiento)
BEGIN
    INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
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
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso, @IdRevFabrica, 1, 'Anomalía detectada: derivar a revisión manual por fábrica de crédito');
END

-- PENDIENTE_CALL → REVISION_FABRICA (call center escala a fábrica)
IF @IdPendCall IS NOT NULL AND @IdRevFabrica IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendCall AND IdEstadoDestino = @IdRevFabrica)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendCall, @IdRevFabrica, 1, 'Call center no puede resolver: escala a revisión fábrica');
END

-- REVISION_FABRICA → EN_PROGRESO (asesor resuelve, devuelve al flujo automático)
IF @IdRevFabrica IS NOT NULL AND @IdEnProgreso IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdEnProgreso)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdEnProgreso, 1, 'Asesor de fábrica resuelve: devolver al flujo automático');
END

-- REVISION_FABRICA → RECHAZADO (asesor rechaza)
IF @IdRevFabrica IS NOT NULL AND @IdRechazado IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdRechazado)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdRechazado, 1, 'Asesor de fábrica determina rechazo definitivo');
END

-- REVISION_FABRICA → BLOQUEADO_FRAUDE (asesor confirma fraude)
IF @IdRevFabrica IS NOT NULL AND @IdBloqFraude IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdRevFabrica AND IdEstadoDestino = @IdBloqFraude)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdRevFabrica, @IdBloqFraude, 1, 'Asesor de fábrica confirma sospecha de fraude');
END

-- EN_PROGRESO → BLOQUEADO_FRAUDE (sistema bloquea automáticamente por regla crítica)
IF @IdEnProgreso IS NOT NULL AND @IdBloqFraude IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdEnProgreso AND IdEstadoDestino = @IdBloqFraude)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso, @IdBloqFraude, 1, 'Regla de fraude crítica: bloqueo automático inmediato');
END

PRINT '✓ Transiciones para REVISION_FABRICA y BLOQUEADO_FRAUDE insertadas';


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.10 Insertar ConfiguracionReglasNegocio — parámetros adicionales para fraude y escalamiento
--      SA-11: Seeds de configuración para umbral de detección de fraude
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio WHERE Codigo = 'VENTANA_FRAUDE_OTP_MIN')
BEGIN
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
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
        'Número máximo de veces que el cliente puede solicitar reenvío del OTP sin que se cancele el reto'),
    ('VENTANA_REACTIVACION_CUPO_DIAS',
        'Ventana de eliminación para reactivación (días)',
        '30', 'INT', 'RIESGO',
        'Días permitidos para evaluar reactivación de un cupo tras haber sido eliminado por el cliente'),
    ('VENTANA_COMPRAS_RECIENTES_DIAS',
        'Ventana compras recientes ruta simplificada (días)',
        '60', 'INT', 'RIESGO',
        'Validar si el cliente realizó compras en los últimos X días para habilitar validación abreviada'),
    ('VENTANA_ACTUALIZACION_DATOS_DIAS',
        'Ventana actualización datos ruta simplificada (días)',
        '90', 'INT', 'RIESGO',
        'Días transcurridos sin cambios de correo y dirección para habilitar validación abreviada');

    PRINT '✓ Seeds adicionales insertados en ConfiguracionReglasNegocio';
END


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
    PRINT '✓ Tabla CatalogoTiposFotografia creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.2  FotografiasEstudio — tabla UNIFICADA de fotografías biométricas (GAP-07)
--      PH-02 + GAP-07: Rediseño completo. Una tabla para el ciclo de vida
--      completo de las 3 fotos obligatorias (Selfie, Frontal del documento,
--      Trasera del documento) con revisión, aprobación y datos biométricos.
--
--      Flujo de Prueba de Vida (orden):
--        1. SELFIE             — prueba de vida (persona real y viva)
--        2. DOCUMENTO_FRONTAL  — frente de la cédula (cara comparada con selfie)
--        3. DOCUMENTO_TRASERO  — reverso de la cédula (OCR complementario)
--
--      Reglas de negocio clave:
--        - El cliente DEBE tener exactamente 3 fotos APROBADAS (una de cada tipo)
--        - Puede haber MÁS de 3 filas por estudio (intentos fallidos, reemplazos)
--        - EsVigente = 1 solo para la foto activa de cada tipo (garantizado por UQ filtrado)
--        - UQ_FotografiasEstudio_Vigente: solo UNA foto vigente por tipo por estudio
--
--      BIGINT IDENTITY: alta cardinalidad (estudios × 3 tipos × versiones × reintentos)
-- ─────────────────────────────────────────────────────────────────────────────
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

    -- Garantiza UNA sola foto vigente por tipo por estudio (integridad del gate de aprobación)
    CREATE UNIQUE INDEX UQ_FotografiasEstudio_Vigente
        ON [fab].[FotografiasEstudio](IdEstudio, TipoFotografia)
        WHERE EsVigente = 1;

    PRINT '✓ Tabla FotografiasEstudio creada (GAP-07: diseño unificado biométrico)';
END


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
        CodigoMotivoRechazo VARCHAR(40)             NULL,       -- Código tipificado (del CHECK a continuación)
        NotasAdicionales    NVARCHAR(500)           NULL,       -- Observaciones opcionales del revisor

        FechaRevision       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        -- NUNCA UPDATE ni DELETE — tabla de solo INSERT

        CONSTRAINT PK_RevisionesFotografia  PRIMARY KEY (IdRevision),
        CONSTRAINT FK_RevisionesFotografia_Foto FOREIGN KEY (IdFotografia) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT FK_RevisionesFotografia_Estudio FOREIGN KEY (IdEstudio) REFERENCES [fab].[EstudiosCredito](IdEstudio),
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
        ON [aud].[RevisionesFotografia](IdFotografia, FechaRevision);

    -- Índice para dashboard de revisiones por estudio
    CREATE INDEX IX_RevisionesFotografia_Estudio
        ON [aud].[RevisionesFotografia](IdEstudio, FechaRevision);

    -- Índice para métricas de rendimiento del revisor
    CREATE INDEX IX_RevisionesFotografia_Revisor
        ON [aud].[RevisionesFotografia](IdRevisor, FechaRevision);

    -- Índice para filtrado rápido de rechazos (seguimiento de calidad)
    CREATE INDEX IX_RevisionesFotografia_Rechazos
        ON [aud].[RevisionesFotografia](CodigoMotivoRechazo, FechaRevision)
        WHERE DecisionRevision = 'RECHAZADA';

    PRINT '✓ Tabla RevisionesFotografia creada';
END


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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.SolicitudesRecarga') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[SolicitudesRecarga] (
        IdSolicitudRecarga  BIGINT IDENTITY(1,1)    NOT NULL,
        IdEstudio           BIGINT                  NOT NULL,   -- FK → EstudiosCredito
        IdTipoFoto          INT                     NULL,       -- FK → CatalogoTiposFotografia (qué foto se pide)
                                                                -- NULL cuando la recarga es por handoff biométrico, no fotográfico
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
        IdAsesorGenerador   INT                     NULL,       -- FK lógica → fab.OperadoresFabrica.IdOperador (si fue manual)

        FechaCreacion       DATETIME2(3)            NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_SolicitudesRecarga PRIMARY KEY (IdSolicitudRecarga),
        CONSTRAINT FK_SolicitudesRecarga_Estudio  FOREIGN KEY (IdEstudio)  REFERENCES [fab].[EstudiosCredito](IdEstudio),
        CONSTRAINT FK_SolicitudesRecarga_TipoFoto FOREIGN KEY (IdTipoFoto) REFERENCES [cat].[CatalogoTiposFotografia](IdTipoFoto),  -- NULL permitido (GAP-01)
        CONSTRAINT FK_SolicitudesRecarga_FotoAnterior FOREIGN KEY (IdFotografiaAnterior) REFERENCES [fab].[FotografiasEstudio](IdFotografia),
        CONSTRAINT UQ_SolicitudesRecarga_Token    UNIQUE (TokenRecarga),
        CONSTRAINT CK_SolicitudesRecarga_Canal    CHECK (CanalEnvio IN ('EMAIL','SMS','WHATSAPP')),
        CONSTRAINT CK_SolicitudesRecarga_Estado   CHECK (EstadoSolicitud IN ('GENERADO','ENVIADO','USADO','EXPIRADO','CANCELADO'))
    );

    -- Índice para lookup rápido del token (validación cuando el cliente accede al link)
    CREATE UNIQUE INDEX IX_SolicitudesRecarga_Token
        ON [fab].[SolicitudesRecarga](TokenRecarga);

    -- Índice para consultar todas las solicitudes de un estudio
    -- GAP-16: IdTipoFoto puede ser NULL (handoff), se usa como INCLUDE no en clave
    CREATE INDEX IX_SolicitudesRecarga_Estudio
        ON [fab].[SolicitudesRecarga](IdEstudio, FechaCreacion)
        INCLUDE (IdTipoFoto);

    -- Índice para expiración batch (job nocturno que marca links expirados)
    CREATE INDEX IX_SolicitudesRecarga_Expiracion
        ON [fab].[SolicitudesRecarga](FechaExpiracion, EstadoSolicitud)
        WHERE EstadoSolicitud IN ('GENERADO','ENVIADO');

    -- Índice para analíticas de canal de envío
    CREATE INDEX IX_SolicitudesRecarga_Canal
        ON [fab].[SolicitudesRecarga](CanalEnvio, EstadoSolicitud, FechaCreacion);

    PRINT '✓ Tabla SolicitudesRecarga creada';
END


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
        MotivoTransicion    NVARCHAR(300)           NULL,       -- Descripción del motivo (por ej. motivo de rechazo)
        IdRevisionRelacionada BIGINT                NULL,       -- FK → RevisionesFotografia (si la transición fue por revisión)
        IdSolicitudRelacionada BIGINT               NULL,       -- FK → SolicitudesRecarga (si la transición fue por re-carga)

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

    -- Línea de tiempo completa para una foto específica
    CREATE INDEX IX_HistFotos_Fotografia
        ON [aud].[HistorialFotografias](IdFotografia, FechaTransicion);

    -- Línea de tiempo completa para un estudio (módulo de revisión / auditoría)
    CREATE INDEX IX_HistFotos_Estudio
        ON [aud].[HistorialFotografias](IdEstudio, FechaTransicion);

    -- Índice para filtrar por tipo de foto (ej. todas las transiciones de SELFIEs)
    CREATE INDEX IX_HistFotos_TipoFoto
        ON [aud].[HistorialFotografias](IdTipoFoto, EstadoNuevo, FechaTransicion);

    PRINT '✓ Tabla HistorialFotografias creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.6  EstudiosCredito — FotografiasAprobadas y EstadoRevisionFotos
--      PH-06: Ambas columnas, el índice IX_EstudiosCredito_RevisionFotos y el
--             constraint CK_EstudiosCredito_EstadoRevisionFotos ya están
--             definidos directamente en el CREATE TABLE (Sección 3.1).
-- ─────────────────────────────────────────────────────────────────────────────
-- (sin ALTER TABLE — columnas y constraint consolidados en CREATE TABLE, Sección 3.1)


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.7  RegistrosBiometria — FKs físicas a FotografiasEstudio (PH-07)
--      Las columnas IdFotografiaFrontal, IdFotografiaReverso e IdFotografiaSelfie
--      ya están definidas en el CREATE TABLE (Sección 3.4).
--      Las FKs físicas se añaden aquí como ALTER porque FotografiasEstudio
--      se crea en la Sección 7.2, DESPUÉS de RegistrosBiometria — dependencia forward.
--      GAP-07: La nueva FotografiasEstudio mantiene la misma PK IdFotografia, por lo
--      que estas FKs siguen siendo válidas.
-- ─────────────────────────────────────────────────────────────────────────────

-- Añadir FKs físicas (FotografiasEstudio ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoFrontal'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoFrontal
        FOREIGN KEY (IdFotografiaFrontal) REFERENCES [fab].[FotografiasEstudio](IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoFrontal añadida';
END


IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoReverso'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoReverso
        FOREIGN KEY (IdFotografiaReverso) REFERENCES [fab].[FotografiasEstudio](IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoReverso añadida';
END


IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.RegistrosBiometria')
      AND name = 'FK_RegistrosBiometria_FotoSelfie'
)
BEGIN
    ALTER TABLE RegistrosBiometria
        ADD CONSTRAINT FK_RegistrosBiometria_FotoSelfie
        FOREIGN KEY (IdFotografiaSelfie) REFERENCES [fab].[FotografiasEstudio](IdFotografia);
    PRINT '✓ RegistrosBiometria: FK FK_RegistrosBiometria_FotoSelfie añadida';
END


-- GAP-07: La nueva FotografiasEstudio no referencia RegistrosBiometria ni SolicitudesRecarga
-- (las FKs inversas de la v2.3 son eliminadas en el rediseño unificado).
-- RegistrosBiometria sigue referenciando FotografiasEstudio (válido — misma PK IdFotografia).

-- FK en FotografiasEstudio → SolicitudesRecarga
-- GAP-07: ELIMINADA — la nueva FotografiasEstudio no tiene IdSolicitudRecarga


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
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES (
        'PENDIENTE_FOTOS',
        'Pendiente Carga de Fotografías',
        'PROCESO', 0, 0,
        'El proceso está bloqueado porque al menos una fotografía obligatoria (frente/reverso cédula o selfie) '
        + 'está faltante o fue rechazada. Se ha enviado link de re-carga al cliente.'
    );
    PRINT '✓ Estado PENDIENTE_FOTOS insertado en CatalogoEstados';
END


IF NOT EXISTS (SELECT * FROM CatalogoEstados WHERE Codigo = 'FOTOS_EN_REVISION')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
    VALUES (
        'FOTOS_EN_REVISION',
        'Fotografías en Revisión Manual',
        'PROCESO', 0, 0,
        'Todas las fotografías obligatorias fueron cargadas por el cliente. '
        + 'El asesor de fábrica está revisando las imágenes para aprobarlas o rechazarlas.'
    );
    PRINT '✓ Estado FOTOS_EN_REVISION insertado en CatalogoEstados';
END


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
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdEnProgreso2, @IdPendFotos, 1,
            'Foto obligatoria faltante o rechazada: sistema envía link de re-carga al cliente');
END

-- PENDIENTE_BIOMETRIA → PENDIENTE_FOTOS (durante la fase biométrica se detecta que las fotos no están OK)
IF @IdPendBiom IS NOT NULL AND @IdPendFotos IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendBiom AND IdEstadoDestino = @IdPendFotos)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendBiom, @IdPendFotos, 1,
            'Desde paso biométrico: foto rechazada o de calidad insuficiente para Rekognition');
END

-- PENDIENTE_FOTOS → FOTOS_EN_REVISION (cliente subió todas las fotos pendientes)
IF @IdPendFotos IS NOT NULL AND @IdFotosRev IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdPendFotos AND IdEstadoDestino = @IdFotosRev)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdPendFotos, @IdFotosRev, 0,
            'Cliente subió todas las fotos pendientes: pasan a revisión del asesor');
END

-- PENDIENTE_FOTOS → PENDIENTE_FOTOS (link expiró, se genera nuevo link — misma cola)
-- No aplica como transición de estado, el estado no cambia.

-- FOTOS_EN_REVISION → EN_PROGRESO (asesor aprueba todas las fotos, proceso se reanuda)
IF @IdFotosRev IS NOT NULL AND @IdEnProgreso2 IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdEnProgreso2)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdEnProgreso2, 0,
            'Asesor aprobó todas las fotografías: proceso de crédito se reanuda automáticamente');
END

-- FOTOS_EN_REVISION → PENDIENTE_FOTOS (asesor rechaza al menos una foto, se pide re-carga)
IF @IdFotosRev IS NOT NULL AND @IdPendFotos IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdPendFotos)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdPendFotos, 1,
            'Asesor rechazó una o más fotografías: se genera nuevo link de re-carga al cliente');
END

-- FOTOS_EN_REVISION → RECHAZADO (fotos definitivamente no viables — ej. persona suplantada)
IF @IdFotosRev IS NOT NULL AND @IdRechazado2 IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM TransicionesEstado WHERE IdEstadoOrigen = @IdFotosRev AND IdEstadoDestino = @IdRechazado2)
BEGIN
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    VALUES (@IdFotosRev, @IdRechazado2, 1,
            'Asesor determina rechazo definitivo por fotografías: suplantación, documento falso, etc.');
END

PRINT '✓ Transiciones PENDIENTE_FOTOS y FOTOS_EN_REVISION insertadas';


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.10 Seeds CatalogoTiposFotografia — los 3 tipos obligatorios
--      PH-10: Datos iniciales del catálogo de tipos de fotografía.
--             OrdenRevision define el orden en que aparecen en el módulo
--             de revisión del asesor (1=Frontal, 2=Reverso, 3=Selfie).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoTiposFotografia)
BEGIN
    INSERT INTO [cat].[CatalogoTiposFotografia] (Codigo, Nombre, Descripcion, EsObligatoria, OrdenRevision, ServicioAWS)
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.11 Seeds ConfiguracionReglasNegocio — parámetros del módulo fotográfico
--      PH-09: Todos los valores límite del proceso de fotografías son
--             configurables sin tocar código, siguiendo el patrón existente.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio WHERE Codigo = 'VIGENCIA_LINK_RECARGA_HORAS')
BEGIN
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion)
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.12 Seeds CatalogoReglasFraude — reglas de fraude fotográfico
--      PH-10 (continuación): Añadir reglas de fraude específicas al módulo
--             de fotografías (complementan las reglas de OTP/email del v2.2).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoReglasFraude WHERE Codigo = 'FOTO_RECHAZADA_MULTIPLE_VECES')
BEGIN
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica)
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


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.13 Seeds CatalogoMotivosEscalamiento — motivos de escalamiento fotográfico
--      PH-10 (continuación): Añadir motivos de escalamiento específicos al
--             módulo de fotografías.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM CatalogoMotivosEscalamiento WHERE Codigo = 'FOTO_MAX_REINTENTOS_SUPERADO')
BEGIN
    INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen)
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



-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 8: PARCHES V2.4 — CORRECCIONES DE ARQUITECTURA (2026-04-15)
-- ══════════════════════════════════════════════════════════════════════════════
-- Correcciones identificadas tras revisión de arquitectura (2026-04-15).
--
-- CAMBIOS EN ESTE BLOQUE:
--   C-01: ConfiguracionReglasNegocio — reglas OTP_EXPIRACION_MINUTOS, OTP_MAXIMO_INTENTOS,
--         JWT_ORIGEN_WEB, JWT_ORIGEN_BODEGA (son reglas de negocio, NO navegación)
--   C-02: EstudiosCredito — renombre IdTienda → IdBodega + índice Tienda → Bodega
--         (solo en la definición CREATE TABLE; ya aplicado en la Sección 3)
--   C-03: Nueva tabla ValidacionesAsesor — log de validación biométrica del asesor
--         (flujo asistido: asesor ingresa código en PC compartida → prueba de vida)
--   C-04: ALTER EstudiosCredito — añadir IdValidacionAsesor BIGINT NULL
--         FK → ValidacionesAsesor.IdValidacion (vincula estudio con la validación
--         que autorizó al asesor para la sesión)
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 8.1  ValidacionesAsesor — log de validación biométrica de identidad del asesor
--      C-03: En el flujo asistido (canal TIENDA/BODEGA), el asesor NO se auto-asigna.
--            Flujo: asesor ingresa "Código de Asesor" en PC compartida → sistema
--            valida via biometría facial (prueba de vida, microservicio externo).
--            Esta tabla registra cada intento de validación y su resultado.
--
--      BIGINT IDENTITY: tabla transaccional de alto volumen.
--      INSERT-ONLY para los registros exitosos (auditoría inmutable).
--      Registros FALLIDA/ERROR_SERVICIO también son inmutables.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'fab.ValidacionesAsesor') AND type = N'U')
BEGIN
    CREATE TABLE [fab].[ValidacionesAsesor] (
        IdValidacion            BIGINT IDENTITY(1,1)    NOT NULL,
        IdAsesor                INT                     NOT NULL,   -- FK → fab.OperadoresFabrica.IdOperador
        CodigoAsesor            VARCHAR(20)             NOT NULL,   -- Badge/código ingresado por el asesor en la PC
        IdBodega                INT                     NOT NULL,   -- FK → QUAC.dbo.bodegas.id — PC/punto de venta donde se valida
        FechaValidacion         DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        -- Resultado de la prueba de vida biométrica
        PruebaVidaExitosa       BIT                     NOT NULL DEFAULT 0, -- 1 = prueba de vida facial superada
        PorcentajeCoincidencia  DECIMAL(5,2)            NULL,       -- Porcentaje de coincidencia facial (0.00–100.00)

        -- Identificación del dispositivo/PC
        IdDispositivo           VARCHAR(100)            NULL,       -- Identificador del equipo/PC (hostname, UUID, etc.)
        DireccionIP             VARCHAR(45)             NULL,       -- IP del dispositivo (soporta IPv4 e IPv6)

        -- Resultado final de la validación
        ResultadoValidacion     VARCHAR(20)             NOT NULL,   -- CHECK: 'EXITOSA', 'FALLIDA', 'ERROR_SERVICIO'
        MensajeError            NVARCHAR(500)           NULL,       -- Mensaje de error si ResultadoValidacion != 'EXITOSA'

        FechaCreacion           DATETIME2(3)            NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_ValidacionesAsesor PRIMARY KEY (IdValidacion),
        CONSTRAINT CK_ValidacionesAsesor_Resultado CHECK (
            ResultadoValidacion IN ('EXITOSA', 'FALLIDA', 'ERROR_SERVICIO')
        ),
        -- FK física al operador en fab schema
        CONSTRAINT FK_ValidacionesAsesor_Asesor
            FOREIGN KEY (IdAsesor)
            REFERENCES [fab].[OperadoresFabrica] (IdOperador)
            ON UPDATE NO ACTION ON DELETE NO ACTION,
        -- FK física a la bodega en QUAC (mismo servidor SQL)
        CONSTRAINT FK_ValidacionesAsesor_Bodega
            FOREIGN KEY (IdBodega)
            REFERENCES QUAC.dbo.bodegas (id)
            ON UPDATE NO ACTION ON DELETE NO ACTION
    );

    -- Índice para consultar las validaciones de un asesor por fecha (timeline del asesor)
    CREATE INDEX IX_ValidacionesAsesor_Asesor
        ON [fab].[ValidacionesAsesor](IdAsesor, FechaValidacion DESC);

    -- Índice para consultar las validaciones desde una bodega (auditoría por punto de venta)
    CREATE INDEX IX_ValidacionesAsesor_Bodega
        ON [fab].[ValidacionesAsesor](IdBodega, FechaValidacion DESC);

    -- Índice para búsqueda por código de asesor (deduplicación, lookups rápidos)
    CREATE INDEX IX_ValidacionesAsesor_Codigo
        ON [fab].[ValidacionesAsesor](CodigoAsesor);

    -- GAP-14: Índice filtrado para el hot-path: validaciones exitosas por asesor
    CREATE INDEX IX_ValidacionesAsesor_Exitosas
        ON [fab].[ValidacionesAsesor](IdAsesor, FechaValidacion DESC)
        WHERE ResultadoValidacion = 'EXITOSA';

    PRINT '✓ Tabla ValidacionesAsesor creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 8.2  EstudiosCredito — FK IdValidacionAsesor (C-04)
--      La columna IdValidacionAsesor ya está definida en el CREATE TABLE (Sección 3.1).
--      El índice IX_EstudiosCredito_ValidacionAsesor también está en el CREATE TABLE.
--      La FK física se añade aquí como ALTER porque ValidacionesAsesor se crea
--      en la Sección 8.1, DESPUÉS de EstudiosCredito — dependencia forward.
-- ─────────────────────────────────────────────────────────────────────────────

-- FK física para IdValidacionAsesor (ValidacionesAsesor ya existe a este punto)
IF NOT EXISTS (
    SELECT * FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'fab.EstudiosCredito')
      AND name = 'FK_EstudiosCredito_ValidacionAsesor'
)
BEGIN
    ALTER TABLE EstudiosCredito
        ADD CONSTRAINT FK_EstudiosCredito_ValidacionAsesor
        FOREIGN KEY (IdValidacionAsesor) REFERENCES [fab].[ValidacionesAsesor](IdValidacion);
    PRINT '✓ EstudiosCredito: FK FK_EstudiosCredito_ValidacionAsesor añadida';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- 8.3  Seeds ConfiguracionReglasNegocio — reglas de autenticación JWT por canal
--      C-01: JWT_ORIGEN_* tipifican el flujo de autenticación según el canal de origen.
--      GAP-04: OTP_EXPIRACION_MINUTOS y OTP_MAXIMO_INTENTOS ELIMINADAS (duplican
--              VIGENCIA_OTP_SEG e INTENTOS_OTP_MAX que ya existen en sección 6.5).
--              JWT_ORIGEN_BODEGA renombrado a JWT_ORIGEN_TIENDA (coherencia con LoginTienda).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM ConfiguracionReglasNegocio WHERE Codigo = 'JWT_ORIGEN_WEB')
BEGIN
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    (
        'JWT_ORIGEN_WEB',
        'Valor del claim ''origen'' en el JWT para el canal de autoservicio web',
        'LoginWeb', 'TEXT', 'AUTH',
        'Identificador de origen que se incluye en el JWT emitido para sesiones iniciadas '
        + 'por el cliente en el portal web de autoservicio. Usado para autorización diferenciada '
        + 'y auditoría de origen del token en el API.'
    ),
    (
        'JWT_ORIGEN_TIENDA',  -- GAP-04: renombrado de JWT_ORIGEN_BODEGA a JWT_ORIGEN_TIENDA
        'Valor del claim ''origen'' en el JWT para el canal de tienda asistida',
        'LoginTienda', 'TEXT', 'AUTH',
        'Identificador de origen que se incluye en el JWT emitido para sesiones iniciadas '
        + 'por el asesor en una tienda/bodega (flujo asistido). Usado para autorización diferenciada '
        + 'y para vincular el JWT con la validación biométrica del asesor (ValidacionesAsesor).'
    );

    PRINT '✓ Seeds JWT_ORIGEN_WEB y JWT_ORIGEN_TIENDA insertados en ConfiguracionReglasNegocio (GAP-04)';
END



-- ==============================================================================
-- SECCIÓN 9: PARCHES V2.5 — GAPS DE AUDITORÍA PRE-PRODUCCIÓN (2026-04-15)
-- ==============================================================================
-- Correcciones identificadas en revisión de arquitectura antes de ir a producción.
-- Todos los cambios son aditivos o correcciones de definición — no hay migraciones
-- de datos ni drops de columnas con información existente.
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 9.1  AuditoriaLogins — GAP-15: Auditoría de intentos de inicio de sesión
--      Registra cada intento de login (exitoso o fallido) por canal y tipo de usuario.
--      INSERT-ONLY: no se actualiza ni elimina. Reemplaza logs dispersos en aplicación.
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
        IdBodega            INT                         NULL,  -- FK blanda a QUAC.dbo.bodegas
        NitUsuario          VARCHAR(20)                 NULL,  -- GAP-19: CC inmutable del usuario autenticado
        MensajeError        NVARCHAR(500)               NULL,  -- detalle si ResultadoLogin != 'EXITOSO'
        FechaCreacion       DATETIME2(3)            NOT NULL   CONSTRAINT DF_AuditoriaLogins_FechaCreacion  DEFAULT GETDATE(),

        CONSTRAINT PK_AuditoriaLogins             PRIMARY KEY (IdLogin),
        CONSTRAINT CK_AuditoriaLogins_Origen      CHECK (OrigenLogin    IN ('LoginWeb', 'LoginTienda')),
        CONSTRAINT CK_AuditoriaLogins_TipoUsuario CHECK (TipoUsuario    IN ('CLIENTE', 'ASESOR')),
        CONSTRAINT CK_AuditoriaLogins_Resultado   CHECK (ResultadoLogin IN ('EXITOSO', 'FALLIDO', 'BLOQUEADO'))
    );

    -- Índice hot-path: consultas por usuario en rango de fecha (detección de fuerza bruta)
    CREATE INDEX IX_AuditoriaLogins_Usuario
        ON [aud].[AuditoriaLogins](IdUsuario, FechaLogin DESC);

    -- Índice hot-path: consultas por canal de origen y fecha (reportería por canal)
    CREATE INDEX IX_AuditoriaLogins_Origen
        ON [aud].[AuditoriaLogins](OrigenLogin, FechaLogin DESC);

    PRINT '✓ Tabla AuditoriaLogins creada (GAP-15)';
END



/*
  ╔══════════════════════════════════════════════════════════════════════════════╗
  ║                        RESUMEN DE IMPLEMENTACIÓN V2.5                        ║
  ╠══════════════════════════════════════════════════════════════════════════════╣
  ║                                                                              ║
  ║  TABLAS CREADAS:                     29 tablas (28 v2.4 + 1 v2.5)           ║
  ║  ├── Configuración:                  9 tablas                                ║
  ║  │   ├── CatalogoCanalesOrigen       (G-DB-01 — nueva en v2.1)               ║
  ║  │   ├── CatalogoReglasFraude        (SA-06 — nueva en v2.2)                 ║
  ║  │   ├── CatalogoMotivosEscalamiento (SA-01 — nueva en v2.2)                 ║
  ║  │   └── CatalogoTiposFotografia     (PH-01 — nueva en v2.3)                 ║
  ║  ├── Transaccionales:                16 tablas                               ║
  ║  │   ├── EvidenciasFabrica           (GT-08 — nueva en v2.1)                 ║
  ║  │   ├── EscalamientosFabrica        (SA-02 — nueva en v2.2)                 ║
  ║  │   ├── AlertasFraude               (SA-05 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── LogValidacionesOTP          (SA-03 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── HistorialDatosSensibles     (SA-04 — nueva en v2.2, INSERT-ONLY)    ║
  ║  │   ├── FotografiasEstudio          (PH-02+GAP-07 — rediseñada en v2.5)     ║
  ║  │   ├── SolicitudesRecarga          (PH-04 — nueva en v2.3)                 ║
  ║  │   ├── ValidacionesAsesor          (C-03  — nueva en v2.4, INSERT-ONLY)    ║
  ║  │   └── AuditoriaLogins             (GAP-15 — nueva en v2.5)               ║
  ║  ├── Auditoría:                      5 tablas                                ║
  ║  │   ├── RevisionesFotografia        (PH-03 — nueva en v2.3, INSERT-ONLY)    ║
  ║  │   └── HistorialFotografias        (PH-05 — nueva en v2.3, INSERT-ONLY)    ║
  ║  └── Integración:                    1 tabla (TercerosFabricas)              ║
  ║                                                                              ║
  ║  TABLAS MODIFICADAS (ALTER — solo tablas de PRODUCCIÓN existentes):          ║
  ║  ├── QUAC.dbo.KCRM_CadenaCreditos   +4 columnas (v2.1)                      ║
  ║  └── QUAC.dbo.BERP_FABRICASOperadores +1 columna (v2.1)                     ║
  ║                                                                              ║
  ║  ALTER TABLE para FKs circulares/forward (no pueden ir en CREATE TABLE):     ║
  ║  ├── ValidacionesContactabilidad    FK → AlertasFraude (SA-10)               ║
  ║  ├── RegistrosBiometria             FK × 3 → FotografiasEstudio (PH-07)      ║
  ║  └── EstudiosCredito                FK → ValidacionesAsesor  (C-04)          ║
  ║                                                                              ║
  ║  COLUMNAS CONSOLIDADAS EN CREATE TABLE (antes eran ALTER TABLE):             ║
  ║  ├── EstudiosCredito: NitComercio, CelularCliente, EliminadoLogico,          ║
  ║  │                    IdCorrelacion, IdEscalamientoActivo,                   ║
  ║  │                    FotografiasAprobadas, EstadoRevisionFotos,             ║
  ║  │                    IdValidacionAsesor                                      ║
  ║  ├── RetosSeguridad:  DireccionEnvio                                         ║
  ║  ├── HistorialEstados: IdCorrelacion                                         ║
  ║  ├── ValidacionesContactabilidad: IdAlertaFraude (columna; FK sigue ALTER)   ║
  ║  └── RegistrosBiometria: IdFotografiaFrontal, IdFotografiaReverso,           ║
  ║                           IdFotografiaSelfie (cols; FKs siguen ALTER)        ║
  ║                                                                              ║
  ║  COLUMNAS ELIMINADAS (decisión PO):                                          ║
  ║  └── EstudiosCredito:                          ║
  ║      (la maquina de estados + reglas de servicio previenen duplicados)       ║
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
  ║  DATOS SEMILLA INSERTADOS:           14 catálogos                            ║
  ║  ├── FasesEstudio:                   7 registros                             ║
  ║  ├── CatalogoEstados:               15 registros (11 base + 4 nuevos)        ║
  ║  ├── PasosEstudio:                  13 registros                             ║
  ║  ├── TransicionesEstado:            40 registros (+8 nuevas v2.3)            ║
  ║  ├── ConfiguracionReglasNegocio:    20 registros (v2.4 duplicados eliminados)║
  ║  ├── CatalogoCanalesOrigen:          3 registros                             ║
  ║  ├── CatalogoReglasFraude:          14 registros (+6 nuevas v2.3)            ║
  ║  ├── CatalogoMotivosEscalamiento:   12 registros (+4 nuevos v2.3)            ║
  ║  └── CatalogoTiposFotografia:        3 registros (PH-10)                     ║
  ║                                                                              ║
  ║  GAPS CORREGIDOS v2.5 (18) — Auditoría Pre-Producción 2026-04-15:           ║
  ║  ├── GAP-01 🔴 SolicitudesRecarga.IdTipoFoto → NULL (handoff biométrico)     ║
  ║  ├── GAP-02 🔴 HistorialEstados CHECK +CLIENTE +ADMINISTRADOR                ║
  ║  ├── GAP-03 🔴 EstudiosCredito +CelularCliente                               ║
  ║  ├── GAP-04 🟠 Seeds duplicados OTP eliminados; JWT_ORIGEN_TIENDA            ║
  ║  ├── GAP-05 🟠 ConfiguracionReglasNegocio +CHECK Categoria                  ║
  ║  ├── GAP-06 🟠 TercerosFabricas DATETIME2 → DATETIME2(3)                    ║
  ║  ├── GAP-07 🟠 FotografiasEstudio REDISEÑADA (tabla unificada biométrica)    ║
  ║  ├── GAP-08 🟠 AuditoriaCambiosDatos +CHECK TipoUsuario                     ║
  ║  ├── GAP-09 🟡 TercerosFabricas.NombreTercero VARCHAR→NVARCHAR               ║
  ║  ├── GAP-10 🟡 TransicionesEstado seeds ya idempotentes (IF NOT EXISTS)      ║
  ║  ├── GAP-11 🟡 SYSDATETIME() → GETDATE() (CatalogoCanalesOrigen+Evidencias)  ║
  ║  ├── GAP-12 🟡 +IX_EstudiosCredito_EscalamientoActivo                       ║
  ║  ├── GAP-13 🟡 RegistrosBiometria CHECK +PRUEBA_VIDA_HANDOFF                 ║
  ║  ├── GAP-14 🟡 +IX_ValidacionesAsesor_Exitosas (hot-path filtrado)           ║
  ║  ├── GAP-15 🟢 Nueva tabla AuditoriaLogins                                  ║
  ║  ├── GAP-16 🟢 IX_SolicitudesRecarga_Estudio: IdTipoFoto → INCLUDE (nullable)║
  ║  ├── GAP-17 🟢 JWT_ORIGEN_TIENDA (cubierto en GAP-04)                       ║
  ║  ├── GAP-18 🟢 TercerosFabricas +CelularPrincipal, +CelularWhatsApp           ║
  ║  ├── GAP-20 🟢 EstudiosCredito +RenunciaCupo (Marcación de eliminación)       ║
  ║  └── GAP-21 🟢 EvaluacionesRiesgo +MoraComerciosAliados                       ║
  ║                                                                              ║
  ╚══════════════════════════════════════════════════════════════════════════════╝
*/

PRINT '================================================================';
PRINT '  MIGRACIÓN FABRICASV2.5 COMPLETADA EXITOSAMENTE';
PRINT '================================================================';
PRINT '  Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- PARCHE V2.8 — GESTIÓN DE CENTRALES DE RIESGO
-- Fecha: 2026-05-04
-- Autor: Arquitectura de Datos — QUAC FinTech
--
-- CONTEXTO:
--   Existen dos centrales de riesgo con servicios equivalentes:
--     · DATACREDITO: Preselecta (viabilidad) + Reconocer (contactabilidad)
--     · CIFIN:       VariablesAdviser (viabilidad) + UBICA (contactabilidad)
--
--   Los logs de cada central YA EXISTEN en QUAC.dbo.BERP_* (ver TABLAS_EXISTENTES.sql).
--   El API externo de cada central consulta, escribe y retorna el Id del registro.
--   Fábricas NO escribe en esas tablas — solo recibe el Id y lo referencia.
--
-- CAMBIOS:
--   CR-01: Nueva tabla cfg.CentralesRiesgoCfg — configura qué central se usa
--          por tipo de servicio (VIABILIDAD, CONTACTABILIDAD) y por canal.
--   CR-02: ALTER fab.EvaluacionesRiesgo — añade columnas para referenciar qué
--          central respondió y el Id del log en la tabla BERP_* correspondiente.
--   CR-03: Semillas iniciales en cfg.CentralesRiesgoCfg.
--   CR-04: Ampliación del CHECK CK_EvaluacionesRiesgo_Tipo para incluir
--          VIABILIDAD_COMBINADA y CONTACTABILIDAD_COMBINADA (respuesta unificada).
-- ==============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- CR-01: cfg.CentralesRiesgoCfg
-- Tabla de configuración: define qué central se usa por tipo de servicio.
-- Un administrador puede cambiar la combinación sin tocar código.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.CentralesRiesgoCfg') AND type = 'U')
BEGIN
    CREATE TABLE [cfg].[CentralesRiesgoCfg] (
        IdConfig            INT IDENTITY(1,1)   NOT NULL,

        -- Qué tipo de evaluación configura esta fila
        TipoServicio        VARCHAR(30)         NOT NULL,   -- VIABILIDAD | CONTACTABILIDAD

        -- Qué central se usa (puede ser una sola o COMBINADO)
        CentralActiva       VARCHAR(30)         NOT NULL,   -- DATACREDITO | CIFIN | COMBINADO

        -- Nombre del servicio concreto dentro de la central
        NombreServicio      VARCHAR(50)         NOT NULL,   -- PRESELECTA | VARIABLES_ADVISER | RECONOCER | UBICA | COMBINADO_VIABILIDAD | COMBINADO_CONTACTABILIDAD

        -- Tabla de log externa donde quedan los registros (referencia documental)
        TablaLogExterna     VARCHAR(100)        NOT NULL,   -- ej: QUAC.dbo.BERP_FABRICASDatacredito_PreselectaDesicion

        -- Canal al que aplica esta configuración (NULL = aplica a todos)
        Canal               VARCHAR(20)         NULL,       -- TIENDA | WEB | NULL (todos)

        -- Control
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
                'PRESELECTA',           -- Datacredito — viabilidad
                'VARIABLES_ADVISER',    -- CIFIN — viabilidad
                'RECONOCER',            -- Datacredito — contactabilidad
                'UBICA',                -- CIFIN — contactabilidad
                'COMBINADO_VIABILIDAD', -- Ambas centrales — respuesta unificada de decisión
                'COMBINADO_CONTACTABILIDAD' -- Ambas centrales — respuesta unificada de contactabilidad
            )
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Canal CHECK (
            Canal IS NULL OR Canal IN ('TIENDA','WEB','HANDOFF')
        )
    );

    CREATE NONCLUSTERED INDEX IX_CentralesRiesgoCfg_Tipo
        ON [cfg].[CentralesRiesgoCfg] (TipoServicio, Activa);

    PRINT '✓ Tabla CentralesRiesgoCfg creada';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- CR-02: ALTER fab.EvaluacionesRiesgo
-- Añade referencia a qué central respondió y el Id del log externo.
-- Permite cruzar el registro de Fábricas con el log detallado en BERP_*.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'CentralConsultada')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CentralConsultada   VARCHAR(30) NULL;   -- DATACREDITO | CIFIN | COMBINADO
    PRINT '✓ fab.EvaluacionesRiesgo +CentralConsultada';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExterno')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExterno BIGINT NULL;         -- Id del registro en la tabla BERP_* correspondiente
    PRINT '✓ fab.EvaluacionesRiesgo +IdLogCentralExterno';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExternoSecundaria')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExternoSecundaria BIGINT NULL; -- Id del log de la segunda central (solo cuando CentralConsultada = COMBINADO)
    PRINT '✓ fab.EvaluacionesRiesgo +IdLogCentralExternoSecundaria';
END

-- CHECK para las nuevas columnas
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
    PRINT '✓ fab.EvaluacionesRiesgo CHECK CentralConsultada';
END

-- Ampliar CHECK TipoEvaluacion para incluir los tipos combinados (CR-04)
-- Primero eliminar el check existente y recrearlo
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
                'PRESELECTA',               -- Datacredito — viabilidad
                'VARIABLES_ADVISER',        -- CIFIN — viabilidad
                'FOSYGA',
                'ANTECEDENTES',
                'RECONOCER',                -- Datacredito — contactabilidad
                'UBICA',                    -- CIFIN — contactabilidad
                'VIABILIDAD_COMBINADA',     -- Ambas centrales — decisión unificada
                'CONTACTABILIDAD_COMBINADA' -- Ambas centrales — contactabilidad unificada
            )
        );
    PRINT '✓ fab.EvaluacionesRiesgo CHECK TipoEvaluacion ampliado (CR-04)';
END

-- Índice para consultas por central
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IX_EvaluacionesRiesgo_Central')
BEGIN
    CREATE NONCLUSTERED INDEX IX_EvaluacionesRiesgo_Central
        ON [fab].[EvaluacionesRiesgo] (CentralConsultada, TipoEvaluacion)
        WHERE CentralConsultada IS NOT NULL;
    PRINT '✓ fab.EvaluacionesRiesgo IX_EvaluacionesRiesgo_Central creado';
END


-- ─────────────────────────────────────────────────────────────────────────────
-- CR-03: Seeds cfg.CentralesRiesgoCfg
-- Configuración inicial: viabilidad por DATACREDITO, contactabilidad por CIFIN.
-- Un admin puede cambiar estas filas sin deploy usando el CRUD A-XX.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM [cfg].[CentralesRiesgoCfg] WHERE TipoServicio = 'VIABILIDAD' AND CentralActiva = 'DATACREDITO')
BEGIN
    INSERT INTO [cfg].[CentralesRiesgoCfg]
        (TipoServicio, CentralActiva, NombreServicio, TablaLogExterna, Canal, Activa, Observaciones)
    VALUES
        -- Configuración combinada: Datacredito para viabilidad, CIFIN para contactabilidad
        ('VIABILIDAD',       'DATACREDITO', 'PRESELECTA',      'QUAC.dbo.BERP_FABRICASDatacredito_PreselectaDesicion', NULL, 1, 'Preselecta Datacredito — viabilidad por defecto'),
        ('VIABILIDAD',       'CIFIN',       'VARIABLES_ADVISER','QUAC.dbo.BERP_FABRICASCifinAdviserLog',               NULL, 0, 'VariablesAdviser CIFIN — alternativa a Preselecta'),
        ('CONTACTABILIDAD',  'CIFIN',       'UBICA',            'QUAC.dbo.BERP_FABRICASCifinUbicaLog',                 NULL, 1, 'UBICA CIFIN — contactabilidad por defecto'),
        ('CONTACTABILIDAD',  'DATACREDITO', 'RECONOCER',        'QUAC.dbo.BERP_CUPOAprobacion_Reconocer_Log',          NULL, 0, 'Reconocer Datacredito — alternativa a UBICA');
    PRINT '✓ Seeds CentralesRiesgoCfg insertados (4 filas)';
END


PRINT '================================================================';
PRINT '  PARCHE V2.8 — CENTRALES DE RIESGO COMPLETADO';
PRINT '================================================================';
PRINT '  Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- ==============================================================================
-- SECCIÓN 10: PARCHE V2.9 — BOT UBICA (VALIDACIÓN DE IDENTIDAD)
-- Fecha: 2026-05-25
-- Descripción: Tablas y seeds para el sistema de validación de identidad por
--              voz. Orquesta llamadas automáticas vía Bot de Voz y soporta
--              Plan B de validación manual por asesor.
-- Bloquea: Integración CIFIN/Datacredito en T-06a/b y W-07
-- ==============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 10.1 cat.CatalogoDiagnosticosBot
--      Fuente de verdad del motor de decisiones (DiagnosticoDecisionEngine).
--      Define los 10 diagnósticos posibles que puede devolver el Bot de Voz
--      o registrar un asesor en Plan B, con la acción que el sistema debe
--      ejecutar para cada uno. NUNCA se hardcodea lógica en el orquestador.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'cat' AND t.name = 'CatalogoDiagnosticosBot')
BEGIN
    CREATE TABLE cat.CatalogoDiagnosticosBot (
        IdDiagnostico       INT             NOT NULL IDENTITY(1,1),
        Codigo              VARCHAR(40)     NOT NULL,
        Descripcion         NVARCHAR(200)   NOT NULL,
        AccionSistema       VARCHAR(20)     NOT NULL,   -- CONTINUAR | BLOQUEAR | ESCALAR | PLAN_B | DESCARTAR_LINEA
        NivelAlerta         VARCHAR(10)     NOT NULL,   -- VERDE | AMARILLO | ROJO | GRIS | ERROR
        GeneraAlertaFraude  BIT             NOT NULL    CONSTRAINT DF_CatDiagBot_GeneraAlerta DEFAULT(0),
        EsTerminal          BIT             NOT NULL    CONSTRAINT DF_CatDiagBot_EsTerminal   DEFAULT(0),
        Activo              BIT             NOT NULL    CONSTRAINT DF_CatDiagBot_Activo        DEFAULT(1),
        Observaciones       NVARCHAR(400)   NULL,

        CONSTRAINT PK_CatalogoDiagnosticosBot PRIMARY KEY (IdDiagnostico),
        CONSTRAINT UQ_CatalogoDiagnosticosBot_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_CatDiagBot_Accion CHECK (AccionSistema IN ('CONTINUAR','BLOQUEAR','ESCALAR','PLAN_B','DESCARTAR_LINEA')),
        CONSTRAINT CK_CatDiagBot_Nivel  CHECK (NivelAlerta   IN ('VERDE','AMARILLO','ROJO','GRIS','ERROR'))
    )
    PRINT '✓ cat.CatalogoDiagnosticosBot creada';
END
ELSE
    PRINT '— cat.CatalogoDiagnosticosBot ya existe, omitida';


-- ─────────────────────────────────────────────────────────────────────────────
-- 10.2 fab.CampanasValidacionIdentidad
--      Una campaña por estudio. Registra si la validación se hizo vía Bot
--      automático o vía asesor manual (Plan B), el diagnóstico final y el
--      Paquete de Inconsistencia que se entrega a Fábrica de Soporte.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'fab' AND t.name = 'CampanasValidacionIdentidad')
BEGIN
    CREATE TABLE fab.CampanasValidacionIdentidad (
        IdCampana               INT             NOT NULL IDENTITY(1,1),
        CodigoCampana           VARCHAR(30)     NOT NULL,   -- CAMP-{yyyyMMdd}-{IdCampana}
        IdEstudio               BIGINT          NOT NULL,
        Canal                   VARCHAR(10)     NOT NULL,   -- BOT | MANUAL
        MotivoManual            VARCHAR(20)     NULL,       -- FALLA_BOT | DECISION_ASESOR | NULL si Canal=BOT
        EstadoCampana           VARCHAR(15)     NOT NULL    CONSTRAINT DF_CampVal_Estado DEFAULT('EN_PROCESO'),
        IdDiagnosticoFinal      INT             NULL,       -- FK a cat.CatalogoDiagnosticosBot
        PaqueteInconsistencia   NVARCHAR(MAX)   NULL,       -- JSON para Fábrica de Soporte (diagnóstico + tags + URL audio)
        TotalLineasUsadas       TINYINT         NULL,
        TotalIntentos           TINYINT         NULL,
        FechaInicioMarcacion    DATETIME2(3)    NULL,
        FechaFinMarcacion       DATETIME2(3)    NULL,
        FechaCreacion           DATETIME2(3)    NOT NULL    CONSTRAINT DF_CampVal_FechaCreacion DEFAULT(SYSUTCDATETIME()),
        NitAsesor               VARCHAR(20)     NOT NULL,   -- Inmutable — GAP-19
        CentralConsultada       VARCHAR(20)     NULL,       -- CIFIN | DATACREDITO — qué central se consultó (v2026-06-05)

        CONSTRAINT PK_CampanasValidacionIdentidad  PRIMARY KEY (IdCampana),
        CONSTRAINT UQ_CampVal_CodigoCampana        UNIQUE (CodigoCampana),
        CONSTRAINT UQ_CampVal_IdEstudio            UNIQUE (IdEstudio),   -- una campaña activa por estudio
        CONSTRAINT FK_CampVal_IdEstudio            FOREIGN KEY (IdEstudio)          REFERENCES fab.EstudiosCredito(IdEstudio),
        CONSTRAINT FK_CampVal_IdDiagnosticoFinal   FOREIGN KEY (IdDiagnosticoFinal) REFERENCES cat.CatalogoDiagnosticosBot(IdDiagnostico),
        CONSTRAINT CK_CampVal_Canal                CHECK (Canal          IN ('BOT','MANUAL')),
        CONSTRAINT CK_CampVal_MotivoManual         CHECK (MotivoManual   IN ('FALLA_BOT','DECISION_ASESOR') OR MotivoManual IS NULL),
        CONSTRAINT CK_CampVal_EstadoCampana        CHECK (EstadoCampana  IN ('EN_PROCESO','COMPLETADA','FALLIDA')),
        CONSTRAINT CK_CampVal_CentralConsultada    CHECK (CentralConsultada IN ('CIFIN','DATACREDITO') OR CentralConsultada IS NULL)
    )
    PRINT '✓ fab.CampanasValidacionIdentidad creada';
END
ELSE
    PRINT '— fab.CampanasValidacionIdentidad ya existe, omitida';


-- ─────────────────────────────────────────────────────────────────────────────
-- 10.3 fab.IntentosValidacionBot
--      Una fila por llamada individual. Registra timestamps exactos, diagnóstico
--      del intento, URL del audio grabado y variables biométricas detectadas
--      por el Bot (género de voz, edad estimada, acento, coincidencias).
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = 'fab' AND t.name = 'IntentosValidacionBot')
BEGIN
    CREATE TABLE fab.IntentosValidacionBot (
        IdIntento                   INT             NOT NULL IDENTITY(1,1),
        IdCampana                   INT             NOT NULL,
        OrdenLinea                  TINYINT         NOT NULL,   -- 1..5 — posición en lista priorizada
        NumeroMarcado               VARCHAR(15)     NOT NULL,
        NumeroIntento               TINYINT         NOT NULL,   -- 1..3 por línea
        IdDiagnosticoIntento        INT             NULL,       -- FK a cat.CatalogoDiagnosticosBot
        FechaInicio                 DATETIME2(3)    NOT NULL,
        FechaFin                    DATETIME2(3)    NULL,
        DuracionSegundos            INT             NULL,
        UrlAudio                    VARCHAR(500)    NULL,
        -- Variables biométricas devueltas por el Bot (pueden ser NULL si no aplica)
        GeneroVozDetectado          VARCHAR(10)     NULL,       -- MASCULINO | FEMENINO | INDEFINIDO
        EdadEstimadaVoz             TINYINT         NULL,
        AcentoDetectado             VARCHAR(30)     NULL,
        CoincidenciaNombre          BIT             NULL,
        CoincidenciaCedula          BIT             NULL,
        DescripcionDiscrepancia     NVARCHAR(400)   NULL,
        FechaCreacion               DATETIME2(3)    NOT NULL    CONSTRAINT DF_IntVal_FechaCreacion DEFAULT(SYSUTCDATETIME()),

        CONSTRAINT PK_IntentosValidacionBot         PRIMARY KEY (IdIntento),
        CONSTRAINT FK_IntVal_IdCampana              FOREIGN KEY (IdCampana)             REFERENCES fab.CampanasValidacionIdentidad(IdCampana),
        CONSTRAINT FK_IntVal_IdDiagnosticoIntento   FOREIGN KEY (IdDiagnosticoIntento)  REFERENCES cat.CatalogoDiagnosticosBot(IdDiagnostico),
        CONSTRAINT CK_IntVal_GeneroVoz              CHECK (GeneroVozDetectado IN ('MASCULINO','FEMENINO','INDEFINIDO') OR GeneroVozDetectado IS NULL),
        CONSTRAINT UQ_IntVal_Intento                UNIQUE (IdCampana, OrdenLinea, NumeroIntento)
    )
    PRINT '✓ fab.IntentosValidacionBot creada';
END
ELSE
    PRINT '— fab.IntentosValidacionBot ya existe, omitida';


-- ─────────────────────────────────────────────────────────────────────────────
-- 10.4 Seeds — cat.CatalogoDiagnosticosBot
--      10 diagnósticos fijos. AccionSistema es la única fuente de verdad que
--      consume DiagnosticoDecisionEngine — sin hardcodeo en el orquestador C#.
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM cat.CatalogoDiagnosticosBot WHERE Codigo = 'CONFIRMACION_POSITIVA')
BEGIN
    INSERT INTO cat.CatalogoDiagnosticosBot
        (Codigo, Descripcion, AccionSistema, NivelAlerta, GeneraAlertaFraude, EsTerminal, Observaciones)
    VALUES
        ('CONFIRMACION_POSITIVA',       'Cliente confirmó identidad satisfactoriamente',                                    'CONTINUAR',       'VERDE',    0, 1, 'Aborta intentos restantes y avanza el estudio'),
        ('ALERTA_SUPLANTACION',         'El bot detectó indicios claros de suplantación de identidad',                      'BLOQUEAR',        'ROJO',     1, 1, 'Crea aud.AlertasFraude + fab.EscalamientosFabrica prioridad CRITICA'),
        ('INFORMACION_PARCIAL',         'El cliente respondió pero la información fue insuficiente o ambigua',              'ESCALAR',         'AMARILLO', 0, 0, 'Genera escalamiento NORMAL a Fábrica de Soporte'),
        ('TERCERO_CONTESTA',            'Contestó una persona distinta al solicitante',                                     'ESCALAR',         'AMARILLO', 0, 0, 'Genera escalamiento NORMAL'),
        ('CLIENTE_NIEGA_LINEA',         'El cliente afirma que el número no le pertenece',                                  'ESCALAR',         'AMARILLO', 0, 0, 'Genera escalamiento NORMAL — posible error en centrales'),
        ('DISCREPANCIA_BIOMETRICA',     'Las variables biométricas de voz no coinciden con el perfil del solicitante',      'ESCALAR',         'AMARILLO', 0, 0, 'Genera escalamiento NORMAL con tags biométricos en paquete'),
        ('NUMERO_EQUIVOCADO',           'El número marcado no corresponde al solicitante — descarta la línea',              'DESCARTAR_LINEA', 'GRIS',     0, 0, 'Pasa a la siguiente línea de la lista priorizada'),
        ('SIN_RESPUESTA',               'La llamada no fue contestada en este intento',                                     'CONTINUAR',       'GRIS',     0, 0, 'Cuenta el intento y sigue con la estrategia Round-Robin'),
        ('SIN_RESPUESTA_MAX_INTENTOS',  'Se agotaron todos los intentos sin respuesta en ninguna línea',                   'CONTINUAR',       'GRIS',     0, 1, 'Flujo continúa por buena fe — sin bloqueo'),
        ('ERROR_TECNICO_BOT',           'El bot falló técnicamente — timeout, error de red o respuesta malformada',         'PLAN_B',          'ERROR',    0, 0, 'Activa ManualValidacionStrategy automáticamente');
    PRINT '✓ Seeds cat.CatalogoDiagnosticosBot insertados (10 filas)';
END
ELSE
    PRINT '— Seeds cat.CatalogoDiagnosticosBot ya existen, omitidos';


-- ─────────────────────────────────────────────────────────────────────────────
-- 10.5 Seeds — cfg.ConfiguracionReglasNegocio (parámetros operativos BOT Ubica)
-- ─────────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM cfg.ConfiguracionReglasNegocio WHERE Codigo = 'BOT_UBICA_TIMEOUT_SEGUNDOS')
BEGIN
    INSERT INTO cfg.ConfiguracionReglasNegocio (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion)
    VALUES
        ('BOT_UBICA_TIMEOUT_SEGUNDOS',   'Timeout Bot Voz',          '300', 'INT',     'GENERAL', 'Timeout máximo en segundos para esperar respuesta del Bot de Voz'),
        ('BOT_UBICA_MAX_INTENTOS_LINEA', 'Máx intentos por línea',   '3',   'INT',     'GENERAL', 'Número máximo de intentos por línea de contacto'),
        ('BOT_UBICA_MAX_LINEAS',         'Máx líneas por campaña',   '5',   'INT',     'GENERAL', 'Número máximo de líneas a marcar por campaña');
    PRINT '✓ Seeds cfg.ConfiguracionReglasNegocio (BOT Ubica) insertados (3 filas)';
END
ELSE
    PRINT '— Seeds cfg.ConfiguracionReglasNegocio (BOT Ubica) ya existen, omitidos';


PRINT '================================================================';
PRINT '  PARCHE V2.9 — BOT UBICA COMPLETADO';
PRINT '================================================================';
PRINT '  Tablas creadas: cat.CatalogoDiagnosticosBot,';
PRINT '                  fab.CampanasValidacionIdentidad,';
PRINT '                  fab.IntentosValidacionBot';
PRINT '  Seeds: 10 diagnósticos + 3 parámetros operativos';
PRINT '  Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '================================================================';