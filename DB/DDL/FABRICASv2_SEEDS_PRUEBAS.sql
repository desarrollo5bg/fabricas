
-- ==============================================================================
-- SECCIÓN 10: DATOS SEMILLA (SEEDS) — Complete sync con FABRICASv2.sql
-- ==============================================================================

-- 10.1 FasesEstudio (7 fases)
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.FasesEstudio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[FasesEstudio])
    BEGIN
        INSERT INTO [cfg].[FasesEstudio] (Codigo, Nombre, OrdenEjecucion, Descripcion) VALUES
        ('IDENTIFICACION',        'Identificación del Cliente',      1, 'Ingreso de documento, validación de existencia, verificación de cupo activo/bloqueado'),
        ('DATOS_CLIENTE',         'Datos del Cliente',               2, 'Captura o actualización de datos personales y de contacto'),
        ('CONSENTIMIENTO_LEGAL',  'Consentimiento Legal',           3, 'Aceptación de términos, autorización de tratamiento de datos, tokenización'),
        ('VALIDACIONES_RIESGO',   'Validaciones de Riesgo',         4, 'Listas restrictivas, buró de crédito, Preselecta, FOSYGA'),
        ('LIMITE_CREDITO',        'Límite de Crédito',            5, 'Cálculo y presentación del cupo preaprobado'),
        ('VERIFICACION_IDENTIDAD','Verificación de Identidad',     6, 'Biometría facial, OCR de documento, prueba de vida'),
        ('CIERRE',               'Cierre del Estudio',            7, 'Confirmación, formalización del crédito');
    END
END


-- 10.2 Estados del Proceso (23 estados) — sync completo con v2.6
IF NOT EXISTS (SELECT 1 FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR')
BEGIN
    -- INICIAL
    INSERT INTO [cfg].[CatalogoEstados] (Codigo, Nombre, Grupo, EsTerminal, PermitePausa, Descripcion) VALUES
    ('BORRADOR', 'En Validación Previa', 'INICIAL', 0, 0, 'El cliente se encuentra en pasos iniciales.'),
    ('PENDIENTE_CLIENTE_PREVIO', 'Pendiente Cliente — Previo', 'INICIAL', 0, 1, 'Se requiere acción del cliente antes de crear solicitud formal.'),
    ('EXPIRADO_PREVIO', 'Expirada — Previo', 'INICIAL', 1, 0, 'El proceso previo no continuó dentro del tiempo permitido.'),
    ('CUPO_YA_ACTIVO', 'Cupo Ya Activo', 'BLOQUEO', 1, 0, 'El cliente ya cuenta con cupo disponible.'),
    ('NO_APLICA_MORA', 'No Aplica — Por Mora', 'BLOQUEO', 1, 0, 'No puede continuar por cartera en mora.'),
    -- REACTIVACION
    ('DESBLOQUEADO', 'Desbloqueado', 'REACTIVACION', 0, 0, 'Se rehabilitó un cupo bloqueado.'),
    ('REACTIVADO', 'Reactivado', 'REACTIVACION', 0, 0, 'Se reactiva un cupo eliminado previamente.'),
    -- PROCESO
    ('EN_PROGRESO', 'En Proceso', 'PROCESO', 0, 1, 'La solicitud avanza normalmente.'),
    ('PAUSADO', 'Pausado', 'PROCESO', 0, 0, 'El cliente se retiró; estudio en espera.'),
    ('PENDIENTE_CLIENTE', 'Pendiente Cliente', 'PROCESO', 0, 1, 'Se requiere acción del cliente.'),
    ('PENDIENTE_OTP', 'Pendiente Validación OTP', 'PROCESO', 0, 1, 'Esperando validación del token.'),
    ('PENDIENTE_BIOMETRIA', 'Pendiente Biometría', 'PROCESO', 0, 1, 'Esperando captura biométrica.'),
    ('PENDIENTE_FOTOS', 'Pendiente Envío de Fotos', 'PROCESO', 0, 1, 'Esperando fotos del cliente.'),
    ('FOTOS_EN_REVISION', 'Fotos en Revisión', 'PROCESO', 0, 0, 'Fotos en revisión manual.'),
    ('PENDIENTE_VALIDACION_AUTOMATICA', 'Pendiente Validación Automática', 'PROCESO', 0, 1, 'Esperando respuesta de motores externos.'),
    ('EN_FABRICA', 'En Fábrica de Soporte', 'PROCESO', 0, 0, 'Caso enviado a gestión manual.'),
    ('CUPO_PREAPROBADO', 'Cupo Preaprobado', 'PROCESO', 0, 1, 'Cupo calculado exitosamente.'),
    ('REVISION_FABRICA', 'En Revisión Manual — Fábrica', 'PROCESO', 0, 0, 'Derivado a revisión por fábrica.'),
    -- TERMINAL
    ('APROBADO', 'Cupo Activado', 'TERMINAL', 1, 0, 'Solicitud aprobada.'),
    ('RECHAZADO', 'Rechazado', 'TERMINAL', 1, 0, 'Solicitud rechazada.'),
    ('NO_VIABLE_ANTECEDENTES_PREVIO', 'No Viable — Antecedentes (Previo)', 'TERMINAL', 1, 0, 'Rechazo en validaciones previas.'),
    ('NO_VIABLE_ANTECEDENTES', 'No Viable — Antecedentes', 'TERMINAL', 1, 0, 'Rechazo por antecedentes.'),
    ('NO_VIABLE_CENTRALES', 'No Viable — Centrales', 'TERMINAL', 1, 0, 'Rechazo por modelo de viabilidad.'),
    ('NO_APLICA_CUPO', 'No Aplica — Para Cupo', 'TERMINAL', 1, 0, 'No supera reglas complementarias.'),
    ('BLOQUEADO_FRAUDE', 'Bloqueado por Sospecha de Fraude', 'TERMINAL', 1, 0, 'Bloqueado por patrón de fraude.'),
    ('EXPIRADO', 'Expirada', 'TERMINAL', 1, 0, 'No retomó dentro del tiempo.'),
    ('CANCELADO_CLIENTE', 'Cancelada por Cliente', 'TERMINAL', 1, 0, 'El cliente desistió.');


END


-- 10.3 PasosEstudio (13 pasos)
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.PasosEstudio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[PasosEstudio])
    BEGIN
        INSERT INTO [cfg].[PasosEstudio] (IdFase, Codigo, Nombre, OrdenEnFase, OrdenGlobal, Actor, ServicioExterno, EsAutomatico, RequiereIntervencion, TiempoTimeoutSeg, Descripcion) VALUES
    (1, 'INGRESO_DOCUMENTO',       'Ingreso de Documento',              1, 1,  'ASESOR',    NULL,                0, 0, NULL,  'El asesor digita el número de documento'),
    (1, 'VALIDAR_EXISTENCIA',     'Validar Existencia del Cliente',    2, 2,  'SISTEMA',  'ERP_QUAC',           1, 0, 30,   'Verifica si el cliente existe'),
    (1, 'VALIDAR_CUPO_BLOQUEO', 'Validar Cupo Activo / Bloqueo',    3, 3,  'SISTEMA',  'CORE_CREDITO',        1, 0, 30,   'Verifica cupo activo, bloqueos'),
    (2, 'CAPTURA_DATOS',         'Captura de Datos Personales',        1, 4,  'ASESOR',    NULL,                0, 0, NULL,  'Captura de datos personales'),
    (3, 'CONSENTIMIENTO_DATOS',  'Autorización Tratamiento Datos',  1, 5,  'CLIENTE',  NULL,                0, 0, NULL,  'Aceptación de términos'),
    (3, 'TOKENIZACION',          'Envío y Validación de Token OTP',  2, 6,  'SISTEMA',  'OTP_PROVIDER',        1, 0, 120,  'Envío y validación de OTP'),
    (4, 'VALIDAR_LISTAS',        'Validar Listas Restrictivas',           1, 7,  'SISTEMA',  'LISTAS_RESTRICTIVAS', 1, 0, 30,   'Consulta listas restrictivas'),
    (4, 'CONSULTAR_BURO',       'Consultar Buró de Crédito',        2, 8,  'SISTEMA',  'BURO_CREDITO',        1, 0, 60,   'Consulta historial crediticio'),
    (4, 'EVALUAR_PRESELECTA',   'Evaluación Preselecta',          3, 9,  'SISTEMA',  'PRESELECTA',         1, 0, 60,   'Motor de decisión Preselecta'),
    (4, 'VALIDAR_FOSYGA',       'Validar FOSYGA / ADRES',         4, 10, 'SISTEMA',  'FOSYGA',             1, 0, 30,   'Verificación seguridad social'),
    (5, 'CALCULAR_CUPO',        'Cálculo del Cupo Preaprobado',   1, 11, 'SISTEMA',  'MOTOR_CUPO',         1, 0, 30,   'Cálculo del límite de crédito'),
    (6, 'VERIFICACION_BIOMETRICA','Verificación Biométrica',         1, 12, 'SISTEMA',  'BIOMETRIA',          1, 1, 120,  'Captura y verificación biométrica'),
    (7, 'ACTIVACION_CUPO',        'Activación del Cupo',             1, 13, 'SISTEMA',  'UBICA',              1, 1, 60,   'Validación UBICA y activación');

    END
