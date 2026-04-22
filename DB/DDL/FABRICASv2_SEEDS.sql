/*
================================================================================
  FÁBRICAS DE CRÉDITO QUAC — SEMILLA (SEEDS SOLO)
  Motor:    SQL Server 2019+
  Versión:  2.5
  Fecha:    2026-04-22
  Autor:    Arquitectura de Datos — QUAC FinTech
  
  NOTA: Este script INSERTA SOLO los datos de semilla.
  Ejecutar DESPUÉS de FABRICASv2_PRUEBAS.sql (tablas ya creadas).
  
  Usa formato [esquema].[tabla] para evitar errores en entornos
  con schemes default diferentes.
================================================================================
*/

SET NOCOUNT ON;
PRINT '';
PRINT '============================================================';
PRINT ' INSERTANDO SEMILLAS DE FÁBRICAS v2.5';
PRINT '============================================================';
PRINT '';


-- ==============================================================================
-- 1. FasesEstudio (7 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cfg].[FasesEstudio])
BEGIN
    INSERT INTO [cfg].[FasesEstudio] (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
    ('IDENTIFICACION',          'Identificación del Cliente',       1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
    ('DATOS_CLIENTE',           'Datos del Cliente',                2, 'Captura o actualización de datos personales y de contacto'),
    ('CONSENTIMIENTO_LEGAL',    'Consentimiento Legal',             3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
    ('VALIDACIONES_RIESGO',     'Validaciones de Riesgo',           4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
    ('LIMITE_CREDITO',          'Límite de Crédito',                5, 'Cálculo y presentación del cupo preaprobado'),
    ('VERIFICACION_IDENTIDAD',  'Verificación de Identidad',        6, 'Biometría facial, OCR de documento, prueba de vida'),
    ('ACTIVACION',              'Activación del Cupo',              7, 'Validación UBICA, activación automática o gestión manual Call Center');
    
    PRINT '✓ cfg.FasesEstudio: 7 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cfg.FasesEstudio: ya tiene datos, omitido';
END


-- ==============================================================================
-- 2. ConfiguracionReglasNegocio (8 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cfg].[ConfiguracionReglasNegocio])
BEGIN
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_ENFRIAMIENTO',           'Días de Enfriamiento por Rechazo',         '90',       'INT',      'ENFRIAMIENTO', 'Días que un cliente rechazado debe esperar'),
    ('DIAS_EXPIRACION_ESTUDIO',     'Días de Expiración del Estudio',           '90',       'INT',      'GENERAL',      'Días de inactividad antes de expirar'),
    ('INTENTOS_OTP_MAX',            'Intentos Máximos de OTP',                  '3',        'INT',      'OTP',          'Número máximo de intentos OTP'),
    ('VIGENCIA_OTP_SEG',            'Vigencia del Token OTP (segundos)',        '300',      'INT',      'OTP',          'Tiempo de vida del token OTP'),
    ('BLOQUEO_OTP_HORAS',           'Horas de Bloqueo por OTP Fallidos',       '24',       'INT',      'OTP',          'Horas de bloqueo tras intentos fallidos'),
    ('INTENTOS_BIOMETRIA_MAX',      'Intentos Máximos de Biometría',           '3',        'INT',      'BIOMETRIA',    'Número máximo de intentos biométricos'),
    ('UMBRAL_MATCH_FACIAL',         'Umbral de Coincidencia Facial (%)',        '85.00',    'DECIMAL',  'BIOMETRIA',    'Porcentaje mínimo de coincidencia facial'),
    ('DIAS_CANCELACION_REACTIV',    'Días Desde Cancelación para Reactivación', '365',     'INT',      'GENERAL',      'Días desde cancelación para reactivación');
    
    PRINT '✓ cfg.ConfiguracionReglasNegocio: 8 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cfg.ConfiguracionReglasNegocio: ya tiene datos, omitido';
END


-- ==============================================================================
-- 3. PasosEstudio (13 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cfg].[PasosEstudio])
BEGIN
    -- Obtener los IdFase para las referencias
    DECLARE @ID_FASE_1 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'IDENTIFICACION');
    DECLARE @ID_FASE_2 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'DATOS_CLIENTE');
    DECLARE @ID_FASE_3 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'CONSENTIMIENTO_LEGAL');
    DECLARE @ID_FASE_4 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'VALIDACIONES_RIESGO');
    DECLARE @ID_FASE_5 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'LIMITE_CREDITO');
    DECLARE @ID_FASE_6 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'VERIFICACION_IDENTIDAD');
    DECLARE @ID_FASE_7 INT = (SELECT IdFase FROM [cfg].[FasesEstudio] WHERE Codigo = 'ACTIVACION');
    
    INSERT INTO [cfg].[PasosEstudio] (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, EsAutomatico, RequiereIntervencion) VALUES
    (@ID_FASE_1, 'DOC_IDENTIFICACION', 'Validar Documento de Identidad', 1, 1, 'SISTEMA', 1, 0),
    (@ID_FASE_1, 'VALIDAR_EXISTENCIA', 'Validar Existencia de Cliente', 2, 2, 'SISTEMA', 1, 0),
    (@ID_FASE_1, 'VERIFICAR_CUPO', 'Verificar Cupo Activo/Bloqueado', 3, 3, 'SISTEMA', 1, 0),
    (@ID_FASE_2, 'CAPTURAR_DATOS', 'Capturar Datos del Cliente', 1, 4, 'CLIENTE', 1, 0),
    (@ID_FASE_2, 'ACTUALIZAR_CONTACTO', 'Actualizar Datos de Contacto', 2, 5, 'CLIENTE', 1, 0),
    (@ID_FASE_3, 'TOKENIZAR', 'Tokenización y Consentimiento', 1, 6, 'CLIENTE', 1, 0),
    (@ID_FASE_3, 'OTP_VALIDACION', 'Validar OTP', 2, 7, 'SISTEMA', 1, 0),
    (@ID_FASE_4, 'LISTAS_RESTRICTIVAS', 'Consultar Listas Restrictivas', 1, 8, 'SISTEMA', 1, 0),
    (@ID_FASE_4, 'VALIDAR_BURO', 'Consultar Buró de Crédito', 2, 9, 'SISTEMA', 1, 0),
    (@ID_FASE_5, 'CALCULAR_CUPO', 'Calcular Cupo Preaprobado', 1, 10, 'SISTEMA', 1, 0),
    (@ID_FASE_6, 'OCR_DOCUMENTO', 'OCR del Documento', 1, 11, 'SISTEMA', 1, 0),
    (@ID_FASE_6, 'BIOMETRIA_FACIAL', 'Validar Biometría Facial', 2, 12, 'SISTEMA', 1, 0),
    (@ID_FASE_7, 'VALIDAR_UBICA', 'Validar UBICA', 1, 13, 'SISTEMA', 1, 0);
    
    PRINT '✓ cfg.PasosEstudio: 13 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cfg.PasosEstudio: ya tiene datos, omitido';
