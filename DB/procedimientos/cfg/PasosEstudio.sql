/*
  Stored Procedures — cfg.PasosEstudio
  Fecha:  2026-05-05
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetByFasePasosEstudio
    cfg.GetByIdPasosEstudio
    cfg.InsertPasosEstudio
    cfg.UpdatePasosEstudio
    cfg.DeactivatePasosEstudio
*/

-- ============================================================================
-- cfg.GetByFasePasosEstudio
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetByFasePasosEstudio]
    @IdFase      INT,
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdPaso,
        IdFase,
        Codigo,
        Nombre,
        OrdenEnFase,
        OrdenGlobal,
        Actor,
        ServicioExterno,
        EsAutomatico,
        RequiereIntervencion,
        TiempoTimeoutSeg,
        Descripcion,
        Activo
    FROM [cfg].[PasosEstudio]
    WHERE IdFase = @IdFase
      AND (@SoloActivos = 0 OR Activo = 1)
    ORDER BY OrdenEnFase;
END;


-- ============================================================================
-- cfg.GetByIdPasosEstudio
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetByIdPasosEstudio]
    @IdPaso INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdPaso,
        IdFase,
        Codigo,
        Nombre,
        OrdenEnFase,
        OrdenGlobal,
        Actor,
        ServicioExterno,
        EsAutomatico,
        RequiereIntervencion,
        TiempoTimeoutSeg,
        Descripcion,
        Activo
    FROM [cfg].[PasosEstudio]
    WHERE IdPaso = @IdPaso;
END;


-- ============================================================================
-- cfg.InsertPasosEstudio
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[InsertPasosEstudio]
    @IdFase               INT,
    @Codigo               VARCHAR(40),
    @Nombre               NVARCHAR(150),
    @OrdenEnFase          INT,
    @OrdenGlobal          INT,
    @Actor                VARCHAR(30)   = 'SISTEMA',
    @ServicioExterno      VARCHAR(50)   = NULL,
    @EsAutomatico         BIT           = 1,
    @RequiereIntervencion BIT           = 0,
    @TiempoTimeoutSeg     INT           = NULL,
    @Descripcion          NVARCHAR(500) = NULL,
    @IdPaso               INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[FasesEstudio] WHERE IdFase = @IdFase)
        BEGIN
            RAISERROR('No existe la fase con IdFase = %d.', 16, 1, @IdFase);
        END;

        IF EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE Codigo = @Codigo)
        BEGIN
            RAISERROR('Ya existe un paso con el código ''%s''.', 16, 1, @Codigo);
        END;

        IF EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE OrdenGlobal = @OrdenGlobal)
        BEGIN
            RAISERROR('El orden global %d ya está en uso por otro paso.', 16, 1, @OrdenGlobal);
        END;

        IF @Actor NOT IN ('ASESOR','SISTEMA','CLIENTE','CALL_CENTER')
        BEGIN
            RAISERROR('El actor ''%s'' no es válido. Use: ASESOR, SISTEMA, CLIENTE o CALL_CENTER.', 16, 1, @Actor);
        END;

        INSERT INTO [cfg].[PasosEstudio] (
            IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal,
            Actor, ServicioExterno, EsAutomatico, RequiereIntervencion,
            TiempoTimeoutSeg, Descripcion
        )
        VALUES (
            @IdFase, @Codigo, @Nombre, @OrdenEnFase, @OrdenGlobal,
            @Actor, @ServicioExterno, @EsAutomatico, @RequiereIntervencion,
            @TiempoTimeoutSeg, @Descripcion
        );

        SET @IdPaso = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdPaso AS IdPaso;
END;


-- ============================================================================
-- cfg.UpdatePasosEstudio
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[UpdatePasosEstudio]
    @IdPaso               INT,
    @Nombre               NVARCHAR(150),
    @OrdenEnFase          INT,
    @OrdenGlobal          INT,
    @Actor                VARCHAR(30),
    @ServicioExterno      VARCHAR(50)   = NULL,
    @EsAutomatico         BIT           = 1,
    @RequiereIntervencion BIT           = 0,
    @TiempoTimeoutSeg     INT           = NULL,
    @Descripcion          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE IdPaso = @IdPaso)
        BEGIN
            RAISERROR('No se encontró el paso con IdPaso = %d.', 16, 1, @IdPaso);
        END;

        IF EXISTS (
            SELECT 1 FROM [cfg].[PasosEstudio]
            WHERE OrdenGlobal = @OrdenGlobal AND IdPaso <> @IdPaso
        )
        BEGIN
            RAISERROR('El orden global %d ya está en uso por otro paso.', 16, 1, @OrdenGlobal);
        END;

        IF @Actor NOT IN ('ASESOR','SISTEMA','CLIENTE','CALL_CENTER')
        BEGIN
            RAISERROR('El actor ''%s'' no es válido. Use: ASESOR, SISTEMA, CLIENTE o CALL_CENTER.', 16, 1, @Actor);
        END;

        UPDATE [cfg].[PasosEstudio]
        SET
            Nombre               = @Nombre,
            OrdenEnFase          = @OrdenEnFase,
            OrdenGlobal          = @OrdenGlobal,
            Actor                = @Actor,
            ServicioExterno      = @ServicioExterno,
            EsAutomatico         = @EsAutomatico,
            RequiereIntervencion = @RequiereIntervencion,
            TiempoTimeoutSeg     = @TiempoTimeoutSeg,
            Descripcion          = @Descripcion
        WHERE IdPaso = @IdPaso;

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
-- cfg.DeactivatePasosEstudio
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[DeactivatePasosEstudio]
    @IdPaso INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[PasosEstudio] WHERE IdPaso = @IdPaso)
        BEGIN
            RAISERROR('No se encontró el paso con IdPaso = %d.', 16, 1, @IdPaso);
        END;

        UPDATE [cfg].[PasosEstudio]
        SET Activo = 0
        WHERE IdPaso = @IdPaso;

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
