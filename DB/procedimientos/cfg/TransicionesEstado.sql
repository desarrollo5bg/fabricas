/*
  Stored Procedures — cfg.TransicionesEstado
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  Procedimientos:
    cfg.GetAllTransicionesEstado
    cfg.GetByOrigenTransicionesEstado
    cfg.InsertTransicionesEstado
    cfg.DeactivateTransicionesEstado
*/

-- ============================================================================
-- cfg.GetAllTransicionesEstado
--   Devuelve todas las transiciones enriquecidas con los códigos de los estados
--   origen y destino. Con @SoloActivas = 1 filtra las transiciones inactivas.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetAllTransicionesEstado]
    @SoloActivas BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.IdTransicion,
        eOrigen.Codigo      AS CodigoOrigen,
        eOrigen.Nombre      AS NombreOrigen,
        eDestino.Codigo     AS CodigoDestino,
        eDestino.Nombre     AS NombreDestino,
        t.RequiereMotivo,
        t.Descripcion,
        t.Activa
    FROM [cfg].[TransicionesEstado] t
    INNER JOIN [cfg].[CatalogoEstados] eOrigen  ON eOrigen.IdEstado  = t.IdEstadoOrigen
    INNER JOIN [cfg].[CatalogoEstados] eDestino ON eDestino.IdEstado = t.IdEstadoDestino
    WHERE (@SoloActivas = 0 OR t.Activa = 1)
    ORDER BY eOrigen.Codigo, eDestino.Codigo;
END;


-- ============================================================================
-- cfg.GetByOrigenTransicionesEstado
--   Devuelve las transiciones activas disponibles desde un estado origen dado.
--   Parámetro: @CodigoOrigen — código del estado desde el que se va a transicionar.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[GetByOrigenTransicionesEstado]
    @CodigoOrigen VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = @CodigoOrigen)
    BEGIN
        RAISERROR('No se encontró un estado con código ''%s''.', 16, 1, @CodigoOrigen);
        RETURN;
    END;

    SELECT
        t.IdTransicion,
        eDestino.Codigo     AS CodigoDestino,
        eDestino.Nombre     AS NombreDestino,
        t.RequiereMotivo,
        t.Descripcion
    FROM [cfg].[TransicionesEstado] t
    INNER JOIN [cfg].[CatalogoEstados] eOrigen  ON eOrigen.IdEstado  = t.IdEstadoOrigen
    INNER JOIN [cfg].[CatalogoEstados] eDestino ON eDestino.IdEstado = t.IdEstadoDestino
    WHERE eOrigen.Codigo = @CodigoOrigen
      AND t.Activa = 1
    ORDER BY eDestino.Codigo;
END;


-- ============================================================================
-- cfg.InsertTransicionesEstado
--   Inserta una nueva transición entre dos estados existentes.
--   No hay Update: para corregir una transición se desactiva y se crea una nueva.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[InsertTransicionesEstado]
    @CodigoOrigen   VARCHAR(40),
    @CodigoDestino  VARCHAR(40),
    @RequiereMotivo BIT           = 0,
    @Descripcion    NVARCHAR(200) = NULL,
    @IdTransicion   INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdEstadoOrigen  INT;
        DECLARE @IdEstadoDestino INT;

        SELECT @IdEstadoOrigen  = IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = @CodigoOrigen;
        SELECT @IdEstadoDestino = IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = @CodigoDestino;

        IF @IdEstadoOrigen IS NULL
        BEGIN
            RAISERROR('No se encontró el estado origen con código ''%s''.', 16, 1, @CodigoOrigen);
        END;

        IF @IdEstadoDestino IS NULL
        BEGIN
            RAISERROR('No se encontró el estado destino con código ''%s''.', 16, 1, @CodigoDestino);
        END;

        IF EXISTS (
            SELECT 1 FROM [cfg].[TransicionesEstado]
            WHERE IdEstadoOrigen = @IdEstadoOrigen AND IdEstadoDestino = @IdEstadoDestino
        )
        BEGIN
            RAISERROR('Ya existe una transición entre ''%s'' y ''%s''.', 16, 1, @CodigoOrigen, @CodigoDestino);
        END;

        INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
        VALUES (@IdEstadoOrigen, @IdEstadoDestino, @RequiereMotivo, @Descripcion);

        SET @IdTransicion = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdTransicion AS IdTransicion;
END;


-- ============================================================================
-- cfg.DeactivateTransicionesEstado
--   Marca la transición como inactiva (Activa = 0).
--   No se elimina: el historial de estados puede referenciar transiciones pasadas.
-- ============================================================================
CREATE OR ALTER PROCEDURE [cfg].[DeactivateTransicionesEstado]
    @IdTransicion INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] WHERE IdTransicion = @IdTransicion)
        BEGIN
            RAISERROR('No se encontró una transición con IdTransicion = %d.', 16, 1, @IdTransicion);
        END;

        IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] WHERE IdTransicion = @IdTransicion AND Activa = 1)
        BEGIN
            -- Severity 10 = informativo, no lanza excepción al cliente
            RAISERROR('La transición con IdTransicion = %d ya se encuentra inactiva.', 10, 1, @IdTransicion);
        END;

        UPDATE [cfg].[TransicionesEstado]
        SET Activa = 0
        WHERE IdTransicion = @IdTransicion;

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
