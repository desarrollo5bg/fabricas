/*
  Stored Procedures — fab.ConsentimientosLegales
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para registrar consentimientos legales.
  - InsertConsentimientoLegal: C-10 Registrar aceptación de consentimiento legal

  Procedimientos:
    fab.InsertConsentimientoLegal
*/

-- ============================================================================
-- fab.InsertConsentimientoLegal (C-10)
-- ============================================================================
CREATE OR ALTER PROCEDURE [fab].[InsertConsentimientoLegal]
    @IdEstudio              BIGINT,
    @NitTercero             VARCHAR(20),
    @TipoConsentimiento     VARCHAR(40),
    @VersionDocumento       VARCHAR(20) = NULL,
    @Aceptado               BIT = 0,
    @DireccionIP            VARCHAR(45) = NULL,
    @UserAgent              NVARCHAR(500) = NULL,
    @TipoFirma              VARCHAR(20) = 'CHECKBOX',
    @IdConsentimiento       BIGINT OUTPUT
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

        -- Validar TipoFirma
        IF @TipoFirma NOT IN ('OTP_SMS','OTP_EMAIL','OTP_WHATSAPP','CHECKBOX','FIRMA_DIGITAL')
        BEGIN
            RAISERROR('El tipo de firma ''%s'' no es válido.', 16, 1, @TipoFirma);
            RETURN;
        END;

        -- INSERT en fab.ConsentimientosLegales
        INSERT INTO [fab].[ConsentimientosLegales] (
            IdEstudio,
            NitTercero,
            TipoConsentimiento,
            VersionDocumento,
            Aceptado,
            DireccionIP,
            UserAgent,
            TipoFirma,
            FechaAceptacion
        )
        VALUES (
            @IdEstudio,
            @NitTercero,
            @TipoConsentimiento,
            @VersionDocumento,
            @Aceptado,
            @DireccionIP,
            @UserAgent,
            @TipoFirma,
            GETDATE()
        );

        SET @IdConsentimiento = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @Msg      NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @Severity INT            = ERROR_SEVERITY();
        DECLARE @State    INT            = ERROR_STATE();
        RAISERROR(@Msg, @Severity, @State);
    END CATCH;

    SELECT @IdConsentimiento AS IdConsentimiento;

END;
