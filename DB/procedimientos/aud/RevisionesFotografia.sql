/*
  Stored Procedures — aud.RevisionesFotografia
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para auditoría de revisión de fotografías.
  - InsertRevisionFotografia: C-13 Registrar decisión de revisión de fotografía (ONLY INSERT, never UPDATE)

  Procedimientos:
    aud.InsertRevisionFotografia
*/

-- ============================================================================
-- aud.InsertRevisionFotografia (C-13)
-- ============================================================================
CREATE  PROCEDURE [aud].[InsertRevisionFotografia]
    @IdFotografia           BIGINT,
    @IdEstudio              BIGINT,
    @IdRevisor              INT,
    @NombreRevisor          NVARCHAR(150) = NULL,
    @DecisionRevision       VARCHAR(10),
    @MotivoRechazo          NVARCHAR(300) = NULL,
    @CodigoMotivoRechazo    VARCHAR(40) = NULL,
    @NotasAdicionales       NVARCHAR(500) = NULL,
    @IdRevision             BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que IdFotografia existe
        IF NOT EXISTS (SELECT 1 FROM [fab].[FotografiasEstudio] WHERE IdFotografia = @IdFotografia)
        BEGIN
            RAISERROR('La fotografía con IdFotografia = %d no existe.', 16, 1, @IdFotografia);
            RETURN;
        END;

        -- Validar que IdEstudio existe
        IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE IdEstudio = @IdEstudio)
        BEGIN
            RAISERROR('El estudio con IdEstudio = %d no existe.', 16, 1, @IdEstudio);
            RETURN;
        END;

        -- Validar DecisionRevision
        IF @DecisionRevision NOT IN ('APROBADA','RECHAZADA')
        BEGIN
            RAISERROR('La decisión de revisión ''%s'' no es válida.', 16, 1, @DecisionRevision);
            RETURN;
        END;

        -- Validar CodigoMotivoRechazo si aplica
        IF @DecisionRevision = 'RECHAZADA' AND @CodigoMotivoRechazo IS NOT NULL
        BEGIN
            IF @CodigoMotivoRechazo NOT IN (
                'FOTO_BORROSA','FOTO_CORTADA','DOCUMENTO_VENCIDO','DOCUMENTO_DAÑADO',
                'ROSTRO_NO_VISIBLE','NO_COINCIDE_PERSONA','FOTO_INCORRECTA',
                'REFLEJO_O_BRILLO','FOTO_DUPLICADA','CALIDAD_INSUFICIENTE','OTRO'
            )
            BEGIN
                RAISERROR('El código de motivo ''%s'' no es válido.', 16, 1, @CodigoMotivoRechazo);
                RETURN;
            END;
        END;

        -- INSERT en aud.RevisionesFotografia (TABLA INSERT-ONLY)
        INSERT INTO [aud].[RevisionesFotografia] (
            IdFotografia,
            IdEstudio,
            IdRevisor,
            NombreRevisor,
            DecisionRevision,
            MotivoRechazo,
            CodigoMotivoRechazo,
            NotasAdicionales,
            FechaRevision
        )
        VALUES (
            @IdFotografia,
            @IdEstudio,
            @IdRevisor,
            @NombreRevisor,
            @DecisionRevision,
            @MotivoRechazo,
            @CodigoMotivoRechazo,
            @NotasAdicionales,
            GETDATE()
        );

        SET @IdRevision = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdRevision AS IdRevision;

END;
