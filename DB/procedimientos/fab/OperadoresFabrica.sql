/*
  Stored Procedures — fab.OperadoresFabrica
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  NOTA: NitOperador es INMUTABLE. Si el NIT cambia, desactivar el registro
  antiguo y crear uno nuevo con InsertOperadoresFabrica.

  Procedimientos:
    fab.GetAllOperadoresFabrica
    fab.GetByNitOperadoresFabrica
    fab.GetByIdOperadoresFabrica
    fab.GetByTipoOperadoresFabrica
    fab.InsertOperadoresFabrica
    fab.UpdateOperadoresFabrica
    fab.DeactivateOperadoresFabrica
    fab.ActivateOperadoresFabrica
*/

-- ============================================================================
-- fab.GetAllOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[GetAllOperadoresFabrica]
    @SoloActivos  BIT         = 1,
    @TipoOperador VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdOperador,
        NitOperador,
        NombreOperador,
        CorreoOperador,
        TelefonoOperador,
        TipoOperador,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [fab].[OperadoresFabrica]
    WHERE (@SoloActivos = 0 OR Activo = 1)
      AND (@TipoOperador IS NULL OR TipoOperador = @TipoOperador)
    ORDER BY TipoOperador, NombreOperador;
END;


-- ============================================================================
-- fab.GetByNitOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[GetByNitOperadoresFabrica]
    @NitOperador VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdOperador,
        NitOperador,
        NombreOperador,
        CorreoOperador,
        TelefonoOperador,
        TipoOperador,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [fab].[OperadoresFabrica]
    WHERE NitOperador = @NitOperador;
END;


-- ============================================================================
-- fab.GetByIdOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[GetByIdOperadoresFabrica]
    @IdOperador INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdOperador,
        NitOperador,
        NombreOperador,
        CorreoOperador,
        TelefonoOperador,
        TipoOperador,
        Activo,
        FechaCreacion,
        FechaActualizacion
    FROM [fab].[OperadoresFabrica]
    WHERE IdOperador = @IdOperador;
END;


-- ============================================================================
-- fab.GetByTipoOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[GetByTipoOperadoresFabrica]
    @TipoOperador VARCHAR(20),
    @SoloActivos  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @TipoOperador NOT IN ('ASESOR','SUPERVISOR','GERENTE','REVISOR_FOTOS','CALL_CENTER','ADMINISTRADOR')
    BEGIN
        RAISERROR('El tipo de operador ''%s'' no es válido.', 16, 1, @TipoOperador);
        RETURN;
    END;

    SELECT
        IdOperador,
        NitOperador,
        NombreOperador,
        CorreoOperador,
        TelefonoOperador,
        TipoOperador,
        Activo
    FROM [fab].[OperadoresFabrica]
    WHERE TipoOperador = @TipoOperador
      AND (@SoloActivos = 0 OR Activo = 1)
    ORDER BY NombreOperador;
END;


-- ============================================================================
-- fab.InsertOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[InsertOperadoresFabrica]
    @NitOperador      VARCHAR(20),
    @NombreOperador   NVARCHAR(200),
    @CorreoOperador   NVARCHAR(100) = NULL,
    @TelefonoOperador VARCHAR(20)   = NULL,
    @TipoOperador     VARCHAR(20)   = 'ASESOR',
    @IdOperador       INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE NitOperador = @NitOperador)
        BEGIN
            RAISERROR('Ya existe un operador con el NIT ''%s''. Si fue dado de baja, use ActivateOperadoresFabrica.', 16, 1, @NitOperador);
        END;

        IF @TipoOperador NOT IN ('ASESOR','SUPERVISOR','GERENTE','REVISOR_FOTOS','CALL_CENTER','ADMINISTRADOR')
        BEGIN
            RAISERROR('El tipo de operador ''%s'' no es válido.', 16, 1, @TipoOperador);
        END;

        INSERT INTO [fab].[OperadoresFabrica] (
            NitOperador, NombreOperador, CorreoOperador, TelefonoOperador, TipoOperador
        )
        VALUES (
            @NitOperador, @NombreOperador, @CorreoOperador, @TelefonoOperador, @TipoOperador
        );

        SET @IdOperador = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdOperador AS IdOperador;
END;


-- ============================================================================
-- fab.UpdateOperadoresFabrica
--   NitOperador es INMUTABLE — no se puede cambiar.
-- ============================================================================
CREATE  PROCEDURE [fab].[UpdateOperadoresFabrica]
    @IdOperador       INT,
    @NombreOperador   NVARCHAR(200),
    @CorreoOperador   NVARCHAR(100) = NULL,
    @TelefonoOperador VARCHAR(20)   = NULL,
    @TipoOperador     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdOperador)
        BEGIN
            RAISERROR('No se encontró el operador con IdOperador = %d.', 16, 1, @IdOperador);
        END;

        IF @TipoOperador NOT IN ('ASESOR','SUPERVISOR','GERENTE','REVISOR_FOTOS','CALL_CENTER','ADMINISTRADOR')
        BEGIN
            RAISERROR('El tipo de operador ''%s'' no es válido.', 16, 1, @TipoOperador);
        END;

        UPDATE [fab].[OperadoresFabrica]
        SET
            NombreOperador     = @NombreOperador,
            CorreoOperador     = @CorreoOperador,
            TelefonoOperador   = @TelefonoOperador,
            TipoOperador       = @TipoOperador,
            FechaActualizacion = GETDATE()
        WHERE IdOperador = @IdOperador;

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


-- ============================================================================
-- fab.DeactivateOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[DeactivateOperadoresFabrica]
    @IdOperador INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdOperador)
        BEGIN
            RAISERROR('No se encontró el operador con IdOperador = %d.', 16, 1, @IdOperador);
        END;

        IF EXISTS (
            SELECT 1 FROM [fab].[EstudiosCredito]
            WHERE IdAsesor = @IdOperador
              AND EliminadoLogico = 0
              AND FechaFinalizacion IS NULL
        )
        BEGIN
            RAISERROR('No se puede desactivar el operador %d: tiene estudios en progreso asignados.', 16, 1, @IdOperador);
        END;

        -- Cerrar disponibilidad activa si existe
        UPDATE [fab].[DisponibilidadOperadores]
        SET
            EstadoDisponibilidad = 'DESCONECTADO',
            FechaDesconexion     = GETDATE()
        WHERE IdOperador = @IdOperador
          AND EstadoDisponibilidad IN ('CONECTADO','EN_PAUSA');

        UPDATE [fab].[OperadoresFabrica]
        SET
            Activo             = 0,
            FechaActualizacion = GETDATE()
        WHERE IdOperador = @IdOperador;

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


-- ============================================================================
-- fab.ActivateOperadoresFabrica
-- ============================================================================
CREATE  PROCEDURE [fab].[ActivateOperadoresFabrica]
    @IdOperador INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdOperador)
        BEGIN
            RAISERROR('No se encontró el operador con IdOperador = %d.', 16, 1, @IdOperador);
        END;

        IF EXISTS (SELECT 1 FROM [fab].[OperadoresFabrica] WHERE IdOperador = @IdOperador AND Activo = 1)
        BEGIN
            RAISERROR('El operador %d ya está activo.', 16, 1, @IdOperador);
        END;

        UPDATE [fab].[OperadoresFabrica]
        SET
            Activo             = 1,
            FechaActualizacion = GETDATE()
        WHERE IdOperador = @IdOperador;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_State();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;
END;
