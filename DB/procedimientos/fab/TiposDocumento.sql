/*
  Stored Procedures — fab.TiposDocumento
  Fecha:  2026-05-06
  Autor:  Edwin Trigos

  NOTA: Procedimientos para obtener tipos de documentos soportados.
  - GetAllTiposDocumento: C-20 Obtener lista de tipos de documento

  Procedimientos:
    fab.GetAllTiposDocumento
*/

-- ============================================================================
-- fab.GetAllTiposDocumento (C-20)
-- ============================================================================
CREATE PROCEDURE [fab].[GetAllTiposDocumento]
AS
BEGIN
    SET NOCOUNT ON;

      -- Retornar tipos de documento comunes en Colombia
    SELECT t.tipo AS TipoDocumento, t.descripcion AS Descripcion
	  from QUAC.dbo.BERP_TercerosTipoDocumento t

END;