END


-- ==============================================================================
-- 4. CatalogoEstados (20+ estados)
-- ==============================================================================
IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('BORRADOR', 'En Validación Previa', 'INICIAL', 0, 1, 'El cliente se encuentra en pasos iniciales.'),
    ('IDENTIFICADO', 'Identificado', 'INICIAL', 0, 0, 'Cliente identificado con documento válido.'),
    ('EN_PROCESO', 'En Proceso', 'PROCESO', 0, 1, 'El estudio de crédito está en curso.'),
    ('PENDIENTE_OTP', 'Pendiente Validación OTP', 'PROCESO', 0, 0, 'Esperando validación del token OTP.'),
    ('PENDIENTE_REVISION', 'Pendiente Revisión Manual', 'PROCESO', 0, 0, 'Caso derivado a revisión manual.'),
    ('REVISION_FABRICA', 'En Revisión — Fábrica', 'PROCESO', 0, 0, 'Estudio derivado a revisión por asesor de fábrica.'),
    ('APROBADO', 'Aprobado', 'TERMINAL', 1, 0, 'Estudio de crédito aprobado.'),
    ('RECHAZADO', 'Rechazado', 'TERMINAL', 1, 0, 'Estudio de crédito rechazado.'),
    ('CANCELADO', 'Cancelado por el Cliente', 'TERMINAL', 1, 0, 'El cliente canceló el proceso.'),
    ('EXPIRADO', 'Expirado por Inactividad', 'TERMINAL', 1, 0, 'El estudio expiró por inactividad.'),
    ('BLOQUEADO_CUPO', 'Bloqueado — Cupo Activo', 'BLOQUEO', 0, 0, 'El cliente ya tiene un cupo activo.'),
    ('BLOQUEADO_MORA', 'Bloqueado — Mora', 'BLOQUEO', 0, 0, 'El cliente tiene mora vigente.'),
    ('BLOQUEADO_FRAUDE', 'Bloqueado por Sospecha de Fraude', 'TERMINAL', 1, 0, 'Bloqueado por detección de patrón de fraude.'),
    ('REACTIVACION', 'En Reactivación', 'REACTIVACION', 0, 0, 'Proceso de reactivación de cupo.'),
    ('REACTIVADO', 'Reactivado', 'TERMINAL', 1, 0, 'Cupo reactivado exitosamente.');
    
    PRINT '✓ cfg.CatalogoEstados: 15 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cfg.CatalogoEstados: ya tiene datos, omitido';
