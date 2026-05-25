/*
  Stored Procedures — aud.HistorialDatosSensibles
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para auditoría de cambios en datos sensibles.
  - InsertAuditoriaCambioDatos: C-15 Registrar cambio en datos sensibles (ONLY INSERT, never UPDATE)

  Procedimientos:
    aud.InsertAuditoriaCambioDatos
*/

-- ============================================================================
-- aud.InsertAuditoriaCambioDatos (C-15)
-- ============================================================================
CREATE OR ALTER PROCEDURE [aud].[InsertAuditoriaCambioDatos]
    @IdEstudio              BIGINT,
    @NitTercero             VARCHAR(20),
    @CampoCambiado          VARCHAR(50),
    @ValorOriginal          NVARCHAR(300) = NULL,
    @ValorNuevo             NVARCHAR(300) = NULL,
    @IdRetoActivoAlCambio   BIGINT = NULL,
    @EsPostFalloOTP         BIT = 0,
    @TipoActor              VARCHAR(20) = 'CLIENTE',
    @DireccionIP            VARCHAR(45) = NULL,
    @UserAgent              NVARCHAR(500) = NULL,
    @MotivoDeclarado        NVARCHAR(300) = NULL,
    @IdHistorialDato        BIGINT OUTPUT
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

        -- Validar TipoActor
        IF @TipoActor NOT IN ('CLIENTE','ASESOR','SISTEMA')
        BEGIN
            RAISERROR('El tipo de actor ''%s'' no es válido.', 16, 1, @TipoActor);
            RETURN;
        END;

        -- INSERT en aud.HistorialDatosSensibles (TABLA INSERT-ONLY)
        INSERT INTO [aud].[HistorialDatosSensibles] (
            IdEstudio,
            NitTercero,
            CampoCambiado,
            ValorOriginal,
            ValorNuevo,
            IdRetoActivoAlCambio,
            EsPostFalloOTP,
            TipoActor,
            DireccionIP,
            UserAgent,
            MotivoDeclarado,
            FechaCambio
        )
        VALUES (
            @IdEstudio,
            @NitTercero,
            @CampoCambiado,
            @ValorOriginal,
            @ValorNuevo,
            @IdRetoActivoAlCambio,
            @EsPostFalloOTP,
            @TipoActor,
            @DireccionIP,
            @UserAgent,
            @MotivoDeclarado,
            GETDATE()
        );

        SET @IdHistorialDato = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdHistorialDato AS IdHistorial;

END;
