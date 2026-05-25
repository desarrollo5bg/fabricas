/*
  Stored Procedures — fab.TransicionEstado
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para gestión de transiciones de estado de estudios.
  - TransicionarEstado: C-03 Cambiar estado del estudio validando transiciones permitidas
  - CalcularSiguientePaso: C-04 Calcular el siguiente paso lógico en el flujo

  Procedimientos:
    fab.TransicionarEstado
    fab.CalcularSiguientePaso
*/

-- ============================================================================
-- fab.TransicionarEstado (C-03)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[TransicionarEstado]
    @IdEstudio              BIGINT,
    @CodigoEstadoDestino    VARCHAR(40),
    @IdOperador             INT,
    @IdMotivo               INT = NULL,
    @Observaciones          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Obtener estado actual del estudio
        DECLARE @CodigoEstadoOrigen VARCHAR(40);
        DECLARE @IdEstadoActual INT;
        DECLARE @IdEstadoDestino INT;
        
        SELECT TOP 1 @IdEstadoActual = IdEstadoActual
        FROM [fab].[EstudiosCredito]
        WHERE IdEstudio = @IdEstudio;

        IF @IdEstadoActual IS NULL
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Obtener código estado actual y destino
        SELECT @CodigoEstadoOrigen = Codigo
        FROM [cfg].[CatalogoEstados]
        WHERE IdEstado = @IdEstadoActual;

        SELECT @IdEstadoDestino = IdEstado
        FROM [cfg].[CatalogoEstados]
        WHERE Codigo = @CodigoEstadoDestino;

        IF @IdEstadoDestino IS NULL
        BEGIN
            RAISERROR('El estado destino con código ''%s'' no existe.', 16, 1, @CodigoEstadoDestino);
            RETURN;
        END;

        -- Validar transición permitida
        DECLARE @TransicionValida BIT;
        DECLARE @RequiereMotivo BIT;
        
        SELECT
            @TransicionValida = CASE WHEN IdTransicion IS NOT NULL THEN 1 ELSE 0 END,
            @RequiereMotivo = RequiereMotivo
        FROM [cfg].[TransicionesEstado]
        WHERE IdEstadoOrigen = @IdEstadoActual
          AND IdEstadoDestino = @IdEstadoDestino
          AND Activa = 1;

        IF @TransicionValida = 0
        BEGIN
            RAISERROR('Transición no permitida de %s a %s.', 16, 1, @CodigoEstadoOrigen, @CodigoEstadoDestino);
            RETURN;
        END;

        -- Validar que se envíe motivo si es requerido
        IF @RequiereMotivo = 1 AND @IdMotivo IS NULL
        BEGIN
            RAISERROR('La transición a %s requiere un motivo (IdMotivo no puede ser NULL).', 16, 1, @CodigoEstadoDestino);
            RETURN;
        END;

        -- UPDATE fab.EstudiosCredito
        UPDATE [fab].[EstudiosCredito]
        SET
            IdEstadoActual     = @IdEstadoDestino,
            FechaActualizacion = GETDATE()
        WHERE IdEstudio = @IdEstudio;

        -- INSERT en aud.HistorialEstados
        INSERT INTO [aud].[HistorialEstados] (
            IdEstudio,
            IdEstadoAnterior,
            IdEstadoNuevo,
            IdUsuarioAccion,
            TipoUsuario,
            MotivoTransicion,
            FechaTransicion
        )
        VALUES (
            @IdEstudio,
            @IdEstadoActual,
            @IdEstadoDestino,
            @IdOperador,
            'ASESOR',
            COALESCE(@Observaciones, 'Transición de estado'),
            GETDATE()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT
        @IdEstudio AS IdEstudio,
        @CodigoEstadoOrigen AS CodigoEstadoAnterior,
        @CodigoEstadoDestino AS CodigoEstadoNuevo;

END;


-- ============================================================================
-- fab.CalcularSiguientePaso (C-04)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[CalcularSiguientePaso]
    @IdPasoActual INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrdenGlobalActual INT;
    DECLARE @IdPasoSiguiente INT;

    -- Obtener OrdenGlobal del paso actual
    SELECT @OrdenGlobalActual = OrdenGlobal
    FROM [cfg].[PasosEstudio]
    WHERE IdPaso = @IdPasoActual;

    IF @OrdenGlobalActual IS NULL
    BEGIN
        -- Paso no existe, retornar NULL en IdPasoSiguiente
        SELECT
            NULL AS IdPasoSiguiente,
            NULL AS Codigo,
            NULL AS Nombre,
            NULL AS OrdenGlobal,
            NULL AS Actor,
            NULL AS EsAutomatico,
            CAST(0 AS BIT) AS EsUltimoPaso;
        RETURN;
    END;

    -- Obtener siguiente paso activo
    SELECT TOP 1
        @IdPasoSiguiente = IdPaso
    FROM [cfg].[PasosEstudio]
    WHERE Activo = 1
      AND OrdenGlobal > @OrdenGlobalActual
    ORDER BY OrdenGlobal ASC;

    -- Retornar resultado
    IF @IdPasoSiguiente IS NULL
    BEGIN
        -- No hay próximo paso
        SELECT
            NULL AS IdPasoSiguiente,
            NULL AS Codigo,
            NULL AS Nombre,
            NULL AS OrdenGlobal,
            NULL AS Actor,
            NULL AS EsAutomatico,
            CAST(1 AS BIT) AS EsUltimoPaso;
    END
    ELSE
    BEGIN
        -- Retornar datos del siguiente paso
        SELECT
            IdPaso AS IdPasoSiguiente,
            Codigo,
            Nombre,
            OrdenGlobal,
            Actor,
            EsAutomatico,
            CAST(0 AS BIT) AS EsUltimoPaso
        FROM [cfg].[PasosEstudio]
        WHERE IdPaso = @IdPasoSiguiente;
    END;

END;