END



-- 10.4 TransicionesEstado (idempotente por fila — se pueden agregar transiciones sin borrar las existentes)

-- Transiciones desde BORRADOR
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Iniciar procesamiento del estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria antes de iniciar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'CANCELADO_CLIENTE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'PENDIENTE_CLIENTE_PREVIO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retracta en validación previa'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'BORRADOR' AND d.Codigo = 'PENDIENTE_CLIENTE_PREVIO';

-- Transiciones desde PENDIENTE_CLIENTE_PREVIO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'BORRADOR')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente completa datos pendientes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'BORRADOR';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria en previo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_CLIENTE_PREVIO' AND d.Codigo = 'CANCELADO_CLIENTE';

-- Transiciones desde EN_PROGRESO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_OTP')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando validación OTP'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_OTP';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_BIOMETRIA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando biométrica'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_BIOMETRIA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_FOTOS')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando fotos del cliente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_FOTOS';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Esperando respuesta de servicio externo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CUPO_PREAPROBADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cupo preaprobado confirmado'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CUPO_PREAPROBADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'APROBADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Todas las validaciones aprobadas'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'APROBADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazado por validación de riesgo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazo por antecedentes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_CENTRALES')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Rechazo por centrales/preselecta'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_CENTRALES';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_APLICA_CUPO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'No aplica para cupo: no supera reglas complementarias'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_APLICA_CUPO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Derivar a fábrica de soporte'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'EN_FABRICA';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Regla de fraude crítica: bloqueo automático inmediato'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'BLOQUEADO_FRAUDE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria durante el proceso'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'CANCELADO_CLIENTE';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Preselecta rechaza por antecedentes'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'NO_VIABLE_ANTECEDENTES_PREVIO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'REVISION_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Anomalía detectada: derivar a revisión manual por fábrica de crédito'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_PROGRESO' AND d.Codigo = 'REVISION_FABRICA';

-- Transiciones desde PAUSADO
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente regresa, reanudar estudio'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EXPIRADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Estudio expiró por inactividad'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'EXPIRADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'CANCELADO_CLIENTE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cancelación voluntaria mientras pausado'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PAUSADO' AND d.Codigo = 'CANCELADO_CLIENTE';

-- Transiciones desde PENDIENTE_OTP
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'OTP validado exitosamente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'OTP fallido, intentos agotados'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_OTP' AND d.Codigo = 'RECHAZADO';

-- Transiciones desde PENDIENTE_BIOMETRIA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Biometría validada exitosamente'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'PAUSADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Cliente se retira, pausar'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'PAUSADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Biometría fallida, derivar a fábrica'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_BIOMETRIA' AND d.Codigo = 'EN_FABRICA';

-- Transiciones desde PENDIENTE_FOTOS
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_FOTOS' AND d.Codigo = 'FOTOS_EN_REVISION')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Fotos recibidas, en revisión'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_FOTOS' AND d.Codigo = 'FOTOS_EN_REVISION';

-- Transiciones desde FOTOS_EN_REVISION
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Asesor aprueba fotos: proceso se reanuda'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'PENDIENTE_FOTOS')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor rechaza fotos: nueva solicitud'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'FOTOS_EN_REVISION' AND d.Codigo = 'PENDIENTE_FOTOS';

-- Transiciones desde EN_FABRICA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Fábrica resuelve: reanudar flujo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Fábrica determina rechazo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Fábrica detecta fraude'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'EN_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE';

-- Transiciones desde PENDIENTE_VALIDACION_AUTOMATICA
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 0, 'Validación automática exitosa'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_FABRICA')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Validación automática fallida'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'PENDIENTE_VALIDACION_AUTOMATICA' AND d.Codigo = 'EN_FABRICA';

-- Transiciones desde REVISION_FABRICA (SA-11)
IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'EN_PROGRESO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica resuelve: devolver al flujo automático'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'EN_PROGRESO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'RECHAZADO')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica determina rechazo definitivo'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'RECHAZADO';

