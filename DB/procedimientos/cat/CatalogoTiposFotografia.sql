/*
  Stored Procedures — cat.CatalogoTiposFotografia
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  NOTA: Catálogo CERRADO (3 registros fijos). No se expone Insert.

  Procedimientos:
    cat.GetAllCatalogoTiposFotografia
    cat.GetObligatoriasCatalogoTiposFotografia
    cat.UpdateCatalogoTiposFotografia
    cat.DeactivateCatalogoTiposFotografia
*/

-- ============================================================================
-- cat.GetAllCatalogoTiposFotografia
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[GetAllCatalogoTiposFotografia]
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdTipoFoto,
        Codigo,
        Nombre,
        Descripcion,
        EsObligatoria,
        OrdenRevision,
        ServicioAWS,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [cat].[CatalogoTiposFotografia]
    WHERE (@SoloActivos = 0 OR Activo = 1)
    ORDER BY OrdenRevision;
END;


-- ============================================================================
-- cat.GetObligatoriasCatalogoTiposFotografia
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[GetObligatoriasCatalogoTiposFotografia]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdTipoFoto,
        Codigo,
        Nombre,
        Descripcion,
        OrdenRevision,
        ServicioAWS
    FROM [cat].[CatalogoTiposFotografia]
    WHERE EsObligatoria = 1
      AND Activo = 1
    ORDER BY OrdenRevision;
END;


-- ============================================================================
-- cat.UpdateCatalogoTiposFotografia
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[UpdateCatalogoTiposFotografia]
    @IdTipoFoto    INT,
    @Nombre        NVARCHAR(100),
    @Descripcion   NVARCHAR(300) = NULL,
    @EsObligatoria BIT           = 1,
    @ServicioAWS   VARCHAR(30)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoTiposFotografia] WHERE IdTipoFoto = @IdTipoFoto)
        BEGIN
            RAISERROR('No se encontró el tipo de fotografía con IdTipoFoto = %d.', 16, 1, @IdTipoFoto);
        END;

        UPDATE [cat].[CatalogoTiposFotografia]
        SET
            Nombre             = @Nombre,
            Descripcion        = @Descripcion,
            EsObligatoria      = @EsObligatoria,
            ServicioAWS        = @ServicioAWS,
            FechaActualizacion = GETDATE()
        WHERE IdTipoFoto = @IdTipoFoto;

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
-- cat.DeactivateCatalogoTiposFotografia
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[DeactivateCatalogoTiposFotografia]
    @IdTipoFoto INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoTiposFotografia] WHERE IdTipoFoto = @IdTipoFoto)
        BEGIN
            RAISERROR('No se encontró el tipo de fotografía con IdTipoFoto = %d.', 16, 1, @IdTipoFoto);
        END;

        DECLARE @ObligatoriosActivos INT;
        SELECT @ObligatoriosActivos = COUNT(*)
        FROM [cat].[CatalogoTiposFotografia]
        WHERE EsObligatoria = 1 AND Activo = 1 AND IdTipoFoto <> @IdTipoFoto;

        IF @ObligatoriosActivos < 1
        BEGIN
            RAISERROR('No se puede desactivar: debe quedar al menos un tipo de foto obligatorio activo.', 16, 1);
        END;

        UPDATE [cat].[CatalogoTiposFotografia]
        SET
            Activo             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdTipoFoto = @IdTipoFoto;

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
