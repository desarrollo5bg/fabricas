/*
  Stored Procedures — aud.RegistroServiciosExternos
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para auditoría de invocaciones a servicios externos.
  - InsertRegistroServicioExterno: C-16 Registrar llamada a servicio externo

  Procedimientos:
    aud.InsertRegistroServicioExterno
*/

-- ============================================================================
-- aud.InsertRegistroServicioExterno (C-16)
-- ============================================================================
CREATE OR ALTER PROCEDURE [aud].[InsertRegistroServicioExterno]
    @IdEstudio              BIGINT = NULL,
    @IdPaso                 INT = NULL,
    @NombreServicio         VARCHAR(50),
    @Endpoint               NVARCHAR(500) = NULL,
    @MetodoHttp             VARCHAR(10) = NULL,
    @PayloadEnviado         NVARCHAR(MAX) = NULL,
    @RespuestaRecibida      NVARCHAR(MAX) = NULL,
    @CodigoRespuestaHttp    INT = NULL,
    @DuracionMs             INT = NULL,
    @Exitoso                BIT = 1,
    @MensajeError           NVARCHAR(500) = NULL,
    @IdRegistro             BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que IdEstudio existe si se proporciona
        IF @IdEstudio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio)
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Validar que IdPaso existe si se proporciona
        IF @IdPaso IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE IdPaso = @IdPaso)
        BEGIN
            RAISERROR('El paso con IdPaso = %d no existe.', 16, 1, @IdPaso);
            RETURN;
        END;

        -- Determinar ResultadoInterpretado basado en CodigoRespuestaHttp y Exitoso
        DECLARE @ResultadoInterpretado VARCHAR(20);
        SET @ResultadoInterpretado = CASE
            WHEN @Exitoso = 1 THEN 'EXITOSO'
            WHEN @CodigoRespuestaHttp = 408 OR @CodigoRespuestaHttp = 504 THEN 'TIMEOUT'
            WHEN @CodigoRespuestaHttp >= 500 THEN 'ERROR'
            ELSE 'FALLIDO'
        END;

        -- INSERT en aud.RegistroServiciosExternos
        INSERT INTO [aud].[RegistroServiciosExternos] (
            IdEstudio,
            IdPaso,
            NombreServicio,
            URLEndpoint,
            MetodoHTTP,
            PayloadRequest,
            PayloadResponse,
            CodigoHTTPRespuesta,
            ResultadoInterpretado,
            MensajeError,
            DuracionMs,
            FechaInvocacion,
            FechaRespuesta
        )
        VALUES (
            @IdEstudio,
            @IdPaso,
            @NombreServicio,
            @Endpoint,
            @MetodoHttp,
            @PayloadEnviado,
            @RespuestaRecibida,
            @CodigoRespuestaHttp,
            @ResultadoInterpretado,
            @MensajeError,
            @DuracionMs,
            GETDATE(),
            CASE WHEN @Exitoso = 1 OR @CodigoRespuestaHttp IS NOT NULL THEN GETDATE() ELSE NULL END
        );

        SET @IdRegistro = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdRegistro AS IdRegistro;

END;
