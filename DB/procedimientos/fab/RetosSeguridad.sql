/*
  Stored Procedures — fab.RetosSeguridad
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Cada reto OTP es inmutable una vez validado (Exitoso = 1).
  Para reenvío se actualiza el mismo reto (nuevo hash + canal),
  no se crea un registro nuevo. El API debe hashear el código
  ANTES de llamar a InsertReto o MarcarRetoReenviado.

  Tabla: fab.RetosSeguridad
  Log:   aud.LogValidacionesOTP (escrito desde fab.ValidarReto)

  Procedimientos:
    fab.InsertReto
    fab.ValidarReto
    fab.GetEstadoReto
    fab.MarcarRetoReenviado
*/

-- ============================================================================
-- fab.InsertReto
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertReto]
    @IdEstudio        BIGINT,
    @NitTercero       VARCHAR(20),
    @CanalEnvio       VARCHAR(20),
    @HashToken        VARCHAR(256),
    @FechaExpiracion  DATETIME2(3),
    @DireccionEnvio   NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio)
    BEGIN
        RAISERROR('EstudioCredito no encontrado: %d', 16, 1, @IdEstudio);
        RETURN;
    END;

    IF @CanalEnvio NOT IN ('WHATSAPP', 'EMAIL', 'SMS')
    BEGIN
        RAISERROR('CanalEnvio invalido. Valores permitidos: WHATSAPP, EMAIL, SMS.', 16, 1);
        RETURN;
    END;

    INSERT INTO [fab].[RetosSeguridad]
    (
        IdEstudio,
        NitTercero,
        CanalEnvio,
        HashToken,
        FechaEnvio,
        FechaExpiracion,
        NumeroIntentos,
        Exitoso,
        NumeroReenvios,
        DireccionEnvio
    )
    VALUES
    (
        @IdEstudio,
        @NitTercero,
        @CanalEnvio,
        @HashToken,
        GETDATE(),
        @FechaExpiracion,
        0,
        0,
        0,
        @DireccionEnvio
    );

    SELECT SCOPE_IDENTITY() AS [IdReto];
END;


-- ============================================================================
-- fab.ValidarReto
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[ValidarReto]
    @IdReto               BIGINT,
    @HashTokenIngresado   VARCHAR(256),
    @DireccionIP          VARCHAR(45)    = NULL,
    @UserAgent            NVARCHAR(500)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @HashAlmacenado  VARCHAR(256),
        @FechaExpiracion DATETIME2(3),
        @Exitoso         BIT,
        @NumeroIntentos  INT,
        @IdEstudio       BIGINT,
        @NitTercero      VARCHAR(20),
        @Resultado       VARCHAR(20);

    SELECT
        @HashAlmacenado  = HashToken,
        @FechaExpiracion = FechaExpiracion,
        @Exitoso         = Exitoso,
        @NumeroIntentos  = NumeroIntentos,
        @IdEstudio       = IdEstudio,
        @NitTercero      = NitTercero
    FROM [fab].[RetosSeguridad]
    WHERE IdReto = @IdReto;

    IF @HashAlmacenado IS NULL
    BEGIN
        RAISERROR('Reto no encontrado: %I64d', 16, 1, @IdReto);
        RETURN;
    END;

    -- Reto ya validado exitosamente
    IF @Exitoso = 1
    BEGIN
        SELECT
            @IdReto          AS IdReto,
            'YA_VALIDADO'    AS ResultadoValidacion,
            1                AS Exitoso,
            @NumeroIntentos  AS NumeroIntentos;
        RETURN;
    END;

    -- Verificar expiración
    IF GETDATE() > @FechaExpiracion
    BEGIN
        SET @Resultado = 'EXPIRADO';

        INSERT INTO [aud].[LogValidacionesOTP]
        (IdReto, IdEstudio, NitTercero, NumeroIntento, ResultadoIntento,
         CodigoEntradoHash, DireccionIP, UserAgent, FechaIntento)
        VALUES
        (@IdReto, @IdEstudio, @NitTercero, @NumeroIntentos + 1, @Resultado,
         @HashTokenIngresado, @DireccionIP, @UserAgent, GETDATE());

        SELECT
            @IdReto    AS IdReto,
            @Resultado AS ResultadoValidacion,
            0          AS Exitoso,
            @NumeroIntentos + 1 AS NumeroIntentos;
        RETURN;
    END;

    -- Incrementar intentos
    SET @NumeroIntentos = @NumeroIntentos + 1;

    UPDATE [fab].[RetosSeguridad]
    SET NumeroIntentos = @NumeroIntentos
    WHERE IdReto = @IdReto;

    -- Comparar hash
    IF @HashTokenIngresado = @HashAlmacenado
    BEGIN
        SET @Resultado = 'EXITOSO';

        UPDATE [fab].[RetosSeguridad]
        SET
            Exitoso         = 1,
            FechaValidacion = GETDATE()
        WHERE IdReto = @IdReto;
    END
    ELSE
    BEGIN
        SET @Resultado = 'FALLIDO_HASH';
    END;

    INSERT INTO [aud].[LogValidacionesOTP]
    (IdReto, IdEstudio, NitTercero, NumeroIntento, ResultadoIntento,
     CodigoEntradoHash, DireccionIP, UserAgent, FechaIntento)
    VALUES
    (@IdReto, @IdEstudio, @NitTercero, @NumeroIntentos, @Resultado,
     @HashTokenIngresado, @DireccionIP, @UserAgent, GETDATE());

    SELECT
        @IdReto                AS IdReto,
        @Resultado             AS ResultadoValidacion,
        CASE WHEN @Resultado = 'EXITOSO' THEN 1 ELSE 0 END AS Exitoso,
        @NumeroIntentos        AS NumeroIntentos;
