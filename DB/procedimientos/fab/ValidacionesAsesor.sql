/*
  Stored Procedures — fab.ValidacionesAsesor
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para validaciones de asesor.
  - InsertValidacionAsesor: C-22 Registrar validación biométrica o de seguridad del asesor

  Procedimientos:
    fab.InsertValidacionAsesor
*/

-- ============================================================================
-- fab.InsertValidacionAsesor (C-22)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertValidacionAsesor]
    @IdAsesor                   INT = NULL,
    @NitAsesor                  VARCHAR(20) = NULL,
    @CodigoAsesor               VARCHAR(20),
    @IdBodega                   INT,
    @FechaValidacion            DATETIME2(3) = NULL,
    @PruebaVidaExitosa          BIT = 0,
    @PorcentajeCoincidencia     DECIMAL(5,2) = NULL,
    @IdDispositivo              VARCHAR(100) = NULL,
    @DireccionIP                VARCHAR(45) = NULL,
    @TipoValidacion             VARCHAR(30),
    @ResultadoValidacion        VARCHAR(20),
    @MensajeError               NVARCHAR(500) = NULL,
    @IdValidacion               BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que IdAsesor existe en fab.OperadoresFabrica
        IF @IdAsesor IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdAsesor)
            BEGIN
                RAISERROR('El asesor con IdAsesor = %d no existe en fab.OperadoresFabrica.', 16, 1, @IdAsesor);
                RETURN;
            END;
        END;

        -- Validar que IdBodega existe en dbo.bodegas
        IF NOT EXISTS (SELECT 1 FROM [dbo].[bodegas] WHERE id = @IdBodega)
        BEGIN
            RAISERROR('La bodega con IdBodega = %d no existe en dbo.bodegas.', 16, 1, @IdBodega);
            RETURN;
        END;

        -- Validar ResultadoValidacion
        IF @ResultadoValidacion NOT IN ('EXITOSA','FALLIDA','ERROR_SERVICIO')
        BEGIN
            RAISERROR('El resultado de validación ''%s'' no es válido.', 16, 1, @ResultadoValidacion);
            RETURN;
        END;

        -- INSERT en fab.ValidacionesAsesor
        INSERT INTO [fab].[ValidacionesAsesor] (
            IdAsesor,
            CodigoAsesor,
            IdBodega,
            FechaValidacion,
            PruebaVidaExitosa,
            PorcentajeCoincidencia,
            IdDispositivo,
            DireccionIP,
            ResultadoValidacion,
            MensajeError,
            FechaCreacion
        )
        VALUES (
            @IdAsesor,
            @CodigoAsesor,
            @IdBodega,
            COALESCE(@FechaValidacion, GETDATE()),
            @PruebaVidaExitosa,
            @PorcentajeCoincidencia,
            @IdDispositivo,
            @DireccionIP,
            @ResultadoValidacion,
            @MensajeError,
            GETDATE()
        );

        SET @IdValidacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdValidacion AS IdValidacion;

END;
