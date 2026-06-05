/*
  Stored Procedures — fab.EvaluacionesRiesgo
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para registrar evaluaciones de riesgo y viabilidad.
  - InsertEvaluacionRiesgo: C-08 Insertar registro de evaluación genérica
  - RegistrarEvaluacionViabilidad: C-23 Registrar evaluación de viabilidad (UBICA)
  - RegistrarEvaluacionContactabilidad: C-24 Registrar evaluación de contactabilidad
  - InsertEvaluacionCombinada: C-26 Registrar evaluación con centrales primarias y secundarias

  Procedimientos:
    fab.InsertEvaluacionRiesgo
    fab.RegistrarEvaluacionViabilidad
    fab.RegistrarEvaluacionContactabilidad
    fab.InsertEvaluacionCombinada
*/

-- ============================================================================
-- fab.InsertEvaluacionRiesgo (C-08)
-- ============================================================================
CREATE  PROCEDURE [fab].[InsertEvaluacionRiesgo]
    @IdEstudio                      BIGINT,
    @IdPaso                         INT = NULL,
    @TipoEvaluacion                 VARCHAR(30),
    @CoincidenciaListasRestrictivas BIT = NULL,
    @ScoreBuro                      INT = NULL,
    @MoraComerciosAliados           BIT = NULL,
    @ViablePreselecta               BIT = NULL,
    @EsPensionado                   BIT = NULL,
    @TieneSeguridadSocial           BIT = NULL,
    @Resultado                      VARCHAR(20),
    @MotivoResultado                NVARCHAR(200) = NULL,
    @DetallesJSON                   NVARCHAR(MAX) = NULL,
    @IdEvaluacion                   BIGINT OUTPUT
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

        -- Validar TipoEvaluacion
        IF @TipoEvaluacion NOT IN ('LISTAS','BURO','PRESELECTA','FOSYGA','ANTECEDENTES','UBICA')
        BEGIN
            RAISERROR('El tipo de evaluación ''%s'' no es válido.', 16, 1, @TipoEvaluacion);
            RETURN;
        END;

        -- Validar Resultado
        IF @Resultado NOT IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR')
        BEGIN
            RAISERROR('El resultado ''%s'' no es válido.', 16, 1, @Resultado);
            RETURN;
        END;

        -- INSERT en fab.EvaluacionesRiesgo
        INSERT INTO [fab].[EvaluacionesRiesgo] (
            IdEstudio,
            IdPaso,
            TipoEvaluacion,
            CoincidenciaListasRestrictivas,
            ScoreBuro,
            MoraComerciosAliados,
            ViablePreselecta,
            EsPensionado,
            TieneSeguridadSocial,
            Resultado,
            MotivoResultado,
            DetallesJSON,
            FechaEvaluacion
        )
        VALUES (
            @IdEstudio,
            @IdPaso,
            @TipoEvaluacion,
            COALESCE(@CoincidenciaListasRestrictivas, 0),
            @ScoreBuro,
            @MoraComerciosAliados,
            @ViablePreselecta,
            @EsPensionado,
            @TieneSeguridadSocial,
            @Resultado,
            @MotivoResultado,
            @DetallesJSON,
            GETDATE()
        );

        SET @IdEvaluacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEvaluacion AS IdEvaluacion;

END;


