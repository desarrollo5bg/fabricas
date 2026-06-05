/*
  Stored Procedures — cat.CatalogoReglasFraude
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cat.GetAllCatalogoReglasFraude
    cat.InsertCatalogoReglasFraude
    cat.UpdateCatalogoReglasFraude
    cat.DeactivateCatalogoReglasFraude
*/

-- ============================================================================
-- cat.GetAllCatalogoReglasFraude
-- ============================================================================
CREATE  PROCEDURE [cat].[GetAllCatalogoReglasFraude]
    @SoloActivas BIT         = 1,
    @NivelRiesgo VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdReglaFraude,
        Codigo,
        Nombre,
        Descripcion,
        NivelRiesgo,
        AccionAutomatica,
        Activa,
        FechaCreacion,
        FechaActualizacion
    FROM [cat].[CatalogoReglasFraude]
    WHERE (@SoloActivas = 0 OR Activa = 1)
      AND (@NivelRiesgo IS NULL OR NivelRiesgo = @NivelRiesgo)
    ORDER BY NivelRiesgo, Codigo;
END;


-- ============================================================================
-- cat.InsertCatalogoReglasFraude
-- ============================================================================
CREATE  PROCEDURE [cat].[InsertCatalogoReglasFraude]
    @Codigo           VARCHAR(50),
    @Nombre           NVARCHAR(150),
    @Descripcion      NVARCHAR(500) = NULL,
    @NivelRiesgo      VARCHAR(10)   = 'MEDIO',
    @AccionAutomatica VARCHAR(30)   = 'ESCALAR',
    @IdReglaFraude    INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe una regla con el código ''%s''.', 16, 1, @Codigo);
        END;

        IF @NivelRiesgo NOT IN ('BAJO','MEDIO','ALTO','CRITICO')
        BEGIN
            RAISERROR('El nivel de riesgo ''%s'' no es válido. Use: BAJO, MEDIO, ALTO o CRITICO.', 16, 1, @NivelRiesgo);
        END;

        IF @AccionAutomatica NOT IN ('ESCALAR','BLOQUEAR','NOTIFICAR','SOLO_REGISTRO')
        BEGIN
            RAISERROR('La acción ''%s'' no es válida. Use: ESCALAR, BLOQUEAR, NOTIFICAR o SOLO_REGISTRO.', 16, 1, @AccionAutomatica);
        END;

        INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica)
        VALUES (@Codigo, @Nombre, @Descripcion, @NivelRiesgo, @AccionAutomatica);

        SET @IdReglaFraude = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdReglaFraude AS IdReglaFraude;
END;


-- ============================================================================
-- cat.UpdateCatalogoReglasFraude
-- ============================================================================
CREATE  PROCEDURE [cat].[UpdateCatalogoReglasFraude]
    @IdReglaFraude    INT,
    @Nombre           NVARCHAR(150),
    @Descripcion      NVARCHAR(500) = NULL,
    @NivelRiesgo      VARCHAR(10),
    @AccionAutomatica VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE IdReglaFraude = @IdReglaFraude)
        BEGIN
            RAISERROR('No se encontró la regla con IdReglaFraude = %d.', 16, 1, @IdReglaFraude);
        END;

        IF @NivelRiesgo NOT IN ('BAJO','MEDIO','ALTO','CRITICO')
        BEGIN
            RAISERROR('El nivel de riesgo ''%s'' no es válido. Use: BAJO, MEDIO, ALTO o CRITICO.', 16, 1, @NivelRiesgo);
        END;

        IF @AccionAutomatica NOT IN ('ESCALAR','BLOQUEAR','NOTIFICAR','SOLO_REGISTRO')
        BEGIN
            RAISERROR('La acción ''%s'' no es válida. Use: ESCALAR, BLOQUEAR, NOTIFICAR o SOLO_REGISTRO.', 16, 1, @AccionAutomatica);
        END;

        UPDATE [cat].[CatalogoReglasFraude]
        SET
            Nombre             = @Nombre,
            Descripcion        = @Descripcion,
            NivelRiesgo        = @NivelRiesgo,
            AccionAutomatica   = @AccionAutomatica,
            FechaActualizacion = GETDATE()
        WHERE IdReglaFraude = @IdReglaFraude;

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
-- cat.DeactivateCatalogoReglasFraude
-- ============================================================================
CREATE  PROCEDURE [cat].[DeactivateCatalogoReglasFraude]
    @IdReglaFraude INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE IdReglaFraude = @IdReglaFraude)
        BEGIN
            RAISERROR('No se encontró la regla con IdReglaFraude = %d.', 16, 1, @IdReglaFraude);
        END;

        IF EXISTS (
            SELECT 1 FROM [aud].[AlertasFraude]
            WHERE IdReglaFraude = @IdReglaFraude AND AccionTomada = 'PENDIENTE'
        )
        BEGIN
            RAISERROR('No se puede desactivar la regla %d: tiene alertas pendientes de resolución.', 16, 1, @IdReglaFraude);
        END;

        UPDATE [cat].[CatalogoReglasFraude]
        SET
            Activa             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdReglaFraude = @IdReglaFraude;

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
