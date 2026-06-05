/*
  Stored Procedures — cat.CatalogoMotivosEscalamiento
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cat.GetAllCatalogoMotivosEscalamiento
    cat.InsertCatalogoMotivosEscalamiento
    cat.UpdateCatalogoMotivosEscalamiento
    cat.DeactivateCatalogoMotivosEscalamiento
*/

-- ============================================================================
-- cat.GetAllCatalogoMotivosEscalamiento
-- ============================================================================
CREATE  PROCEDURE [cat].[GetAllCatalogoMotivosEscalamiento]
    @SoloActivos BIT         = 1,
    @Origen      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdMotivo,
        Codigo,
        Nombre,
        Descripcion,
        Origen,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [cat].[CatalogoMotivosEscalamiento]
    WHERE (@SoloActivos = 0 OR Activo = 1)
      AND (@Origen IS NULL OR Origen = @Origen)
    ORDER BY Origen, Codigo;
END;


-- ============================================================================
-- cat.InsertCatalogoMotivosEscalamiento
-- ============================================================================
CREATE  PROCEDURE [cat].[InsertCatalogoMotivosEscalamiento]
    @Codigo      VARCHAR(50),
    @Nombre      NVARCHAR(150),
    @Descripcion NVARCHAR(500) = NULL,
    @Origen      VARCHAR(20)   = 'SISTEMA',
    @IdMotivo    INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe un motivo con el código ''%s''.', 16, 1, @Codigo);
        END;

        IF @Origen NOT IN ('SISTEMA','ASESOR','FRAUDE')
        BEGIN
            RAISERROR('El origen ''%s'' no es válido. Use: SISTEMA, ASESOR o FRAUDE.', 16, 1, @Origen);
        END;

        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen)
        VALUES (@Codigo, @Nombre, @Descripcion, @Origen);

        SET @IdMotivo = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdMotivo AS IdMotivo;
END;


-- ============================================================================
-- cat.UpdateCatalogoMotivosEscalamiento
-- ============================================================================
CREATE  PROCEDURE [cat].[UpdateCatalogoMotivosEscalamiento]
    @IdMotivo    INT,
    @Nombre      NVARCHAR(150),
    @Descripcion NVARCHAR(500) = NULL,
    @Origen      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE IdMotivo = @IdMotivo)
        BEGIN
            RAISERROR('No se encontró el motivo con IdMotivo = %d.', 16, 1, @IdMotivo);
        END;

        IF @Origen NOT IN ('SISTEMA','ASESOR','FRAUDE')
        BEGIN
            RAISERROR('El origen ''%s'' no es válido. Use: SISTEMA, ASESOR o FRAUDE.', 16, 1, @Origen);
        END;

        UPDATE [cat].[CatalogoMotivosEscalamiento]
        SET
            Nombre             = @Nombre,
            Descripcion        = @Descripcion,
            Origen             = @Origen,
            FechaActualizacion = GETDATE()
        WHERE IdMotivo = @IdMotivo;

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
-- cat.DeactivateCatalogoMotivosEscalamiento
-- ============================================================================
CREATE  PROCEDURE [cat].[DeactivateCatalogoMotivosEscalamiento]
    @IdMotivo INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE IdMotivo = @IdMotivo)
        BEGIN
            RAISERROR('No se encontró el motivo con IdMotivo = %d.', 16, 1, @IdMotivo);
        END;

        IF EXISTS (
            SELECT 1 FROM [fab].[EscalamientosFabrica]
            WHERE IdMotivoEscalamiento = @IdMotivo AND FechaResolucion IS NULL
        )
        BEGIN
            RAISERROR('No se puede desactivar el motivo %d: tiene escalamientos sin resolver.', 16, 1, @IdMotivo);
        END;

        UPDATE [cat].[CatalogoMotivosEscalamiento]
        SET
            Activo             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdMotivo = @IdMotivo;

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