IF NOT EXISTS (SELECT 1 FROM [cfg].[TransicionesEstado] t INNER JOIN [cfg].[CatalogoEstados] o ON o.IdEstado = t.IdEstadoOrigen INNER JOIN [cfg].[CatalogoEstados] d ON d.IdEstado = t.IdEstadoDestino WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE')
    INSERT INTO [cfg].[TransicionesEstado] (IdEstadoOrigen, IdEstadoDestino, RequiereMotivo, Descripcion)
    SELECT o.IdEstado, d.IdEstado, 1, 'Asesor de fábrica confirma sospecha de fraude'
    FROM [cfg].[CatalogoEstados] o, [cfg].[CatalogoEstados] d WHERE o.Codigo = 'REVISION_FABRICA' AND d.Codigo = 'BLOQUEADO_FRAUDE';


-- 10.5 ConfiguracionReglasNegocio
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cfg.ConfiguracionReglasNegocio', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cfg].[ConfiguracionReglasNegocio])
    BEGIN
        INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_ENFRIAMIENTO',       'Días de Enfriamiento por Rechazo',       '90',    'INT', 'ENFRIAMIENTO', 'Días que un rechazado debe esperar'),
    ('DIAS_EXPIRACION_ESTUDIO', 'Días de Expiración del Estudio',        '90',    'INT', 'GENERAL',      'Días de inactividad antes de expirar'),
    ('INTENTOS_OTP_MAX',        'Intentos Máximos de OTP',               '3',     'INT', 'OTP',          'Número máximo de intentos OTP'),
    ('VIGENCIA_OTP_SEG',       'Vigencia del Token OTP (segundos)',    '300',   'INT', 'OTP',          'Tiempo de vida del token OTP'),
    ('BLOQUEO_OTP_HORAS',      'Horas de Bloqueo por OTP Fallidos',   '24',    'INT', 'OTP',          'Horas de bloqueo tras intentos fallidos'),
    ('INTENTOS_BIOMETRIA_MAX',  'Intentos Máximos de Biometría',      '3',     'INT', 'BIOMETRIA',    'Número máximo de intentos biométricos'),
    ('UMBRAL_MATCH_FACIAL',     'Umbral de Coincidencia Facial (%)',      '85.00','DECIMAL','BIOMETRIA',    'Porcentaje mínimo de coincidencia'),
    ('VENTANA_FRAUDE_OTP_MIN',  'Ventana de tiempo fraude post-OTP',    '10',    'INT', 'RIESGO',       'Minutos después de fallo OTP para regla fraude'),
    ('MAX_ESTUDIOS_POR_IP_HORA','Máximo estudios por IP por hora',     '3',     'INT', 'RIESGO',       'Máximo estudios simultáneos por IP'),
    ('SLA_REVISION_FABRICA_HORAS','SLA revisión fábrica (horas)', '24',    'INT', 'RIESGO',       'Tiempo máximo para resolver escalamiento'),
    ('REENVIOS_OTP_MAX',      'Máximo reenvíos OTP permitidos',    '2',     'INT',          'OTP',          'Reenvíos sin cancelar reto');


END

-- Parámetros adicionales (idempotentes por código)
IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'DIAS_CANCELACION_REACTIV')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('DIAS_CANCELACION_REACTIV', 'Días Desde Cancelación para Reactivación', '365', 'INT', 'GENERAL', 'Días desde cancelación para reactivación');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_REACTIVACION_CUPO_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_REACTIVACION_CUPO_DIAS', 'Ventana de eliminación para reactivación (días)', '30', 'INT', 'RIESGO', 'Días permitidos para evaluar reactivación de un cupo tras haber sido eliminado por el cliente');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_COMPRAS_RECIENTES_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_COMPRAS_RECIENTES_DIAS', 'Ventana compras recientes ruta simplificada (días)', '60', 'INT', 'RIESGO', 'Validar si el cliente realizó compras en los últimos X días para habilitar validación abreviada');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VENTANA_ACTUALIZACION_DATOS_DIAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VENTANA_ACTUALIZACION_DATOS_DIAS', 'Ventana actualización datos ruta simplificada (días)', '90', 'INT', 'RIESGO', 'Días transcurridos sin cambios de correo y dirección para habilitar validación abreviada');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'VIGENCIA_LINK_RECARGA_HORAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('VIGENCIA_LINK_RECARGA_HORAS', 'Vigencia del link de re-carga de fotografías (horas)', '48', 'INT', 'FOTOS', 'Número de horas que tiene el cliente para usar el link de re-carga antes de que expire');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'MAX_REINTENTOS_RECARGA_FOTO')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('MAX_REINTENTOS_RECARGA_FOTO', 'Máximo de solicitudes de re-carga por foto por estudio', '3', 'INT', 'FOTOS', 'Número máximo de veces que se puede solicitar re-carga de la misma foto en el mismo estudio');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'MAX_VERSIONES_FOTO')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('MAX_VERSIONES_FOTO', 'Máximo de versiones por fotografía por estudio', '4', 'INT', 'FOTOS', 'Número máximo de veces que el cliente puede re-subir la misma foto. Incluye la subida original');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'FOTOS_OBLIGATORIAS_REQUERIDAS')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('FOTOS_OBLIGATORIAS_REQUERIDAS', 'Número de fotografías obligatorias requeridas para aprobación', '3', 'INT', 'FOTOS', 'Cantidad de fotos que deben estar en estado APROBADA para que el gate de aprobación sea superado');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'CANAL_DEFECTO_RECARGA')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('CANAL_DEFECTO_RECARGA', 'Canal de envío por defecto para links de re-carga', 'WHATSAPP', 'TEXT', 'FOTOS', 'Canal preferido para enviar el link de re-carga al cliente. Valores: EMAIL, SMS, WHATSAPP');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'ALERTA_FOTO_RECHAZADA_VECES')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('ALERTA_FOTO_RECHAZADA_VECES', 'Número de rechazos de una misma foto que activan alerta de fraude', '2', 'INT', 'FOTOS', 'Si la misma foto es rechazada este número de veces consecutivas, se activa una alerta de fraude');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'JWT_ORIGEN_WEB')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('JWT_ORIGEN_WEB', 'Valor del claim ''origen'' en el JWT para el canal de autoservicio web', 'LoginWeb', 'TEXT', 'AUTH', 'Identificador de origen que se incluye en el JWT emitido para sesiones del portal web de autoservicio');

IF NOT EXISTS (SELECT 1 FROM [cfg].[ConfiguracionReglasNegocio] WHERE Codigo = 'JWT_ORIGEN_TIENDA')
    INSERT INTO [cfg].[ConfiguracionReglasNegocio] (Codigo, Nombre, Valor, TipoDato, Categoria, Descripcion) VALUES
    ('JWT_ORIGEN_TIENDA', 'Valor del claim ''origen'' en el JWT para el canal de tienda asistida', 'LoginTienda', 'TEXT', 'AUTH', 'Identificador de origen incluido en el JWT emitido para sesiones iniciadas por el asesor en tienda');

END


-- 10.6 CatalogoCanalesOrigen
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoCanalesOrigen', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoCanalesOrigen])
    BEGIN
        INSERT INTO [cat].[CatalogoCanalesOrigen] (Codigo, Nombre, Descripcion, Activo) VALUES
        ('WEB',     'Canal Web',     'Originación a través del portal web o app',        1),
        ('TIENDA',  'Canal Tienda','Originación presencial en punto de venta',         1),
        ('EXTERNO', 'Canal Externo','Originación por fuerza de ventas externas',        1);
    END
END


-- 10.7 CatalogoReglasFraude
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoReglasFraude', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoReglasFraude])
    BEGIN
        INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('EMAIL_CHANGE_POST_OTP_FAIL', 'Cambio de email después de fallo OTP',
        'El cliente intenta cambiar su email después de fallar OTP. Patrón típico de suplantación.',
        'ALTO', 'ESCALAR'),
    ('CEL_CHANGE_POST_OTP_FAIL', 'Cambio de celular después de fallo OTP',
        'El cliente intenta cambiar su número después de fallar OTP.',
        'ALTO', 'ESCALAR'),
    ('CONTACTO_CHANGE_DURANTE_RETO_ACTIVO', 'Cambio dato contacto con reto activo',
        'Intento de modificar datos mientras hay token OTP vigente.',
        'CRITICO', 'BLOQUEAR'),
    ('MULTIPLES_FALLOS_OTP_MISMA_SESION', 'Múltiples fallos OTP misma sesión',
        'Se agotaron los intentos máximos de OTP en una misma sesión.',
        'MEDIO', 'ESCALAR'),
    ('UBICA_EMAIL_DISCREPANCIA', 'Discrepancia email declarado vs UBICA',
        'El email declarada no coincide con el de UBICA.',
        'MEDIO', 'ESCALAR'),
    ('REINTENTO_RAPIDO_OTRO_EMAIL', 'Reintento rápido con otro email',
        'Solicita nuevo OTP a dirección diferente en poco tiempo.',
        'ALTO', 'ESCALAR'),
    ('IP_MULTIPLES_ESTUDIOS', 'Misma IP en múltiples estudios',
        'La misma IP para varios clientes en período corto.',
        'CRITICO', 'BLOQUEAR'),
    ('DOCUMENTO_OCR_DISCREPANCIA', 'OCR no coincide con datos declarados',
        'Datos extraídos del documento no coinciden con declarados.',
        'MEDIO', 'ESCALAR');


END

-- Reglas de fraude adicionales: DUPLICIDAD y módulo fotográfico (idempotentes por código)
IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'DUPLICIDAD_EMAIL')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('DUPLICIDAD_EMAIL', 'Email Duplicado', 'El correo electrónico ya se encuentra registrado con otro tercero.', 'MEDIO', 'NOTIFICAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'DUPLICIDAD_CELULAR')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('DUPLICIDAD_CELULAR', 'Celular Duplicado', 'El número de celular ya se encuentra registrado con otro tercero.', 'ALTO', 'BLOQUEAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'FOTO_RECHAZADA_MULTIPLE_VECES')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('FOTO_RECHAZADA_MULTIPLE_VECES', 'Fotografía rechazada múltiples veces consecutivas',
     'La misma fotografía fue rechazada en dos o más revisiones consecutivas. Puede indicar intento de usar documentos falsificados.',
     'MEDIO', 'ESCALAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'MAX_VERSIONES_FOTO_SUPERADO')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('MAX_VERSIONES_FOTO_SUPERADO', 'Se superó el máximo de versiones de foto permitidas',
     'El cliente ha intentado subir la misma foto más veces del límite configurado.',
     'ALTO', 'ESCALAR');

IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'FOTO_DUPLICADA_OTRO_ESTUDIO')
    INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
    ('FOTO_DUPLICADA_OTRO_ESTUDIO', 'Fotografía idéntica usada en otro estudio de crédito',
     'El hash del archivo de la foto es idéntico al de una foto en otro estudio activo. Posible reutilización fraudulenta.',
     'CRITICO', 'BLOQUEAR');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoReglasFraude] WHERE Codigo = 'SELFIE_NO_COINCIDE_DOCUMENTO')
        INSERT INTO [cat].[CatalogoReglasFraude] (Codigo, Nombre, Descripcion, NivelRiesgo, AccionAutomatica) VALUES
        ('SELFIE_NO_COINCIDE_DOCUMENTO', 'Selfie no coincide con fotografía del documento según Rekognition',
         'El porcentaje de coincidencia facial entre la selfie y la foto del documento es menor al umbral configurado (UMBRAL_MATCH_FACIAL).',
         'ALTO', 'ESCALAR');

END


-- 10.8 CatalogoMotivosEscalamiento
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoMotivosEscalamiento', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoMotivosEscalamiento])
    BEGIN
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
    ('OTP_FAIL_EMAIL_CHANGE', 'Cambio email tras fallo OTP', 'Falló OTP y cambió email.', 'FRAUDE'),
    ('OTP_INTENTOS_AGOTADOS', 'Intentos OTP agotados', 'Sin validación exitosa.', 'SISTEMA'),
    ('BIOMETRIA_MAX_REINTENTOS', 'Biometría máximos reintentos', 'Reintentos biométricos agotados.', 'SISTEMA'),
    ('UBICA_GESTION_MANUAL_FABRICA', 'Gestión manual UBICA', 'Resultado UBICA requiere revisión.', 'SISTEMA'),
    ('ALERTA_FRAUDE_CRITICA', 'Alerta fraude nivel crítico', 'Regla de fraude CRÍTICO.', 'FRAUDE'),
    ('DISCREPANCIA_DATOS_UBICA', 'Discrepancia datos UBICA', 'Datos no coinciden con UBICA.', 'SISTEMA'),
    ('ESCALAMIENTO_MANUAL_ASESOR', 'Escalamiento manual', 'Asesor escala manualmente.', 'ASESOR'),
    ('DATO_CONTACTO_MODIFICADO_EN_FLUJO', 'Dato modificado en flujo', 'Modificó dato durante originación.', 'FRAUDE');


END

    -- Motivos de escalamiento fotográfico (idempotentes por código)
    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'FOTO_MAX_REINTENTOS_SUPERADO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('FOTO_MAX_REINTENTOS_SUPERADO', 'Máximo de re-cargas de fotografía superado',
         'El cliente superó el número máximo de intentos de re-carga para una foto. Requiere revisión manual del asesor.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'FOTO_RECHAZADA_VARIAS_VECES')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('FOTO_RECHAZADA_VARIAS_VECES', 'Fotografía rechazada en múltiples revisiones',
         'La misma fotografía fue rechazada por el asesor en dos o más revisiones. Se escala para que un supervisor decida.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'LINK_RECARGA_EXPIRADO_SIN_USO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('LINK_RECARGA_EXPIRADO_SIN_USO', 'Link de re-carga expirado sin uso',
         'El link de re-carga de fotografía expiró sin que el cliente	subiera la foto.',
         'SISTEMA');

    IF NOT EXISTS (SELECT 1 FROM [cat].[CatalogoMotivosEscalamiento] WHERE Codigo = 'SELFIE_BIOMETRIA_FALLO')
        INSERT INTO [cat].[CatalogoMotivosEscalamiento] (Codigo, Nombre, Descripcion, Origen) VALUES
        ('SELFIE_BIOMETRIA_FALLO', 'Falló verificación biométrica de selfie',
         'La verificación biométrica de la selfie (Rekognition) falló más de N intentos.',
         'SISTEMA');

END


-- 10.9 CatalogoTiposFotografia
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'cat.CatalogoTiposFotografia', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [cat].[CatalogoTiposFotografia] WHERE Codigo = 'FOTO_FRONTAL_DOC')
    BEGIN
        INSERT INTO [cat].[CatalogoTiposFotografia] (Codigo, Nombre, Descripcion, EsObligatoria, OrdenRevision, ServicioAWS)
    VALUES
    (
        'FOTO_FRONTAL_DOC',
        'Foto Frontal de Cédula de Ciudadanía',
        'Fotografía del lado frontal de la cédula. Usada por OCR y Rekognition CompareFaces.',
        1, 1, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'FOTO_TRASERA_DOC',
        'Foto Reverso de Cédula de Ciudadanía',
        'Fotografía del reverso de la cédula. Usada por OCR para extracción de datos complementarios.',
        1, 2, 'REKOGNITION_DETECT_LABELS'
    ),
    (
        'SELFIE',
        'Selfie del Titular',
        'Foto del rostro del cliente (prueba de vida). Usada por Rekognition DetectFaces y CompareFaces.',
        1, 3, 'REKOGNITION_DETECT_FACES'
    );

    END
END


-- 10.10 OperadoresFabrica — Seed de prueba
-- Guard con OBJECT_ID para evitar error de compilación cuando la tabla no existe aún
IF OBJECT_ID(N'fab.OperadoresFabrica', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT * FROM [fab].[OperadoresFabrica])
    BEGIN
        INSERT INTO [fab].[OperadoresFabrica] (NitOperador, NombreOperador, CorreoOperador, TelefonoOperador, TipoOperador, Activo) VALUES
        ('12345678', 'Juan Pérez Asesor', 'juan.perez@quac.com', '3001234567', 'ASESOR', 1),
         ('87654321', 'María Supervisora', 'maria.supervisor@quac.com', '3007654321', 'SUPERVISOR', 1),
         ('11223344', 'Carlos Revisor Fotos', 'carlos.revisor@quac.com', '3001122334', 'REVISOR_FOTOS', 1);
    END
END


-- ==============================================================================
-- SECCIÓN 10: PARCHES V2.8 — CENTRALES DE RIESGO
-- ==============================================================================
-- Identifica qué central de riesgo se usa por tipo de servicio. Permite cambiar
-- la combinación Datacredito/CIFIN sin tocar código (solo configuración).
--
--   CR-01: Nueva tabla cfg.CentralesRiesgoCfg
--   CR-02: ALTER fab.EvaluacionesRiesgo — columnas CentralConsultada, IdLogCentralExterno
--   CR-03: Seeds iniciales cfg.CentralesRiesgoCfg
--   CR-04: CHECK ampliado CK_EvaluacionesRiesgo_Tipo
-- ==============================================================================


