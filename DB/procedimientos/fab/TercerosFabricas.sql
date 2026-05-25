/*
  Stored Procedures — fab.TercerosFabricas
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para gestión de terceros (clientes) en el sistema de fábricas.
  - UpsertTerceroFabrica: C-07 Insertar o actualizar tercero
  - VerificarElegibilidad: C-06 Verificar si un tercero es elegible para un estudio

  Procedimientos:
    fab.UpsertTerceroFabrica
    fab.VerificarElegibilidad
*/

-- ============================================================================
-- fab.UpsertTerceroFabrica (C-07)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[UpsertTerceroFabrica]
    @NitTercero                 VARCHAR(20),
    @NombreTercero              NVARCHAR(200) = NULL,
    @EstadoTercero              VARCHAR(20) = NULL,
    @TieneCupoActivo            BIT = NULL,
    @EstaBloqueadoFabricas      BIT = NULL,
    @MotivoBloqueo              VARCHAR(100) = NULL,
    @FechaBloqueo               DATETIME2(3) = NULL,
    @FechaDesbloqueo            DATETIME2(3) = NULL,
    @TieneRegistroBiometrico   BIT = NULL,
    @FechaRegistroBiometrico   DATETIME2(3) = NULL,
    @PuntajeCredito             DECIMAL(5,2) = NULL,
    @FechaUltimaEvaluacion      DATETIME2(3) = NULL,
    @CelularPrincipal           VARCHAR(20) = NULL,
    @CelularWhatsApp            VARCHAR(20) = NULL,
    @IdTercero                  INT OUTPUT,
    @EsNuevo                    BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si existe
        DECLARE @ExisteRegistro BIT;
        SELECT @ExisteRegistro = CASE WHEN IdTerceroFabricas IS NOT NULL THEN 1 ELSE 0 END
        FROM [fab].[TercerosFabricas]
        WHERE NitTercero = @NitTercero;

        IF @ExisteRegistro = 1
        BEGIN
            -- UPDATE
            SET @EsNuevo = 0;
            
            UPDATE [fab].[TercerosFabricas]
            SET
                NombreTercero               = COALESCE(@NombreTercero, NombreTercero),
                EstadoTercero               = COALESCE(@EstadoTercero, EstadoTercero),
                TieneCupoActivo             = COALESCE(@TieneCupoActivo, TieneCupoActivo),
                EstaBloqueadoFabricas       = COALESCE(@EstaBloqueadoFabricas, EstaBloqueadoFabricas),
                MotivoBloqueo               = COALESCE(@MotivoBloqueo, MotivoBloqueo),
                FechaBloqueo                = COALESCE(@FechaBloqueo, FechaBloqueo),
                FechaDesbloqueo             = COALESCE(@FechaDesbloqueo, FechaDesbloqueo),
                TieneRegistroBiometrico    = COALESCE(@TieneRegistroBiometrico, TieneRegistroBiometrico),
                FechaRegistroBiometrico    = COALESCE(@FechaRegistroBiometrico, FechaRegistroBiometrico),
                PuntajeCredito              = COALESCE(@PuntajeCredito, PuntajeCredito),
                FechaUltimaEvaluacion       = COALESCE(@FechaUltimaEvaluacion, FechaUltimaEvaluacion),
                CelularPrincipal            = COALESCE(@CelularPrincipal, CelularPrincipal),
                CelularWhatsApp             = COALESCE(@CelularWhatsApp, CelularWhatsApp),
                FechaModificacion           = GETDATE()
            WHERE NitTercero = @NitTercero;

            SELECT @IdTercero = IdTerceroFabricas
            FROM [fab].[TercerosFabricas]
            WHERE NitTercero = @NitTercero;
        END
        ELSE
        BEGIN
            -- INSERT
            SET @EsNuevo = 1;
            
            INSERT INTO [fab].[TercerosFabricas] (
                NitTercero,
                NombreTercero,
                EstadoTercero,
                TieneCupoActivo,
                EstaBloqueadoFabricas,
                MotivoBloqueo,
                FechaBloqueo,
                FechaDesbloqueo,
                TieneRegistroBiometrico,
                FechaRegistroBiometrico,
                PuntajeCredito,
                FechaUltimaEvaluacion,
                CelularPrincipal,
                CelularWhatsApp,
                FechaCreacion,
                FechaModificacion
            )
            VALUES (
                @NitTercero,
                COALESCE(@NombreTercero, 'SIN_NOMBRE'),
                COALESCE(@EstadoTercero, 'ACTIVO'),
                COALESCE(@TieneCupoActivo, 0),
                COALESCE(@EstaBloqueadoFabricas, 0),
                @MotivoBloqueo,
                @FechaBloqueo,
                @FechaDesbloqueo,
                COALESCE(@TieneRegistroBiometrico, 0),
                @FechaRegistroBiometrico,
                @PuntajeCredito,
                @FechaUltimaEvaluacion,
                @CelularPrincipal,
                @CelularWhatsApp,
                GETDATE(),
                GETDATE()
            );

            SET @IdTercero = SCOPE_IDENTITY();
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdTercero AS IdTercero, @EsNuevo AS EsNuevo;

