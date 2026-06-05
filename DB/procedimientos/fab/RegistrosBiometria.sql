/*
  Stored Procedures — fab.RegistrosBiometria
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para registrar datos biométricos.
  - InsertRegistroBiometria: C-09 Registrar resultado de verificación biométrica

  Procedimientos:
    fab.InsertRegistroBiometria
*/

-- ============================================================================
-- fab.InsertRegistroBiometria (C-09)
-- ============================================================================
CREATE  PROCEDURE [fab].[InsertRegistroBiometria]
    @IdEstudio                  BIGINT,
    @IdTransaccionProveedor     VARCHAR(100) = NULL,
    @TipoVerificacion           VARCHAR(20),
    @PruebaVidaAprobada         BIT = 0,
    @PorcentajeCoincidencia     DECIMAL(5,2) = NULL,
    @EstadoOCR                  VARCHAR(20) = NULL,
    @NumeroIntentos             INT = 1,
    @EstadoProceso              VARCHAR(20),
    @NombreExtraidoOCR          NVARCHAR(200) = NULL,
    @FechaExpedicionExtraidaOCR DATE = NULL,
    @NumeroDocumentoExtraidoOCR VARCHAR(20) = NULL,
    @CoincidenciaOCR            BIT = NULL,
    @IdFotografiaFrontal        BIGINT = NULL,
    @IdFotografiaReverso        BIGINT = NULL,
    @IdFotografiaSelfie         BIGINT = NULL,
    @IdBiometria                BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que IdEstudio existe
        IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio)
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Validar TipoVerificacion
        IF @TipoVerificacion NOT IN ('ONBOARDING','AUTENTICACION','PRUEBA_VIDA_HANDOFF')
        BEGIN
            RAISERROR('El tipo de verificación ''%s'' no es válido.', 16, 1, @TipoVerificacion);
            RETURN;
        END;

        -- Validar EstadoProceso
        IF @EstadoProceso NOT IN ('EXITOSO','FALLIDO','REVISION_MANUAL')
        BEGIN
            RAISERROR('El estado de proceso ''%s'' no es válido.', 16, 1, @EstadoProceso);
            RETURN;
        END;

        -- INSERT en fab.RegistrosBiometria
        INSERT INTO [fab].[RegistrosBiometria] (
            IdEstudio,
            IdTransaccionProveedor,
            TipoVerificacion,
            PruebaVidaAprobada,
            PorcentajeCoincidencia,
            EstadoOCR,
            NumeroIntentos,
            EstadoProceso,
            NombreExtraidoOCR,
            FechaExpedicionExtraidaOCR,
            NumeroDocumentoExtraidoOCR,
            CoincidenciaOCR,
            FechaRegistro,
            IdFotografiaFrontal,
            IdFotografiaReverso,
            IdFotografiaSelfie
        )
        VALUES (
            @IdEstudio,
            @IdTransaccionProveedor,
            @TipoVerificacion,
            @PruebaVidaAprobada,
            @PorcentajeCoincidencia,
            @EstadoOCR,
            @NumeroIntentos,
            @EstadoProceso,
            @NombreExtraidoOCR,
            @FechaExpedicionExtraidaOCR,
            @NumeroDocumentoExtraidoOCR,
            @CoincidenciaOCR,
            GETDATE(),
            @IdFotografiaFrontal,
            @IdFotografiaReverso,
            @IdFotografiaSelfie
        );

        SET @IdBiometria = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdBiometria AS IdRegistroBiometria;

END;
