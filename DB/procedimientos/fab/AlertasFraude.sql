/*
  Stored Procedures — fab.AlertasFraude
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para evaluación de fraude.
  - EvaluarFraude: C-11 Evaluar reglas de fraude y generar alertas

  Procedimientos:
    fab.EvaluarFraude
*/

-- ============================================================================
-- fab.EvaluarFraude (C-11)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[EvaluarFraude]
    @IdEstudio              BIGINT,
    @IdOperadorEvaluador    INT = NULL
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

        DECLARE @NitTercero VARCHAR(20);
        SELECT @NitTercero = NitTercero FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio;

        -- Variables para contar alertas
        DECLARE @TotalReglasEvaluadas INT = 0;
        DECLARE @AlertasGeneradas INT = 0;
        DECLARE @RequiereEscalamiento BIT = 0;

        -- Iterar sobre reglas activas y evaluar
        DECLARE @IdRegla INT, @NivelRiesgo VARCHAR(10), @AccionAutomatica VARCHAR(30);
        
        DECLARE ReglasCursor CURSOR FOR
        SELECT IdReglaFraude, NivelRiesgo, AccionAutomatica
        FROM [cat].[CatalogoReglasFraude]
        WHERE Activa = 1;

        OPEN ReglasCursor;
        FETCH NEXT FROM ReglasCursor INTO @IdRegla, @NivelRiesgo, @AccionAutomatica;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @TotalReglasEvaluadas = @TotalReglasEvaluadas + 1;

            -- Si la regla tiene acción automática, registrar alerta
            IF @AccionAutomatica IN ('ESCALAR','BLOQUEAR','NOTIFICAR','SOLO_REGISTRO')
            BEGIN
                SET @AlertasGeneradas = @AlertasGeneradas + 1;

                -- Determinar si requiere escalamiento
                IF @AccionAutomatica IN ('ESCALAR','BLOQUEAR')
                BEGIN
                    SET @RequiereEscalamiento = 1;
                END;

                -- INSERT en aud.AlertasFraude
                INSERT INTO [aud].[AlertasFraude] (
                    IdEstudio,
                    IdReglaFraude,
                    NitTercero,
                    PasoEnQueOcurrio,
                    AccionTomada,
                    IdAsesor,
                    FechaAlerta
                )
                SELECT
                    @IdEstudio,
                    @IdRegla,
                    @NitTercero,
                    NULL,
                    CASE
                        WHEN @AccionAutomatica = 'ESCALAR' THEN 'ESCALADO'
                        WHEN @AccionAutomatica = 'BLOQUEAR' THEN 'BLOQUEADO'
                        WHEN @AccionAutomatica = 'NOTIFICAR' THEN 'PENDIENTE'
                        ELSE 'PENDIENTE'
                    END,
                    @IdOperadorEvaluador,
                    GETDATE();
            END;

            FETCH NEXT FROM ReglasCursor INTO @IdRegla, @NivelRiesgo, @AccionAutomatica;
        END;

        CLOSE ReglasCursor;
        DEALLOCATE ReglasCursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF CURSOR_STATUS('global', 'ReglasCursor') >= -1
        BEGIN
            CLOSE ReglasCursor;
            DEALLOCATE ReglasCursor;
        END;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    -- Retornar resumen de evaluación
    SELECT
        @TotalReglasEvaluadas AS TotalReglasEvaluadas,
        @AlertasGeneradas AS AlertasGeneradas,
        @RequiereEscalamiento AS RequiereEscalamiento;

END;
