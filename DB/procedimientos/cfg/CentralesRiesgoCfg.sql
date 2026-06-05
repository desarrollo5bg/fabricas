/*
  Stored Procedures — cfg.CentralesRiesgoCfg
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetAllCentralesRiesgoCfg
    cfg.GetByTipoServicioCentralesRiesgoCfg
    cfg.InsertCentralesRiesgoCfg
    cfg.UpdateCentralesRiesgoCfg
    cfg.DeactivateCentralesRiesgoCfg
*/

-- ============================================================================
-- cfg.GetAllCentralesRiesgoCfg
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetAllCentralesRiesgoCfg]
    @SoloActivas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdConfig,
        TipoServicio,
        CentralActiva,
        NombreServicio,
        TablaLogExterna,
        Canal,
        Activa,
        FechaVigencia,
        Observaciones,
        FechaCreacion,
        FechaActualizacion
    FROM [cfg].[CentralesRiesgoCfg]
    WHERE (@SoloActivas = 0 OR Activa = 1)
    ORDER BY TipoServicio, CentralActiva, Canal;
END;


-- ============================================================================
-- cfg.GetByTipoServicioCentralesRiesgoCfg
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetByTipoServicioCentralesRiesgoCfg]
    @TipoServicio VARCHAR(30),
    @Canal        VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdConfig,
        TipoServicio,
        CentralActiva,
        NombreServicio,
        TablaLogExterna,
        Canal,
        Activa,
        FechaVigencia,
        Observaciones
    FROM [cfg].[CentralesRiesgoCfg]
    WHERE Activa = 1
      AND TipoServicio = @TipoServicio
      AND (Canal IS NULL OR Canal = @Canal)
    ORDER BY Canal DESC;
END;


-- ============================================================================
-- cfg.InsertCentralesRiesgoCfg
-- ============================================================================
CREATE  PROCEDURE [cfg].[InsertCentralesRiesgoCfg]
    @TipoServicio    VARCHAR(30),
    @CentralActiva   VARCHAR(30),
    @NombreServicio  VARCHAR(50),
    @TablaLogExterna VARCHAR(100),
    @Canal           VARCHAR(20)   = NULL,
    @FechaVigencia   DATE          = NULL,
    @Observaciones   NVARCHAR(500) = NULL,
    @IdConfig        INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @TipoServicio NOT IN ('VIABILIDAD','CONTACTABILIDAD')
        BEGIN
            RAISERROR('El tipo de servicio ''%s'' no es válido. Use: VIABILIDAD o CONTACTABILIDAD.', 16, 1, @TipoServicio);
        END;

        IF @CentralActiva NOT IN ('DATACREDITO','CIFIN','COMBINADO')
        BEGIN
            RAISERROR('La central ''%s'' no es válida. Use: DATACREDITO, CIFIN o COMBINADO.', 16, 1, @CentralActiva);
        END;

        IF @NombreServicio NOT IN ('PRESELECTA','VARIABLES_ADVISER','RECONOCER','UBICA','COMBINADO_VIABILIDAD','COMBINADO_CONTACTABILIDAD')
        BEGIN
            RAISERROR('El nombre de servicio ''%s'' no es válido.', 16, 1, @NombreServicio);
        END;

        IF @Canal IS NOT NULL AND @Canal NOT IN ('TIENDA','WEB','HANDOFF')
        BEGIN
            RAISERROR('El canal ''%s'' no es válido. Use: TIENDA, WEB, HANDOFF o NULL.', 16, 1, @Canal);
        END;

        SET @FechaVigencia = ISNULL(@FechaVigencia, CAST(GETDATE() AS DATE));

        INSERT INTO [cfg].[CentralesRiesgoCfg] (
            TipoServicio, CentralActiva, NombreServicio, TablaLogExterna,
            Canal, FechaVigencia, Observaciones
        )
        VALUES (
            @TipoServicio, @CentralActiva, @NombreServicio, @TablaLogExterna,
            @Canal, @FechaVigencia, @Observaciones
        );

        SET @IdConfig = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdConfig AS IdConfig;
END;


-- ============================================================================
-- cfg.UpdateCentralesRiesgoCfg
-- ============================================================================
CREATE  PROCEDURE [cfg].[UpdateCentralesRiesgoCfg]
    @IdConfig        INT,
    @CentralActiva   VARCHAR(30),
    @NombreServicio  VARCHAR(50),
    @TablaLogExterna VARCHAR(100),
    @Canal           VARCHAR(20)   = NULL,
    @Observaciones   NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[CentralesRiesgoCfg] WHERE IdConfig = @IdConfig)
        BEGIN
            RAISERROR('No se encontró la configuración con IdConfig = %d.', 16, 1, @IdConfig);
        END;

        IF @CentralActiva NOT IN ('DATACREDITO','CIFIN','COMBINADO')
        BEGIN
            RAISERROR('La central ''%s'' no es válida. Use: DATACREDITO, CIFIN o COMBINADO.', 16, 1, @CentralActiva);
        END;

        IF @Canal IS NOT NULL AND @Canal NOT IN ('TIENDA','WEB','HANDOFF')
        BEGIN
            RAISERROR('El canal ''%s'' no es válido. Use: TIENDA, WEB, HANDOFF o NULL.', 16, 1, @Canal);
        END;

        UPDATE [cfg].[CentralesRiesgoCfg]
        SET
            CentralActiva      = @CentralActiva,
            NombreServicio     = @NombreServicio,
            TablaLogExterna    = @TablaLogExterna,
            Canal              = @Canal,
            Observaciones      = @Observaciones,
            FechaActualizacion = GETDATE()
        WHERE IdConfig = @IdConfig;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;
END;


-- ============================================================================
-- cfg.DeactivateCentralesRiesgoCfg
-- ============================================================================
CREATE  PROCEDURE [cfg].[DeactivateCentralesRiesgoCfg]
    @IdConfig INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[CentralesRiesgoCfg] WHERE IdConfig = @IdConfig)
        BEGIN
            RAISERROR('No se encontró la configuración con IdConfig = %d.', 16, 1, @IdConfig);
        END;

        UPDATE [cfg].[CentralesRiesgoCfg]
        SET
            Activa             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdConfig = @IdConfig;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;
END;