-- CR-01: cfg.CentralesRiesgoCfg
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'cfg.CentralesRiesgoCfg') AND type = 'U')
BEGIN
    CREATE TABLE [cfg].[CentralesRiesgoCfg] (
        IdConfig            INT IDENTITY(1,1)   NOT NULL,
        TipoServicio        VARCHAR(30)         NOT NULL,   -- VIABILIDAD | CONTACTABILIDAD
        CentralActiva       VARCHAR(30)         NOT NULL,   -- DATACREDITO | CIFIN | COMBINADO
        NombreServicio      VARCHAR(50)         NOT NULL,   -- PRESELECTA | VARIABLES_ADVISER | RECONOCER | UBICA | COMBINADO_*
        TablaLogExterna     VARCHAR(100)        NOT NULL,   -- ej: dbo.BERP_FABRICASDatacredito_PreselectaDesicion
        Canal               VARCHAR(20)         NULL,       -- TIENDA | WEB | NULL (todos)
        Activa              BIT                 NOT NULL DEFAULT 1,
        FechaVigencia       DATE                NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        Observaciones       NVARCHAR(500)       NULL,
        FechaCreacion       DATETIME2(3)        NOT NULL DEFAULT GETDATE(),
        FechaActualizacion  DATETIME2(3)        NOT NULL DEFAULT GETDATE(),

        CONSTRAINT PK_CentralesRiesgoCfg PRIMARY KEY (IdConfig),
        CONSTRAINT CK_CentralesRiesgoCfg_TipoServicio CHECK (
            TipoServicio IN ('VIABILIDAD','CONTACTABILIDAD')
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Central CHECK (
            CentralActiva IN ('DATACREDITO','CIFIN','COMBINADO')
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Servicio CHECK (
            NombreServicio IN (
                'PRESELECTA',
                'VARIABLES_ADVISER',
                'RECONOCER',
                'UBICA',
                'COMBINADO_VIABILIDAD',
                'COMBINADO_CONTACTABILIDAD'
            )
        ),
        CONSTRAINT CK_CentralesRiesgoCfg_Canal CHECK (
            Canal IS NULL OR Canal IN ('TIENDA','WEB','HANDOFF')
        )
    );

    CREATE NONCLUSTERED INDEX IX_CentralesRiesgoCfg_Tipo
        ON [cfg].[CentralesRiesgoCfg] (TipoServicio, Activa);


END


-- CR-02: ALTER fab.EvaluacionesRiesgo — añade columnas de central consultada
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'CentralConsultada')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CentralConsultada   VARCHAR(30) NULL;   -- DATACREDITO | CIFIN | COMBINADO

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExterno')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExterno BIGINT NULL;

END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IdLogCentralExternoSecundaria')
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD IdLogCentralExternoSecundaria BIGINT NULL;

END

IF NOT EXISTS (
    SELECT * FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo')
    AND name = 'CK_EvaluacionesRiesgo_Central'
)
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CONSTRAINT CK_EvaluacionesRiesgo_Central CHECK (
            CentralConsultada IS NULL OR
            CentralConsultada IN ('DATACREDITO','CIFIN','COMBINADO')
        );

END

-- CR-04: Ampliar CHECK TipoEvaluacion para incluir tipos combinados
IF EXISTS (
    SELECT * FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo')
    AND name = 'CK_EvaluacionesRiesgo_Tipo'
)
BEGIN
    ALTER TABLE [fab].[EvaluacionesRiesgo] DROP CONSTRAINT CK_EvaluacionesRiesgo_Tipo;
    ALTER TABLE [fab].[EvaluacionesRiesgo]
        ADD CONSTRAINT CK_EvaluacionesRiesgo_Tipo CHECK (
            TipoEvaluacion IN (
                'LISTAS',
                'BURO',
                'PRESELECTA',
                'VARIABLES_ADVISER',
                'FOSYGA',
                'ANTECEDENTES',
                'RECONOCER',
                'UBICA',
                'VIABILIDAD_COMBINADA',
                'CONTACTABILIDAD_COMBINADA'
            )
        );

END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'fab.EvaluacionesRiesgo') AND name = 'IX_EvaluacionesRiesgo_Central')
BEGIN
    CREATE NONCLUSTERED INDEX IX_EvaluacionesRiesgo_Central
        ON [fab].[EvaluacionesRiesgo] (CentralConsultada, TipoEvaluacion)
        WHERE CentralConsultada IS NOT NULL;

END


-- CR-03: Seeds cfg.CentralesRiesgoCfg
IF NOT EXISTS (SELECT 1 FROM [cfg].[CentralesRiesgoCfg] WHERE TipoServicio = 'VIABILIDAD' AND CentralActiva = 'DATACREDITO')
BEGIN
    INSERT INTO [cfg].[CentralesRiesgoCfg]
        (TipoServicio, CentralActiva, NombreServicio, TablaLogExterna, Canal, Activa, Observaciones)
    VALUES
        ('VIABILIDAD',       'DATACREDITO', 'PRESELECTA',       'dbo.BERP_FABRICASDatacredito_PreselectaDesicion', NULL, 1, 'Preselecta Datacredito — viabilidad por defecto'),
        ('VIABILIDAD',       'CIFIN',       'VARIABLES_ADVISER', 'dbo.BERP_FABRICASCifinAdviserLog',                NULL, 0, 'VariablesAdviser CIFIN — alternativa a Preselecta'),
        ('CONTACTABILIDAD',  'CIFIN',       'UBICA',             'dbo.BERP_FABRICASCifinUbicaLog',                  NULL, 1, 'UBICA CIFIN — contactabilidad por defecto'),
        ('CONTACTABILIDAD',  'DATACREDITO', 'RECONOCER',         'dbo.BERP_CUPOAprobacion_Reconocer_Log',           NULL, 0, 'Reconocer Datacredito — alternativa a UBICA');

END