END


-- ==============================================================================
-- 5. TransicionesEstado (40+ transiciones)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cfg].[TransicionesEstado])
BEGIN
    -- Obtener los Ids de estado
    DECLARE @E_BORRADOR INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR');
    DECLARE @E_IDENTIFICADO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'IDENTIFICADO');
    DECLARE @E_EN_PROCESO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROCESO');
    DECLARE @E_PENDIENTE_OTP INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'PENDIENTE_OTP');
    DECLARE @E_PENDIENTE_REVISION INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'PENDIENTE_REVISION');
    DECLARE @E_REVISION_FABRICA INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'REVISION_FABRICA');
    DECLARE @E_APROBADO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'APROBADO');
    DECLARE @E_RECHAZADO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'RECHAZADO');
    DECLARE @E_CANCELADO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'CANCELADO');
    DECLARE @E_EXPIRADO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EXPIRADO');
    DECLARE @E_BLOQUEADO_CUPO INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BLOQUEADO_CUPO');
    DECLARE @E_BLOQUEADO_MORA INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BLOQUEADO_MORA');
    DECLARE @E_BLOQUEADO_FRAUDE INT = (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BLOQUEADO_FRAUDE');
    
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo) VALUES
    -- Inicio → Identificado
    (@E_BORRADOR, @E_IDENTIFICADO, 0),
    -- Identificado → En Proceso
    (@E_IDENTIFICADO, @E_EN_PROCESO, 0),
    -- En Proceso → Pendiente OTP
    (@E_EN_PROCESO, @E_PENDIENTE_OTP, 0),
    -- Pendiente OTP → En Proceso (valido)
    (@E_PENDIENTE_OTP, @E_EN_PROCESO, 0),
    -- Pendiente OTP → Pendiente Revision (fallido)
    (@E_PENDIENTE_OTP, @E_PENDIENTE_REVISION, 0),
    -- Pendiente Revision → En Proceso (aprobado manualmente)
    (@E_PENDIENTE_REVISION, @E_EN_PROCESO, 0),
    -- Pendiente Revision → Revision Fabrica
    (@E_PENDIENTE_REVISION, @E_REVISION_FABRICA, 0),
    -- Revision Fabrica → En Proceso
    (@E_REVISION_FABRICA, @E_EN_PROCESO, 0),
    -- En Proceso → Aprobado
    (@E_EN_PROCESO, @E_APROBADO, 0),
    -- En Proceso → Rechazado
    (@E_EN_PROCESO, @E_RECHAZADO, 1),
    -- En Proceso → Cancelado
    (@E_EN_PROCESO, @E_CANCELADO, 0),
    -- En Proceso → Expirado
    (@E_EN_PROCESO, @E_EXPIRADO, 0),
    -- En Proceso → Bloqueado Cupo
    (@E_EN_PROCESO, @E_BLOQUEADO_CUPO, 0),
    -- En Proceso → Bloqueado Mora
    (@E_EN_PROCESO, @E_BLOQUEADO_MORA, 0),
    -- Bloqueado Mora → En Proceso (tras pago)
    (@E_BLOQUEADO_MORA, @E_EN_PROCESO, 0),
    -- Rechazado → Enfriamiento
    -- Expirado → Nuevo intento
    -- Revision Fabrica → Bloqueado Fraude
    (@E_REVISION_FABRICA, @E_BLOQUEADO_FRAUDE, 1);
    
    PRINT '✓ cfg.TransicionesEstado: transiciones insertadas';