END;


-- ============================================================================
-- fab.GetEstadoReto
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[GetEstadoReto]
    @IdReto BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdReto,
        IdEstudio,
        NitTercero,
        CanalEnvio,
        FechaEnvio,
        FechaExpiracion,
        FechaValidacion,
        NumeroIntentos,
        Exitoso,
        NumeroReenvios,
        UltimoReenvio,
        DireccionEnvio,
        CASE WHEN GETDATE() > FechaExpiracion AND Exitoso = 0 THEN 1 ELSE 0 END AS EstaExpirado
    FROM [fab].[RetosSeguridad]
    WHERE IdReto = @IdReto;
END;


-- ============================================================================
-- fab.MarcarRetoReenviado
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[MarcarRetoReenviado]
    @IdReto              BIGINT,
    @NuevoCanalEnvio     VARCHAR(20),
    @HashTokenNuevo      VARCHAR(256),
    @NuevaFechaExpiracion DATETIME2(3),
    @DireccionEnvioNueva  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [fab].[RetosSeguridad] WHERE IdReto = @IdReto)
    BEGIN
        RAISERROR('Reto no encontrado: %I64d', 16, 1, @IdReto);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM [fab].[RetosSeguridad] WHERE IdReto = @IdReto AND Exitoso = 1)
    BEGIN
        RAISERROR('No se puede reenviar un reto ya validado exitosamente.', 16, 1);
        RETURN;
    END;

    IF @NuevoCanalEnvio NOT IN ('WHATSAPP', 'EMAIL', 'SMS')
    BEGIN
        RAISERROR('NuevoCanalEnvio invalido. Valores permitidos: WHATSAPP, EMAIL, SMS.', 16, 1);
        RETURN;
    END;

    UPDATE [fab].[RetosSeguridad]
    SET
        CanalEnvio       = @NuevoCanalEnvio,
        HashToken        = @HashTokenNuevo,
        FechaExpiracion  = @NuevaFechaExpiracion,
        NumeroReenvios   = NumeroReenvios + 1,
        UltimoReenvio    = GETDATE(),
        DireccionEnvio   = @DireccionEnvioNueva,
        NumeroIntentos   = 0
    WHERE IdReto = @IdReto;

    SELECT
        @IdReto AS IdReto,
        NumeroReenvios
    FROM [fab].[RetosSeguridad]
    WHERE IdReto = @IdReto;
END;
