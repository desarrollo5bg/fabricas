/*
  Stored Procedures — cat.CatalogoDiagnosticosBot
  Fecha:  2026-05-27
  Autor:  Edwin Trigos

  Procedimientos:
    cat.GetAllCatalogoDiagnosticosBot
    cat.GetByCodigoCatalogoDiagnosticosBot
    cat.UpdateCatalogoDiagnosticoBot
    cat.ToggleActivoCatalogoDiagnosticoBot
*/

-- ============================================================================
-- cat.GetAllCatalogoDiagnosticosBot
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[GetAllCatalogoDiagnosticosBot]
    @SoloActivos  BIT          = 1,
    @NivelAlerta  VARCHAR(10)  = NULL,
    @AccionSistema VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdDiagnostico,
        Codigo,
        Descripcion,
        AccionSistema,
        NivelAlerta,
        GeneraAlertaFraude,
        EsTerminal,
        Activo,
        Observaciones
    FROM [cat].[CatalogoDiagnosticosBot]
    WHERE (@SoloActivos  = 0 OR Activo        = 1)
      AND (@NivelAlerta  IS NULL OR NivelAlerta  = @NivelAlerta)
      AND (@AccionSistema IS NULL OR AccionSistema = @AccionSistema)
    ORDER BY NivelAlerta, Codigo;
END;


-- ============================================================================
-- cat.GetByCodigoCatalogoDiagnosticosBot
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[GetByCodigoCatalogoDiagnosticosBot]
    @Codigo VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdDiagnostico,
        Codigo,
        Descripcion,
        AccionSistema,
        NivelAlerta,
        GeneraAlertaFraude,
        EsTerminal,
        Activo,
        Observaciones
    FROM [cat].[CatalogoDiagnosticosBot]
    WHERE Codigo = @Codigo;
END;


-- ============================================================================
-- cat.UpdateCatalogoDiagnosticoBot
-- Solo actualiza los campos mutables. Codigo e IdDiagnostico son inmutables.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[UpdateCatalogoDiagnosticoBot]
    @Codigo            VARCHAR(40),
    @Descripcion       NVARCHAR(200),
    @AccionSistema     VARCHAR(20),
    @NivelAlerta       VARCHAR(10),
    @GeneraAlertaFraude BIT,
    @EsTerminal        BIT,
    @Observaciones     NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoDiagnosticosBot] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('No se encontró el diagnóstico con código ''%s''.', 16, 1, @Codigo);
        END;

        IF @AccionSistema NOT IN ('CONTINUAR','BLOQUEAR','ESCALAR','PLAN_B','DESCARTAR_LINEA')
        BEGIN
            RAISERROR('AccionSistema ''%s'' no es válida. Valores: CONTINUAR, BLOQUEAR, ESCALAR, PLAN_B, DESCARTAR_LINEA.', 16, 1, @AccionSistema);
        END;

        IF @NivelAlerta NOT IN ('VERDE','AMARILLO','ROJO','GRIS','ERROR')
        BEGIN
            RAISERROR('NivelAlerta ''%s'' no es válido. Valores: VERDE, AMARILLO, ROJO, GRIS, ERROR.', 16, 1, @NivelAlerta);
        END;

        UPDATE [cat].[CatalogoDiagnosticosBot]
        SET
            Descripcion        = @Descripcion,
            AccionSistema      = @AccionSistema,
            NivelAlerta        = @NivelAlerta,
            GeneraAlertaFraude = @GeneraAlertaFraude,
            EsTerminal         = @EsTerminal,
            Observaciones      = @Observaciones
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


-- ============================================================================
-- cat.ToggleActivoCatalogoDiagnosticoBot
-- Activa o desactiva un diagnóstico. No elimina — soft toggle.
-- Protección: no se puede desactivar un diagnóstico con campañas EN_PROCESO.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cat].[ToggleActivoCatalogoDiagnosticoBot]
    @Codigo  VARCHAR(40),
    @Activo  BIT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoDiagnosticosBot] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('No se encontró el diagnóstico con código ''%s''.', 16, 1, @Codigo);
        END;

        -- Protección al desactivar: verificar que no haya campañas activas usando este diagnóstico
        IF @Activo = 0
        BEGIN
            DECLARE @IdDiagnostico INT;
            SELECT @IdDiagnostico = IdDiagnostico FROM [cat].[CatalogoDiagnosticosBot] WHERE Codigo = @Codigo;

            IF EXISTS (
                SELECT 1 FROM [fab].[CampanasValidacionIdentidad]
                WHERE IdDiagnosticoFinal = @IdDiagnostico
                  AND EstadoCampana = 'EN_PROCESO'
            )
            BEGIN
                RAISERROR('No se puede desactivar el diagnóstico ''%s'': tiene campañas EN_PROCESO asociadas.', 16, 1, @Codigo);
            END;
        END;

        UPDATE [cat].[CatalogoDiagnosticosBot]
        SET Activo = @Activo
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
