/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — LIMPIEZA DDL (PARA ENTORNO DE PRUEBAS)
  Motor:    SQL Server 2019+
  Versión:  2.8
  Fecha:    2026-05-05
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  NOTA: Este script elimina todo lo creado por FABRICASv2_PRUEBAS.sql.
  Ejecutar en orden inverso para evitar errores de dependencias.
================================================================================
*/

-- ==============================================================================
-- ORDEN DE ELIMINACIÓN: primero las tablas con FKs, luego las que referencian
-- ==============================================================================

PRINT '============================================================';
PRINT '  INICIANDO LIMPIEZA DE FÁBRICAS v2.8-PRUEBAS';
PRINT '============================================================';


-- ==============================================================================
-- 1. ELIMINAR FKs EXTERNAS (desde otras tablas hacia las tablas de configuración)
-- ==============================================================================

ALTER TABLE [fab].[EstudiosCredito] DROP CONSTRAINT IF EXISTS FK_EstudiosCredito_ValidacionAsesor;
ALTER TABLE [fab].[EstudiosCredito] DROP CONSTRAINT IF EXISTS FK_EstudiosCredito_Asesor;


ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Frontal;
ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Reverso;
ALTER TABLE [fab].[RegistrosBiometria] DROP CONSTRAINT IF EXISTS FK_RegistrosBiometria_Selfie;


ALTER TABLE [fab].[ValidacionesContactabilidad] DROP CONSTRAINT IF EXISTS FK_ValidContact_AlertaFraude;



-- ==============================================================================
-- 2. ELIMINAR TABLAS DE AUDITORÍA (INSERT-ONLY, sin dependientes)
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[AuditoriaLogins];


DROP TABLE IF EXISTS [aud].[HistorialFotografias];


DROP TABLE IF EXISTS [fab].[SolicitudesRecarga];


DROP TABLE IF EXISTS [aud].[RevisionesFotografia];


DROP TABLE IF EXISTS [fab].[FotografiasEstudio];


DROP TABLE IF EXISTS [cat].[CatalogoTiposFotografia];



-- ==============================================================================
-- 3. ELIMINAR TABLAS DE PARCHE V2.4 — ValidacionesAsesor
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[ValidacionesAsesor];



-- ==============================================================================
-- 4. ELIMINAR TABLAS DE PARCHE V2.2 — Architect Audit
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[HistorialDatosSensibles];


DROP TABLE IF EXISTS [aud].[LogValidacionesOTP];


DROP TABLE IF EXISTS [fab].[EscalamientosFabrica];


DROP TABLE IF EXISTS [aud].[AlertasFraude];


DROP TABLE IF EXISTS [cat].[CatalogoMotivosEscalamiento];


DROP TABLE IF EXISTS [cat].[CatalogoReglasFraude];



-- ==============================================================================
-- 5. ELIMINAR TABLAS DE AUDITORÍA PRINCIPALES
-- ==============================================================================

DROP TABLE IF EXISTS [aud].[RegistroServiciosExternos];


DROP TABLE IF EXISTS [aud].[AuditoriaCambiosDatos];


DROP TABLE IF EXISTS [aud].[HistorialEstados];



-- ==============================================================================
-- 6. ELIMINAR TABLAS TRANSACCIONALES
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[EvidenciasFabrica];


DROP TABLE IF EXISTS [fab].[ConsentimientosLegales];


DROP TABLE IF EXISTS [fab].[ValidacionesContactabilidad];


DROP TABLE IF EXISTS [fab].[RegistrosBiometria];


DROP TABLE IF EXISTS [fab].[EvaluacionesRiesgo];


DROP TABLE IF EXISTS [fab].[RetosSeguridad];


DROP TABLE IF EXISTS [fab].[EstudiosCredito];



-- ==============================================================================
-- 7. ELIMINAR TABLAS DE INTEGRACIÓN (TercerosFabricas, OperadoresFabrica)
-- ==============================================================================

DROP TABLE IF EXISTS [fab].[TercerosFabricas];


DROP TABLE IF EXISTS [fab].[DisponibilidadOperadores];


DROP TABLE IF EXISTS [fab].[OperadoresFabrica];



-- ==============================================================================
-- 8. ELIMINAR TABLAS DE CONFIGURACIÓN
-- ==============================================================================

DROP TABLE IF EXISTS [cat].[CatalogoCanalesOrigen];


DROP TABLE IF EXISTS [cfg].[CentralesRiesgoCfg];


DROP TABLE IF EXISTS [cfg].[ConfiguracionReglasNegocio];


DROP TABLE IF EXISTS [cfg].[TransicionesEstado];


DROP TABLE IF EXISTS [cfg].[EstudiosCredito];


DROP TABLE IF EXISTS [cfg].[PasosEstudio];


DROP TABLE IF EXISTS [cfg].[FasesEstudio];



-- ==============================================================================
-- 9. ELIMINAR ESQUEMAS (solo si están vacíos)
-- ==============================================================================

-- Los esquemas no se eliminan si tienen objetos, así que primero verificamos
IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('aud')) 
   DROP SCHEMA IF EXISTS aud;


IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('fab')) 
   DROP SCHEMA IF EXISTS fab;


IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('cat')) 
   DROP SCHEMA IF EXISTS cat;


IF NOT EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('cfg')) 
   DROP SCHEMA IF EXISTS cfg;



-- ==============================================================================
-- 10. ELIMINAR TABLAS EXTERNAS REPLICADAS (modo PRUEBAS)
-- ==============================================================================

-- Primero: ELIMINAR LAS COLUMNAS añadidas por FÁBRICAS (con sus DEFAULT constraints)
-- Nota: Los constraints de DEFAULT se eliminan automáticamente al eliminar la columna

-- Columnas de KCRM_CadenaCreditos
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'ElegibleReactivacion')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS ElegibleReactivacion;

END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'EstadoActualFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS EstadoActualFabricas;

END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'MotivoBloqueoFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS MotivoBloqueoFabricas;

END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.KCRM_CadenaCreditos') AND name = 'FechaCancelacionFabricas')
BEGIN
    ALTER TABLE dbo.KCRM_CadenaCreditos DROP COLUMN IF EXISTS FechaCancelacionFabricas;

END

-- Columnas de BERP_FABRICASOperadores
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.BERP_FABRICASOperadores') AND name = 'activo')
BEGIN
    ALTER TABLE dbo.BERP_FABRICASOperadores DROP COLUMN IF EXISTS activo;

END


-- ==============================================================================
-- RESUMEN
-- ==============================================================================

PRINT '============================================================';
PRINT '  LIMPIEZA FÁBRICAS v2.8-PRUEBAS COMPLETADA';
PRINT '============================================================';
PRINT '✓ Limpieza ejecutada exitosamente';
