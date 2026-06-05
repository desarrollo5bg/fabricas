/*
  Stored Procedures — fab.DisponibilidadOperadores
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    fab.GetByOperadorDisponibilidadOperadores
    fab.GetConectadosDisponibilidadOperadores
    fab.ConectarDisponibilidadOperadores
    fab.DesconectarDisponibilidadOperadores
    fab.CambiarEstadoDisponibilidadOperadores
*/

-- ============================================================================
-- fab.GetByOperadorDisponibilidadOperadores
-- ============================================================================
CREATE  PROCEDURE [fab].[GetByOperadorDisponibilidadOperadores]
    @IdOperador INT,
    @LimiteDias INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.IdDisponibilidad,
        d.IdOperador,
        d.NitOperador,
        d.EstadoDisponibilidad,
        d.FechaConexion,
        d.FechaDesconexion,
        d.DireccionIP,
        d.Observaciones,
        DATEDIFF(MINUTE, d.FechaConexion, ISNULL(d.FechaDesconexion, GETDATE())) AS MinutosConectado
    FROM [fab].[DisponibilidadOperadores] d
    WHERE d.IdOperador = @IdOperador
      AND d.FechaConexion >= DATEADD(DAY, -@LimiteDias, GETDATE())
    ORDER BY d.FechaConexion DESC;
END;


-- ============================================================================
-- fab.GetConectadosDisponibilidadOperadores
-- ============================================================================
CREATE  PROCEDURE [fab].[GetConectadosDisponibilidadOperadores]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.IdDisponibilidad,
        d.IdOperador,
        d.NitOperador,
        o.NombreOperador,
        o.TipoOperador,
        d.EstadoDisponibilidad,
        d.FechaConexion,
        d.DireccionIP,
        DATEDIFF(MINUTE, d.FechaConexion, GETDATE()) AS MinutosConectado
    FROM [fab].[DisponibilidadOperadores] d
    INNER JOIN [fab].[OperadoresFabrica] o ON o.IdOperador = d.IdOperador
    WHERE d.EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA')
    ORDER BY o.TipoOperador, o.NombreOperador;
END;


-- ============================================================================
-- fab.ConectarDisponibilidadOperadores
--   Registra nueva sesión. Si el operador ya tiene sesión activa, la cierra
--   automáticamente antes de crear la nueva.
-- ============================================================================
CREATE  PROCEDURE [fab].[ConectarDisponibilidadOperadores]
    @IdOperador       INT,
    @NitOperador      VARCHAR(20),
    @DireccionIP      VARCHAR(45) = NULL,
    @IdDisponibilidad BIGINT      OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM [fab].[OperadoresFabrica]
            WHERE IdOperador = @IdOperador AND NitOperador = @NitOperador AND Activo = 1
        )
        BEGIN
            RAISERROR('El operador con IdOperador = %d / NIT = ''%s'' no existe o está inactivo.', 16, 1, @IdOperador, @NitOperador);
        END;

        -- Cerrar sesión activa anterior si existe
        UPDATE [fab].[DisponibilidadOperadores]
        SET
            EstadoDisponibilidad = 'DESCONECTADO',
            FechaDesconexion     = GETDATE(),
            Observaciones        = 'Sesión cerrada automáticamente al iniciar nueva conexión'
        WHERE IdOperador = @IdOperador
          AND EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA');

        INSERT INTO [fab].[DisponibilidadOperadores] (
            IdOperador, NitOperador, EstadoDisponibilidad, DireccionIP
        )
        VALUES (
            @IdOperador, @NitOperador, 'CONECTADO', @DireccionIP
        );

        SET @IdDisponibilidad = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdDisponibilidad AS IdDisponibilidad;
END;


-- ============================================================================
-- fab.DesconectarDisponibilidadOperadores
-- ============================================================================
CREATE  PROCEDURE [fab].[DesconectarDisponibilidadOperadores]
    @IdOperador    INT,
    @Observaciones NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdOperador)
        BEGIN
            RAISERROR('No se encontró el operador con IdOperador = %d.', 16, 1, @IdOperador);
        END;

        UPDATE [fab].[DisponibilidadOperadores]
        SET
            EstadoDisponibilidad = 'DESCONECTADO',
            FechaDesconexion     = GETDATE(),
            Observaciones        = @Observaciones
        WHERE IdOperador = @IdOperador
          AND EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA');

        IF @@ROWCOUNT = 0
        BEGIN
            -- Severity 10 = informativo, no lanza excepción al cliente
            RAISERROR('El operador %d no tenía una sesión activa.', 10, 1, @IdOperador);
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        IF @Severity > 10
            RAISERROR(@Msg, @Severity, @State);
    END CATCH;
END;


-- ============================================================================
-- fab.CambiarEstadoDisponibilidadOperadores
--   Cambia el estado de la sesión activa (CONECTADO ↔ EN_PAUSA / NO_DISPONIBLE).
--   Para desconectar usar DesconectarDisponibilidadOperadores.
-- ============================================================================
CREATE  PROCEDURE [fab].[CambiarEstadoDisponibilidadOperadores]
    @IdOperador           INT,
    @EstadoDisponibilidad VARCHAR(20),
    @Observaciones        NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @EstadoDisponibilidad NOT IN ('CONECTADO','EN_PAUSA','NO_DISPONIBLE')
        BEGIN
            RAISERROR('El estado ''%s'' no es válido. Para desconectar use DesconectarDisponibilidadOperadores.', 16, 1, @EstadoDisponibilidad);
        END;

        IF NOT EXISTS (
            SELECT 1 FROM [fab].[DisponibilidadOperadores]
            WHERE IdOperador = @IdOperador
              AND EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA','NO_DISPONIBLE')
        )
        BEGIN
            RAISERROR('El operador %d no tiene una sesión activa. Use ConectarDisponibilidadOperadores primero.', 16, 1, @IdOperador);
        END;

        UPDATE [fab].[DisponibilidadOperadores]
        SET
            EstadoDisponibilidad = @EstadoDisponibilidad,
            Observaciones        = @Observaciones
        WHERE IdOperador = @IdOperador
          AND EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA','NO_DISPONIBLE');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;
END;