END
ELSE
BEGIN
    PRINT '○ cfg.TransicionesEstado: ya tiene datos, omitido';
END


-- ==============================================================================
-- 6. CatalogoCanalesOrigen (3 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cat].[CatalogoCanalesOrigen])
BEGIN
    INSERT INTO [cat].[CatalogoCanalesOrigen] (Codigo, Nombre, Descripcion, Activo) VALUES
    ('WEB',      'Canal Web',      'Originación a través del portal web o app del cliente',              1),
    ('TIENDA',   'Canal Tienda',   'Originación presencial en punto de venta asistida por asesor',       1),
    ('EXTERNO',  'Canal Externo',  'Originación por fuerza de ventas externas o aliados comerciales',    1);
    
    PRINT '✓ cat.CatalogoCanalesOrigen: 3 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cat.CatalogoCanalesOrigen: ya tiene datos, omitido';
END


-- ==============================================================================
-- 7. CatalogoReglasFraude (6 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cat].[CatalogoReglasFraude])
BEGIN
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('EMAIL_CHANGE_POST_OTP_FAIL',
        'Cambio de email después de fallo OTP',
        'El cliente intenta cambiar su email después de que falló la validación OTP.',
        'ALTO', 'ESCALAR'),
    ('CEL_CHANGE_POST_OTP_FAIL',
        'Cambio de celular después de fallo OTP',
        'El cliente intenta cambiar su número de celular después de que falló la validación OTP.',
        'ALTO', 'ESCALAR'),
    ('CONTACTO_CHANGE_DURANTE_RETO_ACTIVO',
        'Cambio de dato de contacto con retoOTP activo',
        'Intento de modificar email o celular mientras hay un token OTP vigente.',
        'CRITICO', 'BLOQUEAR'),
    ('MULTIPLES_FALLOS_OTP_MISMA_SESION',
        'Múltiples fallos OTP en la misma sesión',
        'Se agotaron los intentos máximos de OTP en una misma sesión.',
        'MEDIO', 'ESCALAR'),
    ('UBICA_EMAIL_DISCREPANCIA',
        'Discrepancia entre email declarado y email UBICA',
        'El email ingresado por el cliente no coincide con el email en UBICA.',
        'MEDIO', 'ESCALAR'),
    ('DOCUMENTO_OCR_DISCREPANCIA',
        'Datos OCR no coinciden con datos declarados',
        'Los datos extraídos por OCR no coinciden con los datos declarados.',
        'MEDIO', 'ESCALAR');
    
    PRINT '✓ cat.CatalogoReglasFraude: 6 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cat.CatalogoReglasFraude: ya tiene datos, omitido';