-- ==============================================================================
-- ══════════════════════════════════════════════════════════════════════════════
-- SECCIÓN 11: SEEDS TRANSACCIONALES PARA PRUEBAS DE API
-- ══════════════════════════════════════════════════════════════════════════════
-- Escenarios cubiertos:
--   Cliente A (10000001) — Nuevo sin historial          → Estudio BORRADOR
--   Cliente B (10000002) — Con cupo activo (aprobado)   → Estudio APROBADO + crédito KCRM
--   Cliente C (10000003) — Bloqueado (mora detectada)   → Estudio RECHAZADO
--   Cliente D (10000004) — En progreso (OTP pendiente)  → Estudio EN_PROGRESO
--   Cliente E (10000005) — En revisión fábrica          → Estudio REVISION_FABRICA
-- ==============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.1  dbo.terceros — 5 clientes ficticios de prueba
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'dbo.terceros', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[terceros] WHERE nit = '10000001')
        INSERT INTO [dbo].[terceros] (nit, nombres, direccion, telefono_1, mail, celular, fecha_creacion, fecha_modificacion)
        VALUES ('10000001', 'Ana García López',      'Calle 10 # 20-30, Bogotá',     '6011234567', 'ana.garcia@prueba.co',      '3001234567', GETDATE(), GETDATE());

    IF NOT EXISTS (SELECT 1 FROM [dbo].[terceros] WHERE nit = '10000002')
        INSERT INTO [dbo].[terceros] (nit, nombres, direccion, telefono_1, mail, celular, fecha_creacion, fecha_modificacion)
        VALUES ('10000002', 'Carlos Ramírez Torres', 'Carrera 7 # 45-12, Bogotá',    '6012345678', 'carlos.ramirez@prueba.co',  '3112345678', GETDATE(), GETDATE());

    IF NOT EXISTS (SELECT 1 FROM [dbo].[terceros] WHERE nit = '10000003')
        INSERT INTO [dbo].[terceros] (nit, nombres, direccion, telefono_1, mail, celular, fecha_creacion, fecha_modificacion)
        VALUES ('10000003', 'Laura Mendoza Ríos',    'Avenida 30 # 15-60, Medellín', '6041234567', 'laura.mendoza@prueba.co',   '3201234567', GETDATE(), GETDATE());

    IF NOT EXISTS (SELECT 1 FROM [dbo].[terceros] WHERE nit = '10000004')
        INSERT INTO [dbo].[terceros] (nit, nombres, direccion, telefono_1, mail, celular, fecha_creacion, fecha_modificacion)
        VALUES ('10000004', 'Pedro Vargas Nieto',    'Diagonal 22 # 8-40, Cali',     '6021234567', 'pedro.vargas@prueba.co',    '3151234567', GETDATE(), GETDATE());

    IF NOT EXISTS (SELECT 1 FROM [dbo].[terceros] WHERE nit = '10000005')
        INSERT INTO [dbo].[terceros] (nit, nombres, direccion, telefono_1, mail, celular, fecha_creacion, fecha_modificacion)
        VALUES ('10000005', 'María Fernández Cruz',  'Calle 80 # 50-25, Bogotá',     '6013456789', 'maria.fernandez@prueba.co', '3181234567', GETDATE(), GETDATE());

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.2  dbo.bodegas — 3 puntos de venta de prueba (bodega 9001–9003)
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'dbo.bodegas', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[bodegas] WHERE bodega = 9001)
        INSERT INTO [dbo].[bodegas] (bodega, descripcion, direccion, telefono, centro, TipoTienda, Nit_Comercio, ciudad, departamento, pais)
        VALUES (9001, 'Bogotá Centro TEST',    'Carrera 7 # 32-00', '6011234567', 0, 'TIENDA_FISICA', '800123456', 'BOG', 'CUN', 'COL');

    IF NOT EXISTS (SELECT 1 FROM [dbo].[bodegas] WHERE bodega = 9002)
        INSERT INTO [dbo].[bodegas] (bodega, descripcion, direccion, telefono, centro, TipoTienda, Nit_Comercio, ciudad, departamento, pais)
        VALUES (9002, 'Medellín Poblado TEST', 'Calle 10 # 43-10', '6041234567', 0, 'TIENDA_FISICA', '800123456', 'MED', 'ANT', 'COL');

    IF NOT EXISTS (SELECT 1 FROM [dbo].[bodegas] WHERE bodega = 9003)
        INSERT INTO [dbo].[bodegas] (bodega, descripcion, direccion, telefono, centro, TipoTienda, Nit_Comercio, ciudad, departamento, pais)
        VALUES (9003, 'Canal Web TEST',        NULL,               NULL,         0, 'VIRTUAL',       '800123456', NULL,  NULL,  'COL');

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.3  dbo.KCRM_CadenaCreditos — créditos activos para clientes B y E
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'dbo.KCRM_CadenaCreditos', N'U') IS NOT NULL
AND OBJECT_ID(N'dbo.bodegas', N'U') IS NOT NULL
BEGIN
    -- Cliente B: cupo activo vigente (aprobado hace 3 meses)
    IF NOT EXISTS (SELECT 1 FROM [dbo].[KCRM_CadenaCreditos] WHERE Nit = '10000002' AND Activa = 1)
        INSERT INTO [dbo].[KCRM_CadenaCreditos]
            (Nit, FechaIngreso, Aprobado, Bodega, CupoAprobado, Activa, EstadoActualFabricas, MotivoBloqueoFabricas, ElegibleReactivacion)
        SELECT '10000002', DATEADD(MONTH, -3, GETDATE()), 1,
               (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9001),
               2000000, 1, 'ACTIVO', NULL, 0;

    -- Cliente E: recién aprobado, pendiente activación
    IF NOT EXISTS (SELECT 1 FROM [dbo].[KCRM_CadenaCreditos] WHERE Nit = '10000005')
        INSERT INTO [dbo].[KCRM_CadenaCreditos]
            (Nit, FechaIngreso, Aprobado, Bodega, CupoAprobado, Activa, EstadoActualFabricas, MotivoBloqueoFabricas, ElegibleReactivacion)
        SELECT '10000005', GETDATE(), 1,
               (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9002),
               1500000, 0, 'PENDIENTE_ACTIVACION', NULL, 0;

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.4  fab.TercerosFabricas — perfil Fábricas de los 5 clientes
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'fab.TercerosFabricas', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = '10000001')
        INSERT INTO [fab].[TercerosFabricas]
            (NitTercero, NombreTercero, EstadoTercero, TieneCupoActivo, EstaBloqueadoFabricas, CelularPrincipal, CelularWhatsApp)
        VALUES ('10000001', 'Ana García López',      'ACTIVO',   0, 0, '3001234567', '3001234567');

    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = '10000002')
        INSERT INTO [fab].[TercerosFabricas]
            (NitTercero, NombreTercero, EstadoTercero, TieneCupoActivo, EstaBloqueadoFabricas, PuntajeCredito, FechaUltimaEvaluacion, CelularPrincipal, CelularWhatsApp)
        VALUES ('10000002', 'Carlos Ramírez Torres', 'ACTIVO',   1, 0, 720.00, DATEADD(MONTH, -3, GETDATE()), '3112345678', '3112345678');

    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = '10000003')
        INSERT INTO [fab].[TercerosFabricas]
            (NitTercero, NombreTercero, EstadoTercero, TieneCupoActivo, EstaBloqueadoFabricas, MotivoBloqueo, FechaBloqueo, CelularPrincipal, CelularWhatsApp)
        VALUES ('10000003', 'Laura Mendoza Ríos',    'BLOQUEADO', 0, 1, 'MORA_DETECTADA', DATEADD(DAY, -15, GETDATE()), '3201234567', '3201234567');

    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = '10000004')
        INSERT INTO [fab].[TercerosFabricas]
            (NitTercero, NombreTercero, EstadoTercero, TieneCupoActivo, EstaBloqueadoFabricas, CelularPrincipal, CelularWhatsApp)
        VALUES ('10000004', 'Pedro Vargas Nieto',    'ACTIVO',   0, 0, '3151234567', '3151234567');

    IF NOT EXISTS (SELECT 1 FROM [fab].[TercerosFabricas] WHERE NitTercero = '10000005')
        INSERT INTO [fab].[TercerosFabricas]
            (NitTercero, NombreTercero, EstadoTercero, TieneCupoActivo, EstaBloqueadoFabricas, PuntajeCredito, FechaUltimaEvaluacion, CelularPrincipal, CelularWhatsApp)
        VALUES ('10000005', 'María Fernández Cruz',  'ACTIVO',   0, 0, 680.00, DATEADD(DAY, -1, GETDATE()),   '3181234567', '3181234567');

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.5  fab.DisponibilidadOperadores — operador de prueba conectado
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'fab.DisponibilidadOperadores', N'U') IS NOT NULL
AND OBJECT_ID(N'fab.OperadoresFabrica', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[DisponibilidadOperadores] d
        INNER JOIN [fab].[OperadoresFabrica] o ON d.IdOperador = o.IdOperador
        WHERE o.NitOperador = '12345678' AND d.FechaDesconexion IS NULL
    )
    BEGIN
        INSERT INTO [fab].[DisponibilidadOperadores]
            (IdOperador, NitOperador, EstadoDisponibilidad, FechaConexion, DireccionIP, Observaciones)
        SELECT IdOperador, NitOperador, 'CONECTADO', DATEADD(HOUR, -1, GETDATE()), '192.168.1.100', 'Sesión de prueba automatizada'
        FROM [fab].[OperadoresFabrica]
        WHERE NitOperador = '12345678';
    END

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.6  fab.EstudiosCredito — 5 estudios en distintos estados
--   Depende de: cfg.CatalogoEstados, cfg.PasosEstudio, cat.CatalogoCanalesOrigen,
--               dbo.bodegas, fab.OperadoresFabrica, fab.TercerosFabricas
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'fab.EstudiosCredito', N'U') IS NOT NULL
AND OBJECT_ID(N'cfg.CatalogoEstados', N'U') IS NOT NULL
AND OBJECT_ID(N'cat.CatalogoCanalesOrigen', N'U') IS NOT NULL
BEGIN
    -- ── Estudio 1: Cliente A (10000001) — BORRADOR, paso INGRESO_DOCUMENTO ──
    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE NitTercero = '10000001' AND EliminadoLogico = 0)
    BEGIN
        INSERT INTO [fab].[EstudiosCredito]
            (NitTercero, NitComercio, CelularCliente, IdBodega, IdAsesor, NitAsesor, IdCanal,
             IdEstadoActual, IdPasoActual, EsPreaprobado, EsReactivacion, RenunciaCupo,
             RequiereCallCenter, EsCupoExpress, EstadoRevisionFotos,
             EmailCliente, SlugPasoWeb, IdCorrelacion)
        SELECT
            '10000001', '800123456', '3001234567',
            (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9001),
            (SELECT IdOperador FROM [fab].[OperadoresFabrica] WHERE NitOperador = '12345678'),
            '12345678',
            (SELECT IdCanal FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = 'TIENDA'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            (SELECT IdPaso FROM [cfg].[PasosEstudio] WHERE Codigo = 'INGRESO_DOCUMENTO'),
            0, 0, 0, 0, 0, 'PENDIENTE',
            'ana.garcia@prueba.co', 'ingreso-documento', 'CORR-TEST-001';
    END

    -- ── Estudio 2: Cliente B (10000002) — APROBADO, cupo 2.000.000 ──
    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE NitTercero = '10000002' AND EliminadoLogico = 0)
    BEGIN
        INSERT INTO [fab].[EstudiosCredito]
            (NitTercero, NitComercio, CelularCliente, IdBodega, IdAsesor, NitAsesor, IdCanal,
             IdEstadoActual, IdPasoActual, EsPreaprobado, EsReactivacion, RenunciaCupo,
             RequiereCallCenter, EsCupoExpress, TipoCierre, CupoPreaprobado, EstadoRevisionFotos,
             EmailCliente, FechaFinalizacion, IdCorrelacion)
        SELECT
            '10000002', '800123456', '3112345678',
            (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9001),
            (SELECT IdOperador FROM [fab].[OperadoresFabrica] WHERE NitOperador = '12345678'),
            '12345678',
            (SELECT IdCanal FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = 'TIENDA'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'APROBADO'),
            NULL,
            1, 0, 0, 0, 0, 'NORMAL', 2000000, 'APROBADO',
            'carlos.ramirez@prueba.co', DATEADD(MONTH, -3, GETDATE()), 'CORR-TEST-002';
    END

    -- ── Estudio 3: Cliente C (10000003) — RECHAZADO (mora en listas) ──
    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE NitTercero = '10000003' AND EliminadoLogico = 0)
    BEGIN
        INSERT INTO [fab].[EstudiosCredito]
            (NitTercero, NitComercio, CelularCliente, IdBodega, IdAsesor, NitAsesor, IdCanal,
             IdEstadoActual, IdPasoActual, EsPreaprobado, EsReactivacion, RenunciaCupo,
             RequiereCallCenter, EsCupoExpress, TipoCierre, MotivoRechazo, EstadoRevisionFotos,
             EmailCliente, FechaFinalizacion, IdCorrelacion)
        SELECT
            '10000003', '800123456', '3201234567',
            (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9002),
            (SELECT IdOperador FROM [fab].[OperadoresFabrica] WHERE NitOperador = '12345678'),
            '12345678',
            (SELECT IdCanal FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = 'TIENDA'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'RECHAZADO'),
            NULL,
            0, 0, 0, 0, 0, 'NORMAL', 'Mora detectada en listas restrictivas', 'PENDIENTE',
            'laura.mendoza@prueba.co', DATEADD(DAY, -15, GETDATE()), 'CORR-TEST-003';
    END

    -- ── Estudio 4: Cliente D (10000004) — EN_PROGRESO, paso TOKENIZACION (OTP activo) ──
    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE NitTercero = '10000004' AND EliminadoLogico = 0)
    BEGIN
        INSERT INTO [fab].[EstudiosCredito]
            (NitTercero, NitComercio, CelularCliente, IdBodega, IdAsesor, NitAsesor, IdCanal,
             IdEstadoActual, IdPasoActual, EsPreaprobado, EsReactivacion, RenunciaCupo,
             RequiereCallCenter, EsCupoExpress, EstadoRevisionFotos,
             EmailCliente, SlugPasoWeb,
             DepartamentoCapturado, CiudadCapturada, DireccionCapturada, BarrioCapturado,
             IdCorrelacion)
        SELECT
            '10000004', '800123456', '3151234567',
            NULL, NULL, NULL,
            (SELECT IdCanal FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = 'WEB'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            (SELECT IdPaso FROM [cfg].[PasosEstudio] WHERE Codigo = 'TOKENIZACION'),
            0, 0, 0, 0, 0, 'PENDIENTE',
            'pedro.vargas@prueba.co', 'tokenizacion',
            'Valle del Cauca', 'Cali', 'Diagonal 22 # 8-40', 'San Fernando',
            'CORR-TEST-004';
    END

    -- ── Estudio 5: Cliente E (10000005) — REVISION_FABRICA, cupo preaprobado 1.500.000 ──
    IF NOT EXISTS (SELECT 1 FROM [fab].[EstudiosCredito] WHERE NitTercero = '10000005' AND EliminadoLogico = 0)
    BEGIN
        INSERT INTO [fab].[EstudiosCredito]
            (NitTercero, NitComercio, CelularCliente, IdBodega, IdAsesor, NitAsesor, IdCanal,
             IdEstadoActual, IdPasoActual, EsPreaprobado, EsReactivacion, RenunciaCupo,
             RequiereCallCenter, EsCupoExpress, CupoPreaprobado, EstadoRevisionFotos,
             EmailCliente,
             DepartamentoCapturado, CiudadCapturada, DireccionCapturada, BarrioCapturado,
             IdCorrelacion)
        SELECT
            '10000005', '800123456', '3181234567',
            (SELECT id FROM [dbo].[bodegas] WHERE bodega = 9002),
            (SELECT IdOperador FROM [fab].[OperadoresFabrica] WHERE NitOperador = '12345678'),
            '12345678',
            (SELECT IdCanal FROM [cat].[CatalogoCanalesOrigen] WHERE Codigo = 'TIENDA'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'REVISION_FABRICA'),
            NULL,
            1, 0, 0, 0, 0, 1500000, 'APROBADO',
            'maria.fernandez@prueba.co',
            'Cundinamarca', 'Bogotá', 'Calle 80 # 50-25', 'Normandía',
            'CORR-TEST-005';
    END

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.7  fab.RetosSeguridad — OTP activo para estudio EN_PROGRESO (Cliente D)
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'fab.RetosSeguridad', N'U') IS NOT NULL
AND OBJECT_ID(N'fab.EstudiosCredito', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[RetosSeguridad] rs
        INNER JOIN [fab].[EstudiosCredito] ec ON rs.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000004' AND rs.Exitoso = 0 AND rs.FechaExpiracion > GETDATE()
    )
    BEGIN
        INSERT INTO [fab].[RetosSeguridad]
            (IdEstudio, NitTercero, CanalEnvio, HashToken, FechaEnvio, FechaExpiracion,
             NumeroIntentos, Exitoso, NumeroReenvios, DireccionEnvio)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000004' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            '10000004', 'WHATSAPP',
            CONVERT(VARCHAR(256), HASHBYTES('SHA2_256', CAST(NEWID() AS VARCHAR(50))), 2),
            DATEADD(MINUTE, -5, GETDATE()),
            DATEADD(MINUTE, 25, GETDATE()),
            0, 0, 0, '3151234567';
    END

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.8  fab.EvaluacionesRiesgo — evaluaciones LISTAS y BURO
--       Clientes E (REVISION_FABRICA) y B (APROBADO): ambas APROBADO
--       Cliente C (RECHAZADO): LISTAS RECHAZADO
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'fab.EvaluacionesRiesgo', N'U') IS NOT NULL
AND OBJECT_ID(N'fab.EstudiosCredito', N'U') IS NOT NULL
BEGIN
    -- Cliente E — LISTAS aprobado
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[EvaluacionesRiesgo] ev
        INNER JOIN [fab].[EstudiosCredito] ec ON ev.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000005' AND ev.TipoEvaluacion = 'LISTAS'
    )
        INSERT INTO [fab].[EvaluacionesRiesgo]
            (IdEstudio, TipoEvaluacion, CoincidenciaListasRestrictivas, Resultado, MotivoResultado)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000005' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            'LISTAS', 0, 'APROBADO', 'Sin coincidencias en listas restrictivas';

    -- Cliente E — BURO aprobado (score 680)
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[EvaluacionesRiesgo] ev
        INNER JOIN [fab].[EstudiosCredito] ec ON ev.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000005' AND ev.TipoEvaluacion = 'BURO'
    )
        INSERT INTO [fab].[EvaluacionesRiesgo]
            (IdEstudio, TipoEvaluacion, CoincidenciaListasRestrictivas, ScoreBuro, ViablePreselecta, Resultado, MotivoResultado)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000005' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            'BURO', 0, 680, 1, 'APROBADO', 'Score aprobado — preaprobada Preselecta';

    -- Cliente B — LISTAS aprobado
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[EvaluacionesRiesgo] ev
        INNER JOIN [fab].[EstudiosCredito] ec ON ev.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000002' AND ev.TipoEvaluacion = 'LISTAS'
    )
        INSERT INTO [fab].[EvaluacionesRiesgo]
            (IdEstudio, TipoEvaluacion, CoincidenciaListasRestrictivas, Resultado, MotivoResultado)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            'LISTAS', 0, 'APROBADO', 'Sin coincidencias en listas restrictivas';

    -- Cliente B — BURO aprobado (score 720)
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[EvaluacionesRiesgo] ev
        INNER JOIN [fab].[EstudiosCredito] ec ON ev.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000002' AND ev.TipoEvaluacion = 'BURO'
    )
        INSERT INTO [fab].[EvaluacionesRiesgo]
            (IdEstudio, TipoEvaluacion, CoincidenciaListasRestrictivas, ScoreBuro, ViablePreselecta, Resultado, MotivoResultado)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            'BURO', 0, 720, 1, 'APROBADO', 'Score aprobado — preaprobada Preselecta';

    -- Cliente C — LISTAS rechazado (mora)
    IF NOT EXISTS (
        SELECT 1 FROM [fab].[EvaluacionesRiesgo] ev
        INNER JOIN [fab].[EstudiosCredito] ec ON ev.IdEstudio = ec.IdEstudio
        WHERE ec.NitTercero = '10000003' AND ev.TipoEvaluacion = 'LISTAS'
    )
        INSERT INTO [fab].[EvaluacionesRiesgo]
            (IdEstudio, TipoEvaluacion, CoincidenciaListasRestrictivas, Resultado, MotivoResultado)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000003' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            'LISTAS', 1, 'RECHAZADO', 'Coincidencia detectada en listas OFAC/SARLAFT';

