/*
  Stored Procedures — fab.EstudiosCredito
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos principales para gestión del ciclo de vida de estudios de crédito.
  - InsertEstudioCredito: C-01 CrearEstudio — Crear estudio inicial con estado BORRADOR
  - GetEstadoEstudio: C-02 ObtenerEstadoEstudio — Obtener estado completo del estudio con detalles
  - AvanzarPaso: C-05 AvanzarPaso — Avanzar al siguiente paso de la máquina de estados
  - ActivarCupo: C-14 ActivarCupo — Activar cupo preaprobado

  Procedimientos:
    fab.InsertEstudioCredito
    fab.GetEstadoEstudio
    fab.AvanzarPaso
    fab.ActivarCupo
*/

-- ============================================================================
-- fab.InsertEstudioCredito (C-01 CrearEstudio)
-- ============================================================================
CREATE  PROCEDURE [fab].[InsertEstudioCredito]
    @NitTercero         VARCHAR(20),
    @IdCanal            INT,
    @IdOperadorCreador  INT,
    @Canal              VARCHAR(20) = NULL,
    @IdEstudio          BIGINT      OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el tercero existe en fab.TercerosFabricas
        IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = @NitTercero)
        BEGIN
            RAISERROR('El tercero con NIT ''%s'' no existe en fab.TercerosFabricas.', 16, 1, @NitTercero);
            RETURN;
        END;

        -- Validar que el canal existe en cat.CatalogoCanalesOrigen
        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoCanalesOrigen] WHERE IdCanal = @IdCanal)
        BEGIN
            RAISERROR('El canal con IdCanal = %d no existe en cat.CatalogoCanalesOrigen.', 16, 1, @IdCanal);
            RETURN;
        END;

        -- Obtener primer IdPaso activo ordenado por OrdenGlobal
        DECLARE @IdPasoActual INT;
        SELECT TOP 1 @IdPasoActual = IdPaso
        FROM [cfg].[PasosEstudio]
        WHERE Activo = 1
        ORDER BY OrdenGlobal ASC;

        IF @IdPasoActual IS NULL
        BEGIN
            RAISERROR('No hay pasos activos configurados en cfg.PasosEstudio.', 16, 1);
            RETURN;
        END;

        -- Obtener código de estado inicial (Grupo = 'INICIAL')
        DECLARE @CodigoEstadoInicial VARCHAR(40);
        SELECT TOP 1 @CodigoEstadoInicial = Codigo
        FROM [cfg].[EstadosEstudio]
        WHERE Grupo = 'INICIAL'
        ORDER BY IdEstado ASC;

        IF @CodigoEstadoInicial IS NULL
        BEGIN
            RAISERROR('No hay estado inicial configurado en cfg.EstadosEstudio.', 16, 1);
            RETURN;
        END;

        -- Obtener IdEstado correspondiente al código inicial
        DECLARE @IdEstadoInicial INT;
        SELECT @IdEstadoInicial = IdEstado
        FROM [cfg].[EstadosEstudio]
        WHERE Codigo = @CodigoEstadoInicial;

        -- Obtener NitComercio de la bodega asociada al operador creador (si existe)
        DECLARE @NitComercio VARCHAR(20);
        SET @NitComercio = @NitTercero;  -- Por defecto, mismo NIT del tercero

        -- INSERT en fab.EstudiosCredito
        INSERT INTO [fab].[EstudiosCredito] (
            NitTercero,
            NitComercio,
            IdEstadoActual,
            IdPasoActual,
            IdCanal,
            IdAsesor,
            FechaInicio,
            FechaUltimaActividad,
            FechaCreacion,
            FechaActualizacion,
            EliminadoLogico
        )
        VALUES (
            @NitTercero,
            @NitComercio,
            @IdEstadoInicial,
            @IdPasoActual,
            @IdCanal,
            @IdOperadorCreador,
            GETDATE(),
            GETDATE(),
            GETDATE(),
            GETDATE(),
            0
        );

        SET @IdEstudio = SCOPE_IDENTITY();

        -- INSERT en aud.HistorialEstados para registrar creación
        INSERT INTO [aud].[HistorialEstados] (
            IdEstudio,
            IdEstadoAnterior,
            IdEstadoNuevo,
            IdPasoRelacionado,
            IdUsuarioAccion,
            TipoUsuario,
            MotivoTransicion,
            FechaTransicion
        )
        VALUES (
            @IdEstudio,
            NULL,
            @IdEstadoInicial,
            @IdPasoActual,
            @IdOperadorCreador,
            'ASESOR',
            'Creación inicial del estudio',
            GETDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEstudio AS [IdNuevoRegistro];
END;


-- ============================================================================
-- fab.GetEstadoEstudio (C-02 ObtenerEstadoEstudio)
-- ============================================================================
CREATE   PROCEDURE [fab].[GetEstadoEstudio]
    @IdEstudio  BIGINT        = NULL,
    @NitTercero VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Retomar por NIT: resolver el IdEstudio del estudio activo más reciente
    IF @IdEstudio IS NULL AND @NitTercero IS NOT NULL
    BEGIN
        SELECT TOP 1 @IdEstudio = IdEstudio
        FROM [fab].[EstudiosCredito]
        WHERE NitTercero = @NitTercero
          AND EliminadoLogico = 0
        ORDER BY FechaCreacion DESC;
    END

    IF @IdEstudio IS NULL
        RETURN;

    SELECT
        ec.IdEstudio,
        ec.NitTercero,
        ec.NitComercio,
        ec.CelularCliente,
        ec.IdBodega,
        ec.IdAsesor,
        ec.NitAsesor,
        ec.IdCanal,
        ec.IdEstadoActual,
        ec.IdPasoActual,
        ec.MotivoRechazo,
        ec.CupoPreaprobado,
        ec.EsPreaprobado,
        ec.EsReactivacion,
        ec.RenunciaCupo,
        ec.RequiereCallCenter,
        ec.EsCupoExpress,
        ec.TipoCierre,
        ec.EmailCliente,
        ec.EmailUbica,
        ec.SlugPasoWeb,
        ec.FechaUltimoAbandono,
        ec.DepartamentoCapturado,
        ec.CiudadCapturada,
        ec.DireccionCapturada,
        ec.BarrioCapturado,
        ec.FechaInicio,
        ec.FechaUltimaActividad,
        ec.FechaFinalizacion,
        ec.FechaPausa,
        ec.FechaCreacion,
        ec.FechaActualizacion,
        ec.EliminadoLogico,
        ec.IdCorrelacion,
        ec.IdEscalamientoActivo,
        ec.FotografiasAprobadas,
        ec.EstadoRevisionFotos,
        ec.IdValidacionAsesor,
        -- Detalles unidos
        ce.Codigo AS [CodigoEstado],
        ce.Nombre AS [NombreEstado],
        ps.Nombre AS [NombrePasoActual],
        fs.Nombre AS [NombreFase],
        tf.NombreTercero,
        cc.Nombre AS [NombreCanal]
    FROM [fab].[EstudiosCredito] ec
    LEFT JOIN [cfg].[EstadosEstudio] ce ON ce.IdEstado = ec.IdEstadoActual
    LEFT JOIN [cfg].[PasosEstudio] ps ON ps.IdPaso = ec.IdPasoActual
    LEFT JOIN [cfg].[FasesEstudio] fs ON fs.IdFase = ps.IdFase
    LEFT JOIN [fab].[TercerosFabricas] tf ON tf.NitTercero = ec.NitTercero
    LEFT JOIN [cat].[CatalogoCanalesOrigen] cc ON cc.IdCanal = ec.IdCanal
    WHERE ec.IdEstudio = @IdEstudio;

END;


-- ============================================================================
-- fab.AvanzarPaso (C-05 AvanzarPaso)
-- ============================================================================
CREATE  PROCEDURE [fab].[AvanzarPaso]
    @IdEstudio           BIGINT,
    @IdPasoCompletado    INT,
    @Resultado           VARCHAR(20) = 'COMPLETADO',
    @Observaciones       NVARCHAR(500) = NULL,
    @IdPasoSiguiente     INT OUTPUT,
    @EsUltimoPaso        BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el estudio existe
        IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio)
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Obtener OrdenGlobal del paso completado
        DECLARE @OrdenGlobalActual INT;
        SELECT @OrdenGlobalActual = OrdenGlobal
        FROM [cfg].[PasosEstudio]
        WHERE IdPaso = @IdPasoCompletado;

        IF @OrdenGlobalActual IS NULL
        BEGIN
            RAISERROR('El paso con IdPaso = %d no existe.', 16, 1, @IdPasoCompletado);
            RETURN;
        END;

        -- Obtener siguiente paso activo
        SELECT TOP 1 @IdPasoSiguiente = IdPaso
        FROM [cfg].[PasosEstudio]
        WHERE Activo = 1
          AND OrdenGlobal > @OrdenGlobalActual
        ORDER BY OrdenGlobal ASC;

        -- Determinar si es último paso
        SET @EsUltimoPaso = CASE WHEN @IdPasoSiguiente IS NULL THEN 1 ELSE 0 END;

        -- UPDATE fab.EstudiosCredito con nuevo paso
        UPDATE [fab].[EstudiosCredito]
        SET
            IdPasoActual       = @IdPasoSiguiente,
            FechaUltimaActividad = GETDATE(),
            FechaActualizacion = GETDATE()
        WHERE IdEstudio = @IdEstudio;

        -- Log en aud.HistorialEstados
        INSERT INTO [aud].[HistorialEstados] (
            IdEstudio,
            IdEstadoAnterior,
            IdEstadoNuevo,
            IdPasoRelacionado,
            TipoUsuario,
            MotivoTransicion,
            FechaTransicion
        )
        SELECT
            @IdEstudio,
            IdEstadoActual,
            IdEstadoActual,  -- Estado no cambia, solo el paso
            @IdPasoSiguiente,
            'SISTEMA',
            'Avance de paso: ' + COALESCE(@Observaciones, @Resultado),
            GETDATE()
        FROM [fab].[EstudiosCredito]
        WHERE IdEstudio = @IdEstudio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT
        @IdEstudio AS IdEstudio,
        @IdPasoCompletado AS IdPasoAnterior,
        @IdPasoSiguiente AS IdPasoSiguiente,
        @EsUltimoPaso AS EsUltimoPaso;

