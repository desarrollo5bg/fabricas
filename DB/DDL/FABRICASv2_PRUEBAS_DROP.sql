/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — LIMPIEZA DDL (PARA ENTORNO DE PRUEBAS)
  Motor:    SQL Server 2019+
  Versión:  2.5
  Fecha:    2026-04-22
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  NOTA: Este script elimina todo lo creado por FABRICASv2_PRUEBAS.sql.
  Ejecutar en orden inverso para evitar errores de dependencias.
================================================================================
*/

-- ==============================================================================
-- ORDEN DE ELIMINACIÓN: eerst las tablas con FKs, luego las que referencian
-- ==============================================================================

PRINT '============================================================';
PRINT '  INICIANDO LIMPIEZA DE FÁBRICAS v2.5-PRUEBAS';
PRINT '============================================================';
PRINT '';


-- ==============================================================================
-- 1. ELIMINAR FKs EXTERNAS (desde otras tablas hacia las tablas de configuración)
-- ==============================================================================

ALTER TABLE [fab].[EstudiosCredito] DROP CONSTRAINT IF EXISTS FK_EstudiosCredito_ValidacionAsesor;
PRINT '✓ FK: FK_EstudiosCredito_ValidacionAsesor eliminada';

ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Frontal;
ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Reverso;
ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Selfie;
PRINT '✓ FKs: FotografiasEstudio eliminadas de RegistrosBiometria';

ALTER TABLE [fab].[ValidacionesContactabilidad] DROP CONSTRAINT IF EXISTS FK_ValidContact_AlertaFraude;
PRINT '✓ FK: FK_ValidContact_AlertaFraude eliminada';


-- ==============================================================================
-- 2. ELIMINAR TABLAS DE AUDITORÍA (INSERT-ONLY, sin dependientes)
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[AuditoriaLogins];
PRINT '✓ Tabla aud.AuditoriaLogins eliminada';

DROP TABLE IF EXISTS [fab].[HistorialFotografias];
PRINT '✓ Tabla fab.HistorialFotografias eliminada';

DROP TABLE IF EXISTS [fab].[SolicitudesRecarga];
PRINT '✓ Tabla fab.SolicitudesRecarga eliminada';

DROP TABLE IF EXISTS [fab].[RevisionesFotografia];
PRINT '✓ Tabla fab.RevisionesFotografia eliminada';

DROP TABLE IF EXISTS [fab].[FotografiasEstudio];
PRINT '✓ Tabla fab.FotografiasEstudio eliminada';

DROP TABLE IF EXISTS [cat].[CatalogoTiposFotografia];
PRINT '✓ Tabla cat.CatalogoTiposFotografia eliminada';


-- ==============================================================================
-- 3. ELIMINAR TABLAS DE PARCHE V2.4 — ValidacionesAsesor
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[ValidacionesAsesor];
PRINT '✓ Tabla fab.ValidacionesAsesor eliminada';


-- ==============================================================================
-- 4. ELIMINAR TABLAS DE PARCHE V2.2 — Architect Audit
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[HistorialDatosSensibles];
PRINT '✓ Tabla aud.HistorialDatosSensibles eliminada';

DROP TABLE IF EXISTS [aud].[LogValidacionesOTP];
PRINT '✓ Tabla aud.LogValidacionesOTP eliminada';

DROP TABLE IF EXISTS [fab].[EscalamientosFabrica];
PRINT '✓ Tabla fab.EscalamientosFabrica eliminada';

DROP TABLE IF EXISTS [aud].[AlertasFraude];
PRINT '✓ Tabla aud.AlertasFraude eliminada';

DROP TABLE IF EXISTS [cat].[CatalogoMotivosEscalamiento];
PRINT '✓ Tabla cat.CatalogoMotivosEscalamiento eliminada';

DROP TABLE IF EXISTS [cat].[CatalogoReglasFraude];
PRINT '✓ Tabla cat.CatalogoReglasFraude eliminada';


-- ==============================================================================
-- 5. ELIMINAR TABLAS DE AUDITORÍA PRINCIPALES
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[RegistroServiciosExternos];
PRINT '✓ Tabla aud.RegistroServiciosExternos eliminada';

DROP TABLE IF EXISTS [aud].[AuditoriaCambiosDatos];
PRINT '✓ Tabla aud.AuditoriaCambiosDatos eliminada';

DROP TABLE IF EXISTS [aud].[HistorialEstados];
PRINT '✓ Tabla aud.HistorialEstados eliminada';


-- ==============================================================================
-- 6. ELIMINAR TABLAS TRANSACCIONALES
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[EvidenciasFabrica];
PRINT '✓ Tabla fab.EvidenciasFabrica eliminada';

DROP TABLE IF EXISTS [fab].[ConsentimientosLegales];
PRINT '✓ Tabla fab.ConsentimientosLegales eliminada';

DROP TABLE IF EXISTS [fab].[ValidacionesContactabilidad];
PRINT '✓ Tabla fab.ValidacionesContactabilidad eliminada';

DROP TABLE IF EXISTS [fab].[RegistrosBiometria];
PRINT '✓ Tabla fab.RegistrosBiometria eliminada';

DROP TABLE IF EXISTS [fab].[EvaluacionesRiesgo];
PRINT '✓ Tabla fab.EvaluacionesRiesgo eliminada';

