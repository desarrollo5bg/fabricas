/*
  Stored Procedures — aud.LogValidacionesOTP
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Tabla de solo escritura (append-only). Los registros NO se modifican.
  La inserción principal la hace fab.ValidarReto directamente.
  Este SP existe para casos donde el API necesita registrar un intento
  manualmente (por ejemplo: expiración detectada en capa de aplicación).

  Procedimientos:
    aud.InsertLogValidacionOTP
*/

-- ============================================================================
-- aud.InsertLogValidacionOTP
-- ============================================================================
CREATE  PROCEDURE [aud].[InsertLogValidacionOTP]
    @IdReto             BIGINT,
    @IdEstudio          BIGINT,
    @NitTercero         VARCHAR(20),
    @NumeroIntento      INT,
    @ResultadoIntento   VARCHAR(20),
    @DireccionEnvio     NVARCHAR(200) = NULL,
    @CodigoEntradoHash  VARCHAR(256)  = NULL,
    @DireccionIP        VARCHAR(45)   = NULL,
    @UserAgent          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ResultadoIntento NOT IN ('EXITOSO', 'FALLIDO_HASH', 'EXPIRADO', 'CANCELADO')
    BEGIN
        RAISERROR('ResultadoIntento invalido. Valores: EXITOSO, FALLIDO_HASH, EXPIRADO, CANCELADO.', 16, 1);
        RETURN;
    END;

    INSERT INTO [aud].[LogValidacionesOTP]
    (
        IdReto,
        IdEstudio,
        NitTercero,
        NumeroIntento,
        DireccionEnvio,
        ResultadoIntento,
        CodigoEntradoHash,
        DireccionIP,
        UserAgent,
        FechaIntento
    )
    VALUES
    (
        @IdReto,
        @IdEstudio,
        @NitTercero,
        @NumeroIntento,
        @DireccionEnvio,
        @ResultadoIntento,
        @CodigoEntradoHash,
        @DireccionIP,
        @UserAgent,
        GETDATE()
    );

    SELECT SCOPE_IDENTITY() AS [IdLogOTP];
END;
