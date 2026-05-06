/*
  Stored Procedures — cat.CatalogoCanalesOrigen
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cat.GetAllCatalogoCanalesOrigen
    cat.InsertCatalogoCanalesOrigen
    cat.UpdateCatalogoCanalesOrigen
    cat.DeactivateCatalogoCanalesOrigen
*/

-- ============================================================================
-- cat.GetAllCatalogoCanalesOrigen
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[GetAllCatalogoCanalesOrigen]
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdCanal,
        Codigo,
        Nombre,
        Descripcion,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [cat].[CatalogoCanalesOrigen]
    WHERE (@SoloActivos = 0 OR Activo = 1)
    ORDER BY Codigo;
END;


-- ============================================================================
-- cat.InsertCatalogoCanalesOrigen
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[InsertCatalogoCanalesOrigen]
    @Codigo      VARCHAR(20),
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(300) = NULL,
    @IdCanal     INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe un canal con el código ''%s''.', 16, 1, @Codigo);
        END;

        INSERT INTO [cat].[CatalogoCanalesOrigen] (Codigo, Nombre, Descripcion)
        VALUES (@Codigo, @Nombre, @Descripcion);

        SET @IdCanal = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdCanal AS IdCanal;
END;


-- ============================================================================
-- cat.UpdateCatalogoCanalesOrigen
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[UpdateCatalogoCanalesOrigen]
    @IdCanal     INT,
    @Nombre      NVARCHAR(100),
    @Descripcion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoCanalesOrigen] WHERE IdCanal = @IdCanal)
        BEGIN
            RAISERROR('No se encontró el canal con IdCanal = %d.', 16, 1, @IdCanal);
        END;

        UPDATE [cat].[CatalogoCanalesOrigen]
        SET
            Nombre             = @Nombre,
            Descripcion        = @Descripcion,
            FechaActualizacion = GETDATE()
        WHERE IdCanal = @IdCanal;

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
-- cat.DeactivateCatalogoCanalesOrigen
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[DeactivateCatalogoCanalesOrigen]
    @IdCanal INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoCanalesOrigen] WHERE IdCanal = @IdCanal)
        BEGIN
            RAISERROR('No se encontró el canal con IdCanal = %d.', 16, 1, @IdCanal);
        END;

        IF EXISTS (
            SELECT 1 FROM [fab].[EstudiosCredito]
            WHERE IdCanal = @IdCanal
              AND EliminadoLogico = 0
              AND FechaFinalizacion IS NULL
        )
        BEGIN
            RAISERROR('No se puede desactivar el canal %d: tiene estudios en progreso asociados.', 16, 1, @IdCanal);
        END;

        UPDATE [cat].[CatalogoCanalesOrigen]
        SET
            Activo             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdCanal = @IdCanal;

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