DROP TABLE IF EXISTS [fab].[RetosSeguridad];
PRINT '✓ Tabla fab.RetosSeguridad eliminada';

DROP TABLE IF EXISTS [fab].[EstudiosCredito];
PRINT '✓ Tabla fab.EstudiosCredito eliminada';


-- ==============================================================================
-- 7. ELIMINAR TABLA DE INTEGRACIÓN (TercerosFabricas)
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[TercerosFabricas];
PRINT '✓ Tabla fab.TercerosFabricas eliminada';


-- ==============================================================================
-- 8. ELIMINAR TABLAS DE CONFIGURACIÓN
-- ==============================================================================

DROP TABLE IF EXISTS [cat].[CatalogoCanalesOrigen];
PRINT '✓ Tabla cat.CatalogoCanalesOrigen eliminada';

DROP TABLE IF EXISTS [cfg].[ConfiguracionReglasNegocio];
PRINT '✓ Tabla cfg.ConfiguracionReglasNegocio eliminada';

DROP TABLE IF EXISTS [cfg].[TransicionesEstado];
PRINT '✓ Tabla cfg.TransicionesEstado eliminada';

DROP TABLE IF EXISTS [cfg].[CatalogoEstados];
PRINT '✓ Tabla cfg.CatalogoEstados eliminada';

DROP TABLE IF EXISTS [cfg].[PasosEstudio];
PRINT '✓ Tabla cfg.PasosEstudio eliminada';

DROP TABLE IF EXISTS [cfg].[FasesEstudio];
PRINT '✓ Tabla cfg.FasesEstudio eliminada';


-- ==============================================================================
-- 9. ELIMINAR ESQUEMAS (solo si están vacíos)
-- ==============================================================================

-- Los esquemas no se eliminan si tienen objetos, así que primero verificamos
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('aud')) 
   DROP SCHEMA IF EXISTS aud;
PRINT '✓ Esquema aud eliminado (si estaba vacío)';

IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('fab')) 
   DROP SCHEMA IF EXISTS fab;
PRINT '✓ Esquema fab eliminado (si estaba vacío)';

IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('cat')) 
   DROP SCHEMA IF EXISTS cat;
PRINT '✓ Esquema cat eliminado (si estaba vacío)';

IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('cfg')) 
   DROP SCHEMA IF EXISTS cfg;
PRINT '✓ Esquema cfg eliminado (si estaba vacío)';


-- ==============================================================================
-- 10. ELIMINAR TABLAS EXTERNAS REPLICADAS (modo PRUEBAS)
-- ==============================================================================

-- Primero: ELIMINAR LAS COLUMNAS añadidas por FÁBRICAS (con sus DEFAULT constraints)
-- Nota: Los constraints de DEFAULT se eliminan automáticamente al eliminar la columna

-- Columnas de KCRM_CadenaCreditos
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS ElegibleReactivacion;
    PRINT '✓ Columna ElegibleReactivacion eliminada de KCRM_CadenaCreditos';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'EstadoActualFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS EstadoActualFabricas;
    PRINT '✓ Columna EstadoActualFabricas eliminada de KCRM_CadenaCreditos';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS MotivoBloqueoFabricas;
    PRINT '✓ Columna MotivoBloqueoFabricas eliminada de KCRM_CadenaCreditos';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS FechaCancelacionFabricas;
    PRINT '✓ Columna FechaCancelacionFabricas eliminada de KCRM_CadenaCreditos';
END

-- Columnas de BERP_FABRICASOperadores
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.BERP_FABRICASOperadores') AND name = 'activo')
BEGIN
    ALTER TABLE dbo.BERP_FABRICASOperadores DROP COLUMN IF EXISTS activo;
    PRINT '✓ Columna activo eliminada de BERP_FABRICASOperadores';
END

-- Ahora: eliminar las tablas réplica (solo si existen y están en este script)
-- Nota: En producción estas tablas YA EXISTEN y no se deben eliminar

DROP TABLE IF EXISTS [dbo].[KCRM_CadenaCreditos];
PRINT '✓ Tabla dbo.KCRM_CadenaCreditos (réplica local) eliminada';

DROP TABLE IF EXISTS [dbo].[BERP_FABRICASOperadores];
PRINT '✓ Tabla dbo.BERP_FABRICASOperadores (réplica local) eliminada';

DROP TABLE IF EXISTS [dbo].[bodegas];
PRINT '✓ Tabla dbo.bodegas (réplica local) eliminada';

DROP TABLE IF EXISTS [dbo].[terceros];
PRINT '✓ Tabla dbo.terceros (réplica local) eliminada';


-- ==============================================================================
-- RESUMEN
-- ==============================================================================

PRINT '';
PRINT '============================================================';
PRINT '  LIMPIEZA COMPLETADA';
PRINT '============================================================';
PRINT '';
PRINT 'Elementos eliminados:';
PRINT '  - 29 tablas de los esquemas aud/fab/cat/cfg';
PRINT '  - 4 tablas réplica en dbo';
PRINT '  - 4 esquemas lógicos (aud, fab, cat, cfg)';
PRINT '  - 5 columnas adds de KCRM_CadenaCreditos y BERP_FABRICASOperadores';
PRINT '';
PRINT '✓ Limpieza ejecutada exitosamente';
PRINT '';
