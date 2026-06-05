/*
  Stored Procedures — cfg.FasesEstudio
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetAllFasesEstudio
    cfg.GetByIdFasesEstudio
    cfg.InsertFasesEstudio
    cfg.UpdateFasesEstudio
    cfg.DeactivateFasesEstudio
*/

-- ============================================================================
-- cfg.GetAllFasesEstudio
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetAllFasesEstudio]
    @SoloActivas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdFase,
        Codigo,
        Nombre,
        OrdenEjecucion,
        Descripcion,
        Activa
    FROM [cfg].[FasesEstudio]
    WHERE (@SoloActivas = 0 OR Activa = 1)
    ORDER BY OrdenEjecucion;
END;


-- ============================================================================
-- cfg.GetByIdFasesEstudio
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetByIdFasesEstudio]
    @IdFase INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdFase,
        Codigo,
        Nombre,
        OrdenEjecucion,
        Descripcion,
        Activa
    FROM [cfg].[FasesEstudio]
    WHERE IdFase = @IdFase;
END;


-- ============================================================================
-- cfg.InsertFasesEstudio
-- ============================================================================
CREATE  PROCEDURE [cfg].[InsertFasesEstudio]
    @Codigo          VARCHAR(30),
    @Nombre          NVARCHAR(100),
    @OrdenEjecucion  INT,
    @Descripcion     NVARCHAR(500) = NULL,
    @IdFase          INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [cfg].[FasesEstudio] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe una fase con el código ''%s''.', 16, 1, @Codigo);
        END;

        IF EXISTS (SELECT 1 FROM [cfg].[FasesEstudio] WHERE OrdenEjecucion = @OrdenEjecucion)
        BEGIN
            RAISERROR('Ya existe una fase con el orden de ejecución %d.', 16, 1, @OrdenEjecucion);
        END;

        INSERT INTO [cfg].[FasesEstudio] (Codigo, Nombre, OrdenEjecucion, Descripcion)
        VALUES (@Codigo, @Nombre, @OrdenEjecucion, @Descripcion);

        SET @IdFase = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdFase AS IdFase;
END;


-- ============================================================================
-- cfg.UpdateFasesEstudio
-- ============================================================================
CREATE  PROCEDURE [cfg].[UpdateFasesEstudio]
    @IdFase          INT,
    @Nombre          NVARCHAR(100),
    @OrdenEjecucion  INT,
    @Descripcion     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[FasesEstudio] WHERE IdFase = @IdFase)
        BEGIN
            RAISERROR('No se encontró la fase con IdFase = %d.', 16, 1, @IdFase);
        END;

        IF EXISTS (
            SELECT 1 FROM [cfg].[FasesEstudio]
            WHERE OrdenEjecucion = @OrdenEjecucion AND IdFase <> @IdFase
        )
        BEGIN
            RAISERROR('El orden de ejecución %d ya está en uso por otra fase.', 16, 1, @OrdenEjecucion);
        END;

        UPDATE [cfg].[FasesEstudio]
        SET
            Nombre         = @Nombre,
            OrdenEjecucion = @OrdenEjecucion,
            Descripcion    = @Descripcion
        WHERE IdFase = @IdFase;

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
-- cfg.DeactivateFasesEstudio
-- ============================================================================
CREATE  PROCEDURE [cfg].[DeactivateFasesEstudio]
    @IdFase INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[FasesEstudio] WHERE IdFase = @IdFase)
        BEGIN
            RAISERROR('No se encontró la fase con IdFase = %d.', 16, 1, @IdFase);
        END;

        IF EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE IdFase = @IdFase AND Activo = 1)
        BEGIN
            RAISERROR('No se puede desactivar la fase %d porque tiene pasos activos asociados.', 16, 1, @IdFase);
        END;

        UPDATE [cfg].[FasesEstudio]
        SET Activa = 0
        WHERE IdFase = @IdFase;

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