END;


-- ============================================================================
-- fab.VerificarElegibilidad (C-06)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[VerificarElegibilidad]
    @NitTercero VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EsElegible BIT = 1;
    DECLARE @EsBloqueado BIT = 0;
    DECLARE @TieneEstudioActivo BIT = 0;
    DECLARE @EnCoolingOff BIT = 0;
    DECLARE @MotivoInelegibilidad VARCHAR(200) = NULL;
    DECLARE @CoolingOffDias INT = 30;

    -- Verificar si existe tercero
    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = @NitTercero)
    BEGIN
        SET @EsElegible = 0;
        SET @MotivoInelegibilidad = 'Tercero no existe en el sistema';
        
        SELECT
            @EsElegible AS EsElegible,
            CAST(0 AS BIT) AS EsBloqueado,
            CAST(0 AS BIT) AS TieneEstudioActivo,
            CAST(0 AS BIT) AS EnCoolingOff,
            @MotivoInelegibilidad AS MotivoInelegibilidad;
        RETURN;
    END;

    -- Verificar si está bloqueado
    SELECT @EsBloqueado = EstaBloqueadoFabricas
    FROM [fab].[TercerosFabricas]
    WHERE NitTercero = @NitTercero;

    IF @EsBloqueado = 1
    BEGIN
        SET @EsElegible = 0;
        SET @MotivoInelegibilidad = 'Tercero bloqueado en fábricas';
    END;

    -- Verificar si tiene estudio activo (no terminal)
    IF EXISTS (
        SELECT 1
        FROM [fab].[EstudiosCredito] ec
        JOIN [cfg].[CatalogoEstados] ce ON ce.IdEstado = ec.IdEstadoActual
        WHERE ec.NitTercero = @NitTercero
          AND ce.EsTerminal = 0
          AND ec.EliminadoLogico = 0
    )
    BEGIN
        SET @TieneEstudioActivo = 1;
        IF @EsElegible = 1
        BEGIN
            SET @EsElegible = 0;
            SET @MotivoInelegibilidad = 'El tercero ya tiene un estudio activo';
        END;
    END;

    -- Obtener días de enfriamiento (cooling-off) de configuración
    SELECT TOP 1 @CoolingOffDias = TRY_CAST([Valor] AS INT)
    FROM [cfg].[ConfiguracionReglasNegocio]
    WHERE Codigo = 'COOLING_OFF_DIAS'
      AND VigenciaDesde <= CAST(GETDATE() AS DATE)
      AND (VigenciaHasta IS NULL OR VigenciaHasta >= CAST(GETDATE() AS DATE));

    -- Si no está configurado, usar valor por defecto
    IF @CoolingOffDias IS NULL SET @CoolingOffDias = 30;

    -- Verificar cooling-off: estudios completados/rechazados en los últimos N días
    IF EXISTS (
        SELECT 1
        FROM [fab].[EstudiosCredito] ec
        JOIN [cfg].[CatalogoEstados] ce ON ce.IdEstado = ec.IdEstadoActual
        WHERE ec.NitTercero = @NitTercero
          AND ce.EsTerminal = 1
          AND DATEDIFF(DAY, ec.FechaFinalizacion, GETDATE()) <= @CoolingOffDias
          AND ec.EliminadoLogico = 0
    )
    BEGIN
        SET @EnCoolingOff = 1;
        IF @EsElegible = 1
        BEGIN
            SET @EsElegible = 0;
            SET @MotivoInelegibilidad = 'Tercero en período de enfriamiento (cooling-off)';
        END;
    END;

    SELECT
        @EsElegible AS EsElegible,
        @EsBloqueado AS EsBloqueado,
        @TieneEstudioActivo AS TieneEstudioActivo,
        @EnCoolingOff AS EnCoolingOff,
        @MotivoInelegibilidad AS MotivoInelegibilidad;

END;