END;


-- ============================================================================
-- fab.ActivarCupo (C-14 ActivarCupo)
-- ============================================================================
CREATE  PROCEDURE [fab].[ActivarCupo]
    @IdEstudio              BIGINT,
    @IdOperadorAprobador    INT,
    @MontoAprobado          DECIMAL(18,2),
    @Observaciones          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el estudio existe
        DECLARE @IdEstadoActual INT;
        SELECT @IdEstadoActual = IdEstadoActual
        FROM [fab].[EstudiosCredito]
        WHERE IdEstudio = @IdEstudio;

        IF @IdEstadoActual IS NULL
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Validar que no esté ya en estado terminal (aprobado o rechazado)
        DECLARE @EsTerminal BIT;
        SELECT @EsTerminal = EsTerminal
        FROM [cfg].[EstadosEstudio]
        WHERE IdEstado = @IdEstadoActual;

        IF @EsTerminal = 1
        BEGIN
            RAISERROR('El estudio ya está en estado terminal y no puede ser aprobado nuevamente.', 16, 1);
            RETURN;
        END;

        -- Obtener IdEstado del estado APROBADO
        DECLARE @IdEstadoAprobado INT;
        SELECT TOP 1 @IdEstadoAprobado = IdEstado
        FROM [cfg].[EstadosEstudio]
        WHERE Codigo = 'APROBADO'
        ORDER BY IdEstado ASC;

        IF @IdEstadoAprobado IS NULL
        BEGIN
            RAISERROR('No existe estado APROBADO configurado en cfg.EstadosEstudio.', 16, 1);
            RETURN;
        END;

        -- UPDATE fab.EstudiosCredito
        UPDATE [fab].[EstudiosCredito]
        SET
            IdEstadoActual     = @IdEstadoAprobado,
            CupoPreaprobado    = @MontoAprobado,
            EsPreaprobado      = 1,
            FechaFinalizacion  = GETDATE(),
            FechaActualizacion = GETDATE()
        WHERE IdEstudio = @IdEstudio;

        -- Log en aud.HistorialEstados
        INSERT INTO [aud].[HistorialEstados] (
            IdEstudio,
            IdEstadoAnterior,
            IdEstadoNuevo,
            IdUsuarioAccion,
            TipoUsuario,
            MotivoTransicion,
            FechaTransicion
        )
        VALUES (
            @IdEstudio,
            @IdEstadoActual,
            @IdEstadoAprobado,
            @IdOperadorAprobador,
            'ASESOR',
            'Activación de cupo: ' + COALESCE(@Observaciones, CAST(@MontoAprobado AS VARCHAR(20))),
            GETDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT
        @IdEstudio AS IdEstudio,
        'APROBADO' AS CodigoEstadoNuevo,
        GETDATE() AS FechaActivacion;

END;