-- ============================================================================
-- fab.RegistrarEvaluacionViabilidad (C-23)
-- ============================================================================
CREATE  PROCEDURE [fab].[RegistrarEvaluacionViabilidad]
    @IdEstudio              BIGINT,
    @NitTercero             VARCHAR(20),
    @CentralConsultada      VARCHAR(20),
    @Resultado              VARCHAR(20),
    @ScoreObtenido          DECIMAL(10,4) = NULL,
    @IdLogCentralExterno    VARCHAR(100) = NULL,
    @RespuestaRaw           NVARCHAR(MAX) = NULL,
    @IdEvaluacion           BIGINT OUTPUT
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

        -- INSERT en fab.EvaluacionesRiesgo con TipoEvaluacion = 'UBICA'
        INSERT INTO [fab].[EvaluacionesRiesgo] (
            IdEstudio,
            IdPaso,
            TipoEvaluacion,
            Resultado,
            MotivoResultado,
            DetallesJSON,
            FechaEvaluacion
        )
        VALUES (
            @IdEstudio,
            NULL,
            'UBICA',
            @Resultado,
            @CentralConsultada,
            (SELECT @CentralConsultada AS CentralConsultada, @ScoreObtenido AS ScoreObtenido, @IdLogCentralExterno AS IdLogCentralExterno FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            GETDATE()
        );

        SET @IdEvaluacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEvaluacion AS IdEvaluacion;

END;


-- ============================================================================
-- fab.RegistrarEvaluacionContactabilidad (C-24)
-- ============================================================================
CREATE  PROCEDURE [fab].[RegistrarEvaluacionContactabilidad]
    @IdEstudio              BIGINT,
    @NitTercero             VARCHAR(20),
    @CentralConsultada      VARCHAR(20),
    @Resultado              VARCHAR(20),
    @ScoreObtenido          DECIMAL(10,4) = NULL,
    @IdLogCentralExterno    VARCHAR(100) = NULL,
    @RespuestaRaw           NVARCHAR(MAX) = NULL,
    @TelefonoValidado       VARCHAR(20) = NULL,
    @CorreoValidado         VARCHAR(200) = NULL,
    @IdEvaluacion           BIGINT OUTPUT,
    @IdValidacion           BIGINT OUTPUT
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

        -- INSERT en fab.EvaluacionesRiesgo con TipoEvaluacion = 'CONTACTABILIDAD'
        INSERT INTO [fab].[EvaluacionesRiesgo] (
            IdEstudio,
            IdPaso,
            TipoEvaluacion,
            Resultado,
            MotivoResultado,
            DetallesJSON,
            FechaEvaluacion
        )
        VALUES (
            @IdEstudio,
            NULL,
            'CONTACTABILIDAD',
            @Resultado,
            @CentralConsultada,
            (SELECT @CentralConsultada AS CentralConsultada, @ScoreObtenido AS ScoreObtenido,
                    @TelefonoValidado AS TelefonoValidado, @CorreoValidado AS CorreoValidado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            GETDATE()
        );

        SET @IdEvaluacion = SCOPE_IDENTITY();

        -- INSERT en fab.ValidacionesContactabilidad si la tabla está disponible
        IF OBJECT_ID(N'fab.ValidacionesContactabilidad', N'U') IS NOT NULL
        BEGIN
            INSERT INTO [fab].[ValidacionesContactabilidad] (
                IdEstudio,
                ScoreUbica,
                EstadoUbica,
                FechaVerificacion
            )
            VALUES (
                @IdEstudio,
                @CentralConsultada,
                CASE WHEN @Resultado = 'APROBADO' THEN 'OK_CEL_CORREO' ELSE 'GESTION_MANUAL_FABRICA' END,
                GETDATE()
            );

            SET @IdValidacion = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SET @IdValidacion = NULL;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEvaluacion AS IdEvaluacion, @IdValidacion AS IdValidacion;

END;


-- ============================================================================
-- fab.InsertEvaluacionCombinada (C-26)
-- ============================================================================
CREATE  PROCEDURE [fab].[InsertEvaluacionCombinada]
    @IdEstudio                          BIGINT,
    @NitTercero                         VARCHAR(20),
    @Resultado                          VARCHAR(20),
    @ScoreObtenidoPrimaria              DECIMAL(10,4) = NULL,
    @ScoreObtenidoSecundaria            DECIMAL(10,4) = NULL,
    @IdLogCentralExterno                VARCHAR(100) = NULL,
    @IdLogCentralExternoSecundaria      VARCHAR(100) = NULL,
    @RespuestaRawPrimaria               NVARCHAR(MAX) = NULL,
    @RespuestaRawSecundaria             NVARCHAR(MAX) = NULL,
    @IdEvaluacion                       BIGINT OUTPUT
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

        -- Validar Resultado
        IF @Resultado NOT IN ('APROBADO','RECHAZADO','PENDIENTE','ERROR')
        BEGIN
            RAISERROR('El resultado ''%s'' no es válido.', 16, 1, @Resultado);
            RETURN;
        END;

        -- INSERT en fab.EvaluacionesRiesgo con TipoEvaluacion = 'COMBINADA'
        INSERT INTO [fab].[EvaluacionesRiesgo] (
            IdEstudio,
            IdPaso,
            TipoEvaluacion,
            Resultado,
            DetallesJSON,
            FechaEvaluacion
        )
        VALUES (
            @IdEstudio,
            NULL,
            'COMBINADA',
            @Resultado,
            (SELECT @IdLogCentralExterno AS CentralPrimaria, @IdLogCentralExternoSecundaria AS CentralSecundaria,
                    @ScoreObtenidoPrimaria AS ScorePrimaria, @ScoreObtenidoSecundaria AS ScoreSecundaria FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            GETDATE()
        );

        SET @IdEvaluacion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEvaluacion AS IdEvaluacion;

END;
