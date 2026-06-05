/*
  Stored Procedures — cfg.ConfiguracionReglasNegocio
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetAllConfiguracionReglasNegocio
    cfg.GetByClaveConfiguracionReglasNegocio
    cfg.InsertConfiguracionReglasNegocio
    cfg.UpdateConfiguracionReglasNegocio
*/

-- ============================================================================
-- cfg.GetAllConfiguracionReglasNegocio
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetAllConfiguracionReglasNegocio]
    @Categoria VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdRegla,
        Codigo,
        Nombre,
        Valor,
        TipoDato,
        Categoria,
        Descripcion,
        VigenciaDesde,
        VigenciaHasta,
        FechaCreacion,
        FechaActualizacion
    FROM [cfg].[ConfiguracionReglasNegocio]
    WHERE (@Categoria IS NULL OR Categoria = @Categoria)
    ORDER BY Categoria, Codigo;
END;


-- ============================================================================
-- cfg.GetByClaveConfiguracionReglasNegocio
-- ============================================================================
CREATE  PROCEDURE [cfg].[GetByClaveConfiguracionReglasNegocio]
    @Codigo VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdRegla,
        Codigo,
        Nombre,
        Valor,
        TipoDato,
        Categoria,
        Descripcion,
        VigenciaDesde,
        VigenciaHasta,
        FechaCreacion,
        FechaActualizacion
    FROM [cfg].[ConfiguracionReglasNegocio]
    WHERE Codigo = @Codigo;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se encontró el parámetro con código ''%s''.', 16, 1, @Codigo);
    END;
END;


-- ============================================================================
-- cfg.InsertConfiguracionReglasNegocio
-- ============================================================================
CREATE  PROCEDURE [cfg].[InsertConfiguracionReglasNegocio]
    @Codigo        VARCHAR(50),
    @Nombre        NVARCHAR(150),
    @Valor         NVARCHAR(500),
    @TipoDato      VARCHAR(20)   = 'INT',
    @Categoria     VARCHAR(30)   = 'GENERAL',
    @Descripcion   NVARCHAR(500) = NULL,
    @VigenciaDesde DATE          = NULL,
    @VigenciaHasta DATE          = NULL,
    @IdRegla       INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe un parámetro con el código ''%s''. Use UpdateConfiguracionReglasNegocio para modificarlo.', 16, 1, @Codigo);
        END;

        IF @TipoDato NOT IN ('INT','DECIMAL','BOOL','TEXT','JSON')
        BEGIN
            RAISERROR('El tipo de dato ''%s'' no es válido. Use: INT, DECIMAL, BOOL, TEXT o JSON.', 16, 1, @TipoDato);
        END;

        IF @Categoria NOT IN ('ENFRIAMIENTO','GENERAL','OTP','BIOMETRIA','RIESGO','FOTOS','AUTH')
        BEGIN
            RAISERROR('La categoría ''%s'' no es válida.', 16, 1, @Categoria);
        END;

        SET @VigenciaDesde = ISNULL(@VigenciaDesde, CAST(GETDATE() AS DATE));

        INSERT INTO [cfg].[ConfiguracionReglasNegocio] (
            Codigo, Nombre, Valor, TipoDato, Categoria,
            Descripcion, VigenciaDesde, VigenciaHasta
        )
        VALUES (
            @Codigo, @Nombre, @Valor, @TipoDato, @Categoria,
            @Descripcion, @VigenciaDesde, @VigenciaHasta
        );

        SET @IdRegla = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdRegla AS IdRegla;
END;


-- ============================================================================
-- cfg.UpdateConfiguracionReglasNegocio
-- ============================================================================
CREATE  PROCEDURE [cfg].[UpdateConfiguracionReglasNegocio]
    @Codigo        VARCHAR(50),
    @Nombre        NVARCHAR(150),
    @Valor         NVARCHAR(500),
    @TipoDato      VARCHAR(20),
    @Categoria     VARCHAR(30),
    @Descripcion   NVARCHAR(500) = NULL,
    @VigenciaDesde DATE          = NULL,
    @VigenciaHasta DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('No se encontró el parámetro con código ''%s''.', 16, 1, @Codigo);
        END;

        IF @TipoDato NOT IN ('INT','DECIMAL','BOOL','TEXT','JSON')
        BEGIN
            RAISERROR('El tipo de dato ''%s'' no es válido. Use: INT, DECIMAL, BOOL, TEXT o JSON.', 16, 1, @TipoDato);
        END;

        IF @Categoria NOT IN ('ENFRIAMIENTO','GENERAL','OTP','BIOMETRIA','RIESGO','FOTOS','AUTH')
        BEGIN
            RAISERROR('La categoría ''%s'' no es válida.', 16, 1, @Categoria);
        END;

        UPDATE [cfg].[ConfiguracionReglasNegocio]
        SET
            Nombre             = @Nombre,
            Valor              = @Valor,
            TipoDato           = @TipoDato,
            Categoria          = @Categoria,
            Descripcion        = @Descripcion,
            VigenciaDesde      = ISNULL(@VigenciaDesde, VigenciaDesde),
            VigenciaHasta      = @VigenciaHasta,
            FechaActualizacion = GETDATE()
        WHERE Codigo = @Codigo;

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
