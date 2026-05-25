/*
  Stored Procedures — fab.EscalamientosFabrica
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para gestionar escalamientos.
  - InsertEscalamiento: C-12 Crear escalamiento de caso

  Procedimientos:
    fab.InsertEscalamiento
*/

-- ============================================================================
-- fab.InsertEscalamiento (C-12)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertEscalamiento]
    @IdEstudio              BIGINT,
    @IdMotivo               INT,
    @IdOperadorCreador      INT,
    @IdOperadorAsignado     INT = NULL,
    @Descripcion            NVARCHAR(500) = NULL,
    @IdEscalamiento         BIGINT OUTPUT
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

        -- Validar que IdMotivo existe en cat.CatalogoMotivosEscalamiento
        IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE IdMotivo = @IdMotivo AND Activo = 1)
        BEGIN
            RAISERROR('El motivo de escalamiento con IdMotivo = %d no existe o no está activo.', 16, 1, @IdMotivo);
            RETURN;
        END;

        -- Obtener estado actual del estudio
        DECLARE @IdEstadoActual INT;
        SELECT @IdEstadoActual = IdEstadoActual
        FROM [fab].[EstudiosCredito]
        WHERE IdEstudio = @IdEstudio;

        -- INSERT en fab.EscalamientosFabrica
        INSERT INTO [fab].[EscalamientosFabrica] (
            IdEstudio,
            IdMotivoEscalamiento,
            IdAlertaOrigen,
            DescripcionContexto,
            PasoEnQueEscalo,
            IdEstadoAlEscalar,
            SnapshotDatosCliente,
            EscaladoPorSistema,
            IdAsesor,
            IdAsesorAsignado,
            FechaAsignacion,
            EstadoEscalamiento,
            NotasAsesor,
            FechaCreacion,
            FechaActualizacion
        )
        VALUES (
            @IdEstudio,
            @IdMotivo,
            NULL,
            @Descripcion,
            NULL,
            @IdEstadoActual,
            NULL,
            0,  -- Escalamiento manual por operador
            @IdOperadorCreador,
            @IdOperadorAsignado,
            CASE WHEN @IdOperadorAsignado IS NOT NULL THEN GETDATE() ELSE NULL END,
            'ABIERTO',
            NULL,
            GETDATE(),
            GETDATE()
        );

        SET @IdEscalamiento = SCOPE_IDENTITY();

        -- UPDATE fab.EstudiosCredito para marcar escalamiento activo
        UPDATE [fab].[EstudiosCredito]
        SET
            IdEscalamientoActivo   = @IdEscalamiento,
            FechaActualizacion     = GETDATE()
        WHERE IdEstudio = @IdEstudio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEscalamiento AS IdEscalamiento;

END;
