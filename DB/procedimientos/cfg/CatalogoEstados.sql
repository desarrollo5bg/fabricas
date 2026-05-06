/*
  Stored Procedures — cfg.CatalogoEstados
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetAllCatalogoEstados
    cfg.GetByCodigoCatalogoEstados
    cfg.InsertCatalogoEstados
    cfg.UpdateCatalogoEstados
    cfg.DeactivateCatalogoEstados
*/

-- ============================================================================
-- cfg.GetAllCatalogoEstados
--   Devuelve todos los estados. Con @SoloActivos = 1 filtra estados inactivos.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetAllCatalogoEstados]
    @SoloActivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.IdEstado,
        e.Codigo,
        e.Nombre,
        e.Grupo,
        e.EsTerminal,
        e.PermitePausa,
        e.Descripcion,
        e.Activo
    FROM [cfg].[CatalogoEstados] e
    WHERE (@SoloActivos = 0 OR e.Activo = 1)
    ORDER BY e.Grupo, e.Nombre;
END;


-- ============================================================================
-- cfg.GetByCodigoCatalogoEstados
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetByCodigoCatalogoEstados]
    @Codigo VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.IdEstado,
        e.Codigo,
        e.Nombre,
        e.Grupo,
        e.EsTerminal,
        e.PermitePausa,
        e.Descripcion,
        e.Activo
    FROM [cfg].[CatalogoEstados] e
    WHERE e.Codigo = @Codigo;
END;


-- ============================================================================
-- cfg.InsertCatalogoEstados
--   Inserta un nuevo estado. Codigo es inmutable (no se puede cambiar después).
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[InsertCatalogoEstados]
    @Codigo       VARCHAR(40),
    @Nombre       NVARCHAR(100),
    @Grupo        VARCHAR(20),
    @EsTerminal   BIT           = 0,
    @PermitePausa BIT           = 0,
    @Descripcion  NVARCHAR(500) = NULL,
    @IdEstado     INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Grupo NOT IN ('INICIAL','PROCESO','TERMINAL','BLOQUEO','REACTIVACION')
        BEGIN
            RAISERROR('El grupo ''%s'' no es válido. Valores permitidos: INICIAL, PROCESO, TERMINAL, BLOQUEO, REACTIVACION.', 16, 1, @Grupo);
        END;

        IF EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe un estado con el código ''%s''.', 16, 1, @Codigo);
        END;

        INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion)
        VALUES (@Codigo, @Nombre, @Grupo, @EsTerminal, @PermitePausa, @Descripcion);

        SET @IdEstado = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdEstado AS IdEstado;
END;


-- ============================================================================
-- cfg.UpdateCatalogoEstados
--   Actualiza un estado existente. Codigo es INMUTABLE: no se permite cambiarlo.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[UpdateCatalogoEstados]
    @IdEstado     INT,
    @Nombre       NVARCHAR(100),
    @Grupo        VARCHAR(20),
    @EsTerminal   BIT,
    @PermitePausa BIT,
    @Descripcion  NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Grupo NOT IN ('INICIAL','PROCESO','TERMINAL','BLOQUEO','REACTIVACION')
        BEGIN
            RAISERROR('El grupo ''%s'' no es válido. Valores permitidos: INICIAL, PROCESO, TERMINAL, BLOQUEO, REACTIVACION.', 16, 1, @Grupo);
        END;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE IdEstado = @IdEstado)
        BEGIN
            RAISERROR('No se encontró un estado con IdEstado = %d.', 16, 1, @IdEstado);
        END;

        UPDATE [cfg].[CatalogoEstados]
        SET
            Nombre       = @Nombre,
            Grupo        = @Grupo,
            EsTerminal   = @EsTerminal,
            PermitePausa = @PermitePausa,
            Descripcion  = @Descripcion
        WHERE IdEstado = @IdEstado;

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
-- cfg.DeactivateCatalogoEstados
--   Marca el estado como inactivo (Activo = 0).
--   No elimina el registro: los estados son referenciados por EstudiosCredito
--   e historial — el borrado físico rompería integridad referencial.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[DeactivateCatalogoEstados]
    @IdEstado INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE IdEstado = @IdEstado)
        BEGIN
            RAISERROR('No se encontró un estado con IdEstado = %d.', 16, 1, @IdEstado);
        END;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE IdEstado = @IdEstado AND Activo = 1)
        BEGIN
            -- Severity 10 = informativo, no lanza excepción al cliente
            RAISERROR('El estado con IdEstado = %d ya se encuentra inactivo.', 10, 1, @IdEstado);
        END;

        UPDATE [cfg].[CatalogoEstados]
        SET Activo = 0
        WHERE IdEstado = @IdEstado;

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