END


-- ─────────────────────────────────────────────────────────────────────────────
-- 11.9  aud.HistorialEstados — transiciones de los 5 estudios
-- ─────────────────────────────────────────────────────────────────────────────
IF OBJECT_ID(N'aud.HistorialEstados', N'U') IS NOT NULL
AND OBJECT_ID(N'fab.EstudiosCredito', N'U') IS NOT NULL
AND OBJECT_ID(N'cfg.CatalogoEstados', N'U') IS NOT NULL
BEGIN
    -- ── Cliente A (10000001): INICIO → BORRADOR ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000001' AND ce.Codigo = 'BORRADOR'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000001' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            NULL,
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            'ASESOR', 'Inicio de estudio de crédito', '12345678', 'CORR-TEST-001';

    -- ── Cliente D (10000004): INICIO → BORRADOR ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000004' AND ce.Codigo = 'BORRADOR'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000004' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            NULL,
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            'CLIENTE', 'Inicio de solicitud de cupo', 'CORR-TEST-004',
            DATEADD(MINUTE, -30, GETDATE());

    -- ── Cliente D (10000004): BORRADOR → EN_PROGRESO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000004' AND ce.Codigo = 'EN_PROGRESO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000004' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            'CLIENTE', 'Cliente completó datos personales — avance al flujo', 'CORR-TEST-004',
            DATEADD(MINUTE, -15, GETDATE());

    -- ── Cliente C (10000003): INICIO → BORRADOR ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000003' AND ce.Codigo = 'BORRADOR'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000003' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            NULL,
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            'ASESOR', 'Inicio de estudio de crédito', '12345678', 'CORR-TEST-003',
            DATEADD(DAY, -15, DATEADD(MINUTE, -45, GETDATE()));

    -- ── Cliente C (10000003): BORRADOR → EN_PROGRESO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000003' AND ce.Codigo = 'EN_PROGRESO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000003' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            'ASESOR', 'Datos capturados — avance al flujo de validaciones', '12345678', 'CORR-TEST-003',
            DATEADD(DAY, -15, DATEADD(MINUTE, -30, GETDATE()));

    -- ── Cliente C (10000003): EN_PROGRESO → RECHAZADO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000003' AND ce.Codigo = 'RECHAZADO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000003' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'RECHAZADO'),
            'SISTEMA', 'Mora detectada en listas restrictivas — rechazo automático', '12345678', 'CORR-TEST-003',
            DATEADD(DAY, -15, GETDATE());

    -- ── Cliente E (10000005): INICIO → BORRADOR ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000005' AND ce.Codigo = 'BORRADOR'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000005' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            NULL,
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            'ASESOR', 'Inicio de estudio de crédito', '12345678', 'CORR-TEST-005',
            DATEADD(HOUR, -3, GETDATE());

    -- ── Cliente E (10000005): BORRADOR → EN_PROGRESO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000005' AND ce.Codigo = 'EN_PROGRESO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000005' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            'ASESOR', 'Datos capturados y consentimiento firmado', '12345678', 'CORR-TEST-005',
            DATEADD(HOUR, -2, GETDATE());

    -- ── Cliente E (10000005): EN_PROGRESO → REVISION_FABRICA ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000005' AND ce.Codigo = 'REVISION_FABRICA'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000005' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'REVISION_FABRICA'),
            'SISTEMA', 'Validaciones completadas — enviado a fábrica para revisión final', '12345678', 'CORR-TEST-005',
            DATEADD(HOUR, -1, GETDATE());

    -- ── Cliente B (10000002): INICIO → BORRADOR ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000002' AND ce.Codigo = 'BORRADOR'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            NULL,
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            'ASESOR', 'Inicio de estudio de crédito', '12345678', 'CORR-TEST-002',
            DATEADD(MONTH, -3, DATEADD(HOUR, -5, GETDATE()));

    -- ── Cliente B (10000002): BORRADOR → EN_PROGRESO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000002' AND ce.Codigo = 'EN_PROGRESO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'BORRADOR'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            'ASESOR', 'Datos capturados y consentimiento firmado', '12345678', 'CORR-TEST-002',
            DATEADD(MONTH, -3, DATEADD(HOUR, -4, GETDATE()));

    -- ── Cliente B (10000002): EN_PROGRESO → REVISION_FABRICA ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000002' AND ce.Codigo = 'REVISION_FABRICA'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'EN_PROGRESO'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'REVISION_FABRICA'),
            'SISTEMA', 'Validaciones exitosas — enviado a fábrica', '12345678', 'CORR-TEST-002',
            DATEADD(MONTH, -3, DATEADD(HOUR, -3, GETDATE()));

    -- ── Cliente B (10000002): REVISION_FABRICA → APROBADO ──
    IF NOT EXISTS (
        SELECT 1 FROM [aud].[HistorialEstados] h
        INNER JOIN [fab].[EstudiosCredito] ec ON h.IdEstudio = ec.IdEstudio
        INNER JOIN [cfg].[CatalogoEstados] ce ON h.IdEstadoNuevo = ce.IdEstado
        WHERE ec.NitTercero = '10000002' AND ce.Codigo = 'APROBADO'
    )
        INSERT INTO [aud].[HistorialEstados]
            (IdEstudio, IdEstadoAnterior, IdEstadoNuevo, TipoUsuario, MotivoTransicion, NitAsesor, IdCorrelacion, FechaTransicion)
        SELECT
            (SELECT TOP 1 IdEstudio FROM [fab].[EstudiosCredito]
             WHERE NitTercero = '10000002' AND EliminadoLogico = 0 ORDER BY FechaCreacion DESC),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'REVISION_FABRICA'),
            (SELECT IdEstado FROM [cfg].[CatalogoEstados] WHERE Codigo = 'APROBADO'),
            'ASESOR', 'Cupo aprobado por analista — activación en KCRM', '12345678', 'CORR-TEST-002',
            DATEADD(MONTH, -3, GETDATE());

END


-- ==============================================================================
-- ═══════════════════════════════════════════════════════════════════════════════
-- RESUMEN DE EJECUCIÓN
-- ═══════════════════════════════════════════════════════════════════════════════
PRINT '============================================================';
PRINT '  FABRICAS v2.8-PRUEBAS - EJECUCIÓN COMPLETA';
PRINT '============================================================';
PRINT '✓ Script ejecutado exitosamente en modo PRUEBAS';