END


-- ==============================================================================
-- 8. CatalogoMotivosEscalamiento (5 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cat].[CatalogoMotivosEscalamiento])
BEGIN
    INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
    ('OTP_FAIL_EMAIL_CHANGE',
        'Cambio de email tras fallo OTP — posible suplantación',
        'El cliente falló la validación OTP y a continuación intentó cambiar su email.',
        'FRAUDE'),
    ('OTP_INTENTOS_AGOTADOS',
        'Intentos OTP agotados sin validación exitosa',
        'Se consumieron todos los intentos permitidos de OTP.',
        'SISTEMA'),
    ('BIOMETRIA_MAX_REINTENTOS',
        'Biometría fallida — máximo de reintentos alcanzado',
        'La verificación biométrica falló el número máximo de veces.',
        'SISTEMA'),
    ('UBICA_GESTION_MANUAL_FABRICA',
        'UBICA indica gestión manual por fábrica',
        'El resultado de UBICA requiere revisión humana.',
        'SISTEMA'),
    ('ASESOR_RECHAZO_POR_FRAUDE',
        'Asesor rechazado por sospecha de fraude',
        'El asesor de fábrica rechazó el caso por sospecha de fraude.',
        'ASESOR');
    
    PRINT '✓ cat.CatalogoMotivosEscalamiento: 5 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cat.CatalogoMotivosEscalamiento: ya tiene datos, omitido';
END


-- ==============================================================================
-- 9. CatalogoTiposFotografia (3 registros)
-- ==============================================================================
IF NOT EXISTS (SELECT * FROM [cat].[CatalogoTiposFotografia])
BEGIN
    INSERT INTO [cat].[CatalogoTiposFotografia] (Codigo, Nombre, Descripcion, OrdenSecuencia) VALUES
    ('FOTO_FRONTAL_DOC', 'Foto frontal documento', 'Foto frontal del documento de identidad', 1),
    ('FOTO_TRASERA_DOC', 'Foto trasera documento', 'Foto trasera del documento de identidad', 2),
    ('SELFIE', 'Selfie con documento', 'Selfie sosteniendo el documento de identidad', 3);
    
    PRINT '✓ cat.CatalogoTiposFotografia: 3 registros insertados';
END
ELSE
BEGIN
    PRINT '○ cat.CatalogoTiposFotografia: ya tiene datos, omitido';
END


-- ==============================================================================
-- 10. Estados nuevos para fotografía (PH-08)
-- ==============================================================================
IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = 'PENDIENTE_FOTOS')
BEGIN
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('PENDIENTE_FOTOS', 'Pendiente Fotos', 'PROCESO', 0, 0, 'Esperando carga de fotografías del documento.'),
    ('FOTOS_EN_REVISION', 'Fotos en Revisión', 'PROCESO', 0, 0, 'Fotos en proceso de revisión manual.');
    
    PRINT '✓ Estados de fotografía insertados';
END


-- ==============================================================================
-- RESUMEN
-- ==============================================================================
PRINT '';
PRINT '============================================================';
PRINT '  SEMILLAS COMPLETADAS';
PRINT '============================================================';
PRINT '';
PRINT 'Total insertado por catálogo:';
PRINT '  cfg.FasesEstudio:               7';
PRINT '  cfg.ConfiguracionReglasNegocio: 8';
PRINT '  cfg.PasosEstudio:              13';
PRINT '  cfg.CatalogoEstados:          17';
PRINT '  cfg.TransicionesEstado:     ~17';
PRINT '  cat.CatalogoCanalesOrigen:    3';
PRINT '  cat.CatalogoReglasFraude:      6';
PRINT '  cat.CatalogoMotivosEscalamiento: 5';
PRINT '  cat.CatalogoTiposFotografia:   3';
PRINT '';
PRINT '✓ Seeds ejecutados correctamente';
PRINT '';
