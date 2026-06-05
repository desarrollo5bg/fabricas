/*
  Stored Procedures — fab.CampanasValidacionIdentidad / fab.IntentosValidacionBot
  Fecha:  2026-05-26
  Autor:  Edwin Trigos

  Procedimientos para el ciclo de vida completo de campañas de validación de
  identidad (BOT Ubica). El Bot de Voz o un asesor (Plan B) interactúan con
  estas tablas a través de estos SPs exclusivamente.

  Procedimientos:
    fab.InsertCampanaValidacion        — inicia una campaña, genera CodigoCampana
    fab.InsertIntentoValidacion        — registra una llamada individual con biometría
    fab.UpdateDiagnosticoFinalCampana  — cierra la campaña con diagnóstico definitivo
    fab.GetCampanaActivaPorEstudio     — consulta si un estudio tiene campaña EN_PROCESO
*/

-- ============================================================================
-- fab.InsertCampanaValidacion
-- Registra el inicio de una campaña de validación de identidad.
-- Genera el CodigoCampana con el patrón CAMP-{yyyyMMdd}-{IdCampana}.
-- Previene duplicados: lanza error si el estudio ya tiene campaña EN_PROCESO.
-- Retorna: IdCampana (int), CodigoCampana (varchar)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertCampanaValidacion]
    @IdEstudio          INT,
    @Canal              VARCHAR(10),    -- BOT | MANUAL
    @MotivoManual       VARCHAR(20),    -- FALLA_BOT | DECISION_ASESOR | NULL si Canal=BOT
    @NitAsesor          VARCHAR(20),
    @CentralConsultada  VARCHAR(20) = NULL  -- CIFIN | DATACREDITO | NULL (v2026-06-05)
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

        -- Prevenir campaña duplicada EN_PROCESO
        IF EXISTS (
            SELECT 1 FROM [fab].[CampanasValidacionIdentidad]
            WHERE IdEstudio = @IdEstudio AND EstadoCampana = 'EN_PROCESO'
        )
        BEGIN
            RAISERROR('El estudio %d ya tiene una campaña de validación EN_PROCESO.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Validar Canal
        IF @Canal NOT IN ('BOT', 'MANUAL')
        BEGIN
            RAISERROR('Canal inválido: %s. Valores permitidos: BOT, MANUAL.', 16, 1, @Canal);
            RETURN;
        END;

        -- Validar MotivoManual coherente con Canal
        IF @Canal = 'MANUAL' AND @MotivoManual NOT IN ('FALLA_BOT', 'DECISION_ASESOR')
        BEGIN
            RAISERROR('Para Canal=MANUAL se requiere MotivoManual: FALLA_BOT o DECISION_ASESOR.', 16, 1);
            RETURN;
        END;

        IF @Canal = 'BOT' AND @MotivoManual IS NOT NULL
        BEGIN
            RAISERROR('Para Canal=BOT el campo MotivoManual debe ser NULL.', 16, 1);
            RETURN;
        END;

        -- Validar CentralConsultada
        IF @Canal = 'BOT' AND @CentralConsultada IS NOT NULL
           AND @CentralConsultada NOT IN ('CIFIN', 'DATACREDITO')
        BEGIN
            RAISERROR('CentralConsultada inválida: %s. Use: CIFIN, DATACREDITO o NULL.', 16, 1, @CentralConsultada);
            RETURN;
        END;

        -- INSERT inicial — CodigoCampana se genera en el UPDATE siguiente
        INSERT INTO [fab].[CampanasValidacionIdentidad] (
            CodigoCampana,
            IdEstudio,
            Canal,
            MotivoManual,
            EstadoCampana,
            NitAsesor,
            CentralConsultada
        )
        VALUES (
            'CAMP-PENDIENTE',   -- placeholder — se actualiza abajo con el Id generado
            @IdEstudio,
            @Canal,
            @MotivoManual,
            'EN_PROCESO',
            @NitAsesor,
            @CentralConsultada
        );

        DECLARE @IdCampana INT = SCOPE_IDENTITY();

        -- Generar y actualizar CodigoCampana con el Id real
        DECLARE @CodigoCampana VARCHAR(30) =
            'CAMP-' + CONVERT(VARCHAR(8), GETDATE(), 112) + '-' + CAST(@IdCampana AS VARCHAR(10));

        UPDATE [fab].[CampanasValidacionIdentidad]
        SET CodigoCampana = @CodigoCampana
        WHERE IdCampana = @IdCampana;

        COMMIT TRANSACTION;

        -- Retornar identificadores generados
        SELECT @IdCampana AS IdCampana, @CodigoCampana AS CodigoCampana;

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
-- fab.InsertIntentoValidacion
-- Registra una llamada individual dentro de una campaña (Round-Robin).
-- Incluye timestamps, diagnóstico del intento y variables biométricas del Bot.
-- La restricción UQ_IntVal_Intento (IdCampana, OrdenLinea, NumeroIntento)
-- garantiza idempotencia — no se puede registrar el mismo intento dos veces.
-- Retorna: IdIntento (int)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertIntentoValidacion]
    @IdCampana              INT,
    @OrdenLinea             TINYINT,
    @NumeroMarcado          VARCHAR(15),
    @NumeroIntento          TINYINT,
    @IdDiagnosticoIntento   INT         = NULL,
    @FechaInicio            DATETIME2(3),
    @FechaFin               DATETIME2(3) = NULL,
    @DuracionSegundos       INT          = NULL,
    @UrlAudio               VARCHAR(500) = NULL,
    -- Variables biométricas (opcionales — solo las devuelve el Bot)
    @GeneroVozDetectado     VARCHAR(10)  = NULL,
    @EdadEstimadaVoz        TINYINT      = NULL,
    @AcentoDetectado        VARCHAR(30)  = NULL,
    @CoincidenciaNombre     BIT          = NULL,
    @CoincidenciaCedula     BIT          = NULL,
    @DescripcionDiscrepancia NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que la campaña existe y está EN_PROCESO
        IF NOT EXISTS (
            SELECT 1 FROM [fab].[CampanasValidacionIdentidad]
            WHERE IdCampana = @IdCampana AND EstadoCampana = 'EN_PROCESO'
        )
        BEGIN
            RAISERROR('La campaña %d no existe o no está EN_PROCESO.', 16, 1, @IdCampana);
            RETURN;
        END;

        -- Validar diagnóstico si fue informado
        IF @IdDiagnosticoIntento IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [cat].[CatalogoDiagnosticosBot] WHERE IdDiagnostico = @IdDiagnosticoIntento AND Activo = 1)
        BEGIN
            RAISERROR('IdDiagnosticoIntento = %d no existe o está inactivo.', 16, 1, @IdDiagnosticoIntento);
            RETURN;
        END;

        INSERT INTO [fab].[IntentosValidacionBot] (
            IdCampana,
            OrdenLinea,
            NumeroMarcado,
            NumeroIntento,
            IdDiagnosticoIntento,
            FechaInicio,
            FechaFin,
            DuracionSegundos,
            UrlAudio,
            GeneroVozDetectado,
            EdadEstimadaVoz,
            AcentoDetectado,
            CoincidenciaNombre,
            CoincidenciaCedula,
            DescripcionDiscrepancia
        )
        VALUES (
            @IdCampana,
            @OrdenLinea,
            @NumeroMarcado,
            @NumeroIntento,
            @IdDiagnosticoIntento,
            @FechaInicio,
            @FechaFin,
            @DuracionSegundos,
            @UrlAudio,
            @GeneroVozDetectado,
            @EdadEstimadaVoz,
            @AcentoDetectado,
            @CoincidenciaNombre,
            @CoincidenciaCedula,
            @DescripcionDiscrepancia
        );

        DECLARE @IdIntento INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @IdIntento AS IdIntento;

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
-- fab.UpdateDiagnosticoFinalCampana
-- Cierra una campaña con el diagnóstico definitivo.
-- Actualiza: IdDiagnosticoFinal, EstadoCampana, FechaFinMarcacion, totales
-- y el PaqueteInconsistencia (JSON para Fábrica de Soporte).
-- Solo UPDATE — no Upsert.
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[UpdateDiagnosticoFinalCampana]
    @IdCampana              INT,
    @IdDiagnosticoFinal     INT,
    @EstadoCampana          VARCHAR(15),        -- COMPLETADA | FALLIDA
    @FechaFinMarcacion      DATETIME2(3),
    @TotalLineasUsadas      TINYINT,
    @TotalIntentos          TINYINT,
    @FechaInicioMarcacion   DATETIME2(3) = NULL,
    @PaqueteInconsistencia  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que la campaña existe y está EN_PROCESO
        IF NOT EXISTS (
            SELECT 1 FROM [fab].[CampanasValidacionIdentidad]
            WHERE IdCampana = @IdCampana AND EstadoCampana = 'EN_PROCESO'
        )
        BEGIN
            RAISERROR('La campaña %d no existe o no está EN_PROCESO — no se puede cerrar.', 16, 1, @IdCampana);
            RETURN;
        END;

        -- Validar diagnóstico final
        IF NOT EXISTS (
            SELECT 1 FROM [cat].[CatalogoDiagnosticosBot]
            WHERE IdDiagnostico = @IdDiagnosticoFinal AND Activo = 1
        )
        BEGIN
            RAISERROR('IdDiagnosticoFinal = %d no existe o está inactivo.', 16, 1, @IdDiagnosticoFinal);
            RETURN;
        END;

        -- Validar EstadoCampana destino
        IF @EstadoCampana NOT IN ('COMPLETADA', 'FALLIDA')
        BEGIN
            RAISERROR('EstadoCampana inválido: %s. Valores permitidos: COMPLETADA, FALLIDA.', 16, 1, @EstadoCampana);
            RETURN;
        END;

        UPDATE [fab].[CampanasValidacionIdentidad]
        SET
            IdDiagnosticoFinal    = @IdDiagnosticoFinal,
            EstadoCampana         = @EstadoCampana,
            FechaFinMarcacion     = @FechaFinMarcacion,
            TotalLineasUsadas     = @TotalLineasUsadas,
            TotalIntentos         = @TotalIntentos,
            FechaInicioMarcacion  = ISNULL(@FechaInicioMarcacion, FechaInicioMarcacion),
            PaqueteInconsistencia = @PaqueteInconsistencia
        WHERE IdCampana = @IdCampana;

        COMMIT TRANSACTION;

        -- Retornar campaña cerrada para confirmación al orquestador
        SELECT
            c.IdCampana,
            c.CodigoCampana,
            c.EstadoCampana,
            c.IdDiagnosticoFinal,
            d.Codigo            AS DiagnosticoCodigo,
            d.AccionSistema,
            d.NivelAlerta,
            d.GeneraAlertaFraude,
            c.TotalIntentos,
            c.TotalLineasUsadas,
            c.FechaInicioMarcacion,
            c.FechaFinMarcacion
        FROM [fab].[CampanasValidacionIdentidad] c
        JOIN [cat].[CatalogoDiagnosticosBot]     d ON d.IdDiagnostico = c.IdDiagnosticoFinal
        WHERE c.IdCampana = @IdCampana;

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
-- fab.GetCampanaActivaPorEstudio
-- Consulta si un estudio ya tiene una campaña EN_PROCESO.
-- Retorna la campaña con su diagnóstico final (si existe) para polling.
-- Retorna 0 filas si no hay campaña activa — no es un error.
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[GetCampanaActivaPorEstudio]
    @IdEstudio INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IdCampana,
        c.CodigoCampana,
        c.IdEstudio,
        c.Canal,
        c.MotivoManual,
        c.EstadoCampana,
        c.IdDiagnosticoFinal,
        d.Codigo            AS DiagnosticoCodigo,
        d.AccionSistema,
        d.NivelAlerta,
        d.GeneraAlertaFraude,
        c.TotalLineasUsadas,
        c.TotalIntentos,
        c.FechaInicioMarcacion,
        c.FechaFinMarcacion,
        c.FechaCreacion,
        c.NitAsesor,
        c.CentralConsultada
    FROM [fab].[CampanasValidacionIdentidad] c
    LEFT JOIN [cat].[CatalogoDiagnosticosBot] d ON d.IdDiagnostico = c.IdDiagnosticoFinal
    WHERE c.IdEstudio    = @IdEstudio
      AND c.EstadoCampana = 'EN_PROCESO';

END;
