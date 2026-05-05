-------------------------------------------------------------------------------------------------
-- TABLAS EXISTENTES EN EL SISTEMA (NO SUGERIR ELIMINACIÓN, SOLO INTEGRACIÓN)
-- Estas tablas ya existen en el sistema 
--------------------------------------------------------------------------------------------------
-- QUAC.dbo.terceros definition

-- Tabla base con datos de terceros (clientes, proveedores, etc.) del ERP QUAC. Contiene información demográfica, de contacto y banderas de estado.

CREATE TABLE QUAC.dbo.terceros (
	nit Tipo_NIT NOT NULL,
	digito tinyint NULL,
	nombres varchar(60) COLLATE Modern_Spanish_CI_AS NOT NULL,
	direccion varchar(200) COLLATE Modern_Spanish_CI_AS NULL,
	ciudad varchar(140) COLLATE Modern_Spanish_CI_AS NULL,
	telefono_1 varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	telefono_2 varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	fax varchar(15) COLLATE Modern_Spanish_CI_AS NULL,
	apartado_aereo varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	tipo_identificacion char(1) COLLATE Modern_Spanish_CI_AS NULL,
	pais varchar(200) COLLATE Modern_Spanish_CI_AS NULL,
	gran_contribuyente bit DEFAULT 0 NOT NULL,
	autoretenedor bit DEFAULT 0 NOT NULL,
	bloqueo tinyint DEFAULT 0 NULL,
	notas varchar(250) COLLATE Modern_Spanish_CI_AS NULL,
	lista tinyint NULL,
	concepto_1 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_2 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_3 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_4 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_5 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_6 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_7 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_8 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_9 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_10 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	mail varchar(100) COLLATE Modern_Spanish_CI_AS NULL,
	pos_num tinyint DEFAULT 0 NOT NULL,
	regimen char(1) COLLATE Modern_Spanish_CI_AS NULL,
	cupo_credito money NULL,
	nit_real Tipo_NIT NOT NULL,
	condicion varchar(4) COLLATE Modern_Spanish_CI_AS NULL,
	vendedor Tipo_NIT NULL,
	fletes real NULL,
	es_excento_iva varchar(1) COLLATE Modern_Spanish_CI_AS NULL,
	contacto_1 varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	contacto_2 varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	formato_factura varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	fecha_creacion datetime NULL,
	formato_copias tinyint NULL,
	tipo_factura varchar(4) COLLATE Modern_Spanish_CI_AS NULL,
	dias_gracia smallint NULL,
	solo_contado varchar(1) COLLATE Modern_Spanish_CI_AS NULL,
	descuento_fijo real NULL,
	excluir_tabla_desc char(1) COLLATE Modern_Spanish_CI_AS NULL,
	centro_fijo int NULL,
	exportado char(1) COLLATE Modern_Spanish_CI_AS NULL,
	factor_o_lista char(1) COLLATE Modern_Spanish_CI_AS NULL,
	codigo_ica smallint NULL,
	fecha_modificacion datetime NULL,
	cumple nvarchar(50) COLLATE Modern_Spanish_CI_AS DEFAULT N'NO' NULL,
	tiket nvarchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	minimo_ret_vtas money NULL,
	nospam bit DEFAULT 0 NULL,
	factor_negociacion real NULL,
	envio nvarchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_11 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_12 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_13 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_14 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_15 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_16 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_17 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_18 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_19 varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	concepto_20 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	ter_mercadeo bit NULL,
	ter_fecha_corte smalldatetime NULL,
	rol tinyint NULL,
	pr_password varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	vsw_porcventas real DEFAULT 0 NOT NULL,
	vsw_bodega int NULL,
	descuento_fijo_prov real NULL,
	solo_contado_compra varchar(1) COLLATE Modern_Spanish_CI_AS NULL,
	y_dpto varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	y_ciudad varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	cm_lastupdate datetime DEFAULT getdate() NULL,
	clasificado char(1) COLLATE Modern_Spanish_CI_AS NULL,
	edad varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	id int IDENTITY(1,1) NOT NULL,
	celular varchar(15) COLLATE Modern_Spanish_CI_AS NULL,
	fecha_nacimiento datetime NULL,
	fecha_asig_cum datetime NULL,
	fecha_cumple datetime NULL,
	dias_recibo_caja smallint NULL,
	tipo_devolucion varchar(4) COLLATE Modern_Spanish_CI_AS NULL,
	fecha_ult_factura datetime NULL,
	y_pais varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	ext_1 varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	codigo_alterno varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Usuario2 varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Motivo_Estado nvarchar(200) COLLATE Modern_Spanish_CI_AS NULL,
	banco_personas smallint NULL,
	LimiteCompra smallint NULL,
	FechaCambioMail smalldatetime NULL,
	UndMaxCortesia int NULL,
	VlrMaxCortesia money NULL,
	AcumulaCortesia bit DEFAULT 0 NULL,
	PIN varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	AñoNace int NULL,
	departamento varchar(7) COLLATE Modern_Spanish_CI_AS NULL,
	ciudad2 varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	ExcluidoLey bit NULL,
	BodegaActualiza int NULL,
	UsuarioActualiza varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	tieneRUT nvarchar(1) COLLATE Modern_Spanish_CI_AS NULL,
	mail_adicional varchar(250) COLLATE Modern_Spanish_CI_AS NULL,
	estado_civil nvarchar(1) COLLATE Modern_Spanish_CI_AS NULL,
	codigoActividadEconomica varchar(4) COLLATE Modern_Spanish_CI_AS NULL,
	codigoPostal nvarchar(9) COLLATE Modern_Spanish_CI_AS NULL,
	estrato char(1) COLLATE Modern_Spanish_CI_AS NULL,
	paginaweb varchar(80) COLLATE Modern_Spanish_CI_AS NULL,
	area_labora varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	cargo varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	ext2 varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	celular2 varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	email2 varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	otro_descuento real NULL,
	no_regulados char(1) COLLATE Modern_Spanish_CI_AS NULL,
	descuento_financiero real NULL,
	formatoRemision varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	copiaRemision char(1) COLLATE Modern_Spanish_CI_AS NULL,
	GLN_Cabasnet varchar(30) COLLATE Modern_Spanish_CI_AS NULL,
	Usuario varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	ftoCopia_factura varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	tipo_direccion smallint NULL,
	id_definicion_tributaria_tipo int NULL,
	DocumentoExtranjeria varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Insolvencia bit NULL,
	Insoluto bit NULL,
	CONSTRAINT IX_terceros_id UNIQUE (id),
	CONSTRAINT PK_terceros_1__10 PRIMARY KEY (nit)
);


-- QUAC.dbo.bodegas definition
-- Tabla que contiene informacion de bodegas, equivalente a los puntos de venta en el sistema QUAC. 
-- Contiene datos de ubicación, contacto, características comerciales y operativas, así como indicadores de desempeño y clasificación.

CREATE TABLE QUAC.dbo.bodegas (
	bodega decimal(18,0) NULL,
	descripcion varchar(40) COLLATE Modern_Spanish_CI_AS NOT NULL,
	centro int DEFAULT 0 NOT NULL,
	direccion varchar(80) COLLATE Modern_Spanish_CI_AS NULL,
	telefono varchar(40) COLLATE Modern_Spanish_CI_AS NULL,
	texto varchar(250) COLLATE Modern_Spanish_CI_AS NULL,
	codigo_cliente varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	GrupoBodega int NULL,
	PorcPresupuesto real NULL,
	IdGerencia int NULL,
	marcas varchar(500) COLLATE Modern_Spanish_CI_AS NULL,
	rebates int DEFAULT 0 NOT NULL,
	cumple int DEFAULT 0 NOT NULL,
	mp real DEFAULT 0 NOT NULL,
	promfact money DEFAULT 0 NOT NULL,
	excluidas varchar(3000) COLLATE Modern_Spanish_CI_AS NULL,
	huella_inicial smalldatetime NULL,
	huella_final smalldatetime NULL,
	si_marcas varchar(3000) COLLATE Modern_Spanish_CI_AS NULL,
	exportacion datetime NULL,
	importacion datetime NULL,
	cm_lastupdate datetime DEFAULT getdate() NULL,
	SancionDec real DEFAULT 0 NOT NULL,
	GrupoComisionBod char(1) COLLATE Modern_Spanish_CI_AS DEFAULT 'A' NOT NULL,
	tipo_prenda varchar(500) COLLATE Modern_Spanish_CI_AS NULL,
	id int IDENTITY(1,1) NOT NULL,
	asterisco int DEFAULT 0 NULL,
	departamento varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	ciudad varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	autoretenedorica bit NULL,
	es_punto_venta bit NULL,
	impresora varchar(80) COLLATE Modern_Spanish_CI_AS NULL,
	idTask int NULL,
	ColoresADespachar int NULL,
	StockMaximo int NULL,
	StockActual int DEFAULT 0 NOT NULL,
	PorcPresupVtas real DEFAULT 0 NOT NULL,
	PorcPresupVtasCredito real DEFAULT 0 NOT NULL,
	PorcCumplimientoMP real DEFAULT 0 NOT NULL,
	PorcTelemercadeo real DEFAULT 0 NOT NULL,
	PorcCalifServicio real DEFAULT 0 NOT NULL,
	IdZona int NULL,
	FechaUltimaApertura smalldatetime NULL,
	TipoBodega int NULL,
	CiudadBod varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	id_clasificacion int NULL,
	Acepta_Ext bit NULL,
	Utilidad int NULL,
	idSMD varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	MinimoPersonal int NULL,
	MaximoPersonal int NULL,
	pais varchar(5) COLLATE Modern_Spanish_CI_AS NULL,
	bloqueo_inventarios tinyint DEFAULT 0 NOT NULL,
	texto2 varchar(300) COLLATE Modern_Spanish_CI_AS NULL,
	es_bodega_obsoleta bit DEFAULT 0 NOT NULL,
	TipoTienda varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	GrupoApuestas int NULL,
	Tienda varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	TelefonoCall varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	demostracion bit NULL,
	es_almacen bit DEFAULT 0 NOT NULL,
	PorcCreditosEfectivos int NULL,
	BloqueoPagos bit DEFAULT 0 NOT NULL,
	UltimoBloqueo smalldatetime NULL,
	UltimoDesbloqueo smalldatetime NULL,
	NotaBloqueo varchar(300) COLLATE Modern_Spanish_CI_AS NULL,
	PorcReventa int NULL,
	PorcSolicitudesNuevas int NULL,
	IdZonaClima int NULL,
	IdPerfilPrecios int NULL,
	EsVitrina bit NULL,
	BodegaEstadistica int NULL,
	inactiva char(1) COLLATE Modern_Spanish_CI_AS NULL,
	excluidasActivos varchar(3000) COLLATE Modern_Spanish_CI_AS NULL,
	DestinoInsumos varchar(3000) COLLATE Modern_Spanish_CI_AS NULL,
	PorcPromFactura real NULL,
	ColeccionesBloqueadas varchar(300) COLLATE Modern_Spanish_CI_AS NULL,
	IdCoordinacion int NULL,
	HoraApertura time NULL,
	HoraCierre time NULL,
	HoraAperturaFestivo time NULL,
	HoraCierreFestivo time NULL,
	PresupuestoClientesNuevos decimal(3,2) NULL,
	IdGrupoComision int NULL,
	NitResponsable decimal(18,0) NULL,
	cerrada bit NULL,
	fechacierre smalldatetime NULL,
	motivocierre varchar(200) COLLATE Modern_Spanish_CI_AS NULL,
	proposito varchar(300) COLLATE Modern_Spanish_CI_AS NULL,
	MinimoDias int NULL,
	EsDespachoDias bit DEFAULT 0 NOT NULL,
	FechaOffline date NULL,
	PorcVentaContado real NULL,
	IdRegional int NULL,
	ExcluirRendimiento bit DEFAULT 0 NOT NULL,
	OfflineActivo bit NULL,
	PoliticaPrivacidad varchar(MAX) COLLATE Modern_Spanish_CI_AS NULL,
	ImprimirPolitica bit DEFAULT 0 NOT NULL,
	IdGrupoCredito int NULL,
	Latitud float NULL,
	Longitud float NULL,
	idZonaLogistica int NULL,
	BodegaPresupuesto int NULL,
	Extensiones varchar(100) COLLATE Modern_Spanish_CI_AS NULL,
	HoraInicioIntranet datetime NULL,
	HoraFinIntranet datetime NULL,
	PorcentajeProvision real NULL,
	FeCodigoCiudad varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	FeCodigoDepartamento varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	FeCodigoMunicipioFiscal varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	FeCodigoDepartamentoFiscal varchar(10) COLLATE Modern_Spanish_CI_AS NULL,
	DepartamentoBod varchar(40) COLLATE Modern_Spanish_CI_AS NULL,
	LinkWhatsAPP varchar(50) COLLATE Modern_Spanish_CI_AS NULL,
	NotificacionesFactura varchar(MAX) COLLATE Modern_Spanish_CI_AS NULL,
	RepoDias int NULL,
	RepoCompletar int NULL,
	IP_Server varchar(30) COLLATE Modern_Spanish_CI_AS NULL,
	Nit_Comercio Tipo_NIT NULL,
	HoraInicioTask datetime NULL,
	HoraFinTask datetime NULL
);


-- PRUEBASBD.dbo.kcrm_VendedoresExternos definition

-- Tabla que contiene información de vendedores de las tiendas

CREATE TABLE PRUEBASBD.dbo.kcrm_VendedoresExternos (
	nit Tipo_NIT NOT NULL,
	codigo Tipo_NIT NOT NULL,
	IdLider int NULL,
	MonoMarca bit NULL,
	CONSTRAINT PK_kcrm_VendedoresExternos PRIMARY KEY (codigo)
);

-- QUAC.dbo.BERP_FABRICASOperadores definition

-- Tabla de los operadores del call center

CREATE TABLE QUAC.dbo.BERP_FABRICASOperadores (
	idOperadorFabrica int IDENTITY(1,1) NOT NULL,
	idTipoFabrica int NULL,
	usuario varchar(100) COLLATE Modern_Spanish_CI_AS NULL,
	nit decimal(18,0) NULL,
	aforo int NULL,
	aforoMaximo int NULL,
	idTipoFabricaPerfil int NULL,
	CONSTRAINT PK_BERP_FABRICASOperadores PRIMARY KEY (idOperadorFabrica)
);

-- tabla con el estado de los operadores del call center, para saber si están conectados o desconectados, y a qué hora se conectan o desconectan

CREATE TABLE QUAC.dbo.BERP_FABRICASOperadorEstados (
	idOperadorEstadoFabrica int IDENTITY(1,1) NOT NULL,
	idOperadorFabrica int NULL,
	fechaHoraDesconecta smalldatetime NULL,
	fechaHoraConecta smalldatetime NULL,
	idStatus int NULL,
	nit decimal(18,0) NULL,
	CONSTRAINT PK_BERP_FABRICASOperadorEstados PRIMARY KEY (idOperadorEstadoFabrica)
);


-- QUAC.dbo.KCRM_CadenaCreditos definition

-- Informacion crediticia de un cliente, especial importancia en cupoaprobado, bodega, vendedor, bloqueado.

CREATE TABLE QUAC.dbo.KCRM_CadenaCreditos (
	IdCadena int IDENTITY(1,1) NOT NULL,
	Nit Tipo_NIT NOT NULL,
	FechaIngreso datetime DEFAULT getdate() NOT NULL,
	PasoActual int NULL,
	StatusActual int NULL,
	Notas varchar(3000) COLLATE Modern_Spanish_CI_AS NULL,
	Operario varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Aprobado bit DEFAULT 0 NOT NULL,
	Bodega int NULL,
	Vendedor Tipo_NIT NULL,
	EnPausa bit DEFAULT 0 NOT NULL,
	FechaPausa smalldatetime NULL,
	Negado bit DEFAULT 0 NOT NULL,
	Archivado bit DEFAULT 0 NOT NULL,
	CupoAprobado money NULL,
	Asignado bit DEFAULT 0 NOT NULL,
	FechaAprobacion datetime NULL,
	UsuarioAprueba varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	FechaAsignacion datetime NULL,
	UsuarioAsigna varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	IdMotivo int NULL,
	Empleado Tipo_NIT NULL,
	AuditadaPor varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	MailEnviado bit DEFAULT 0 NULL,
	BodegaCredito int NULL,
	Devuelto bit DEFAULT 0 NOT NULL,
	FechaDevolucion smalldatetime NULL,
	RP tinyint DEFAULT 0 NOT NULL,
	RL tinyint DEFAULT 0 NOT NULL,
	RC tinyint DEFAULT 0 NOT NULL,
	FechaReestudio smalldatetime NULL,
	AutorizadoCR bit NULL,
	FechaUltimoEvento smalldatetime NULL,
	UltimoEvento varchar(3) COLLATE Modern_Spanish_CI_AS NULL,
	Activa bit DEFAULT 0 NOT NULL,
	FechaActivacionComercial smalldatetime NULL,
	FechaUltimaGestion smalldatetime NULL,
	Gestor varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	InicioGestionComercial smalldatetime NULL,
	FinGestionComercial smalldatetime NULL,
	Origen int NULL,
	CarpetaPagare varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	IdClase int NULL,
	AprobadoPor decimal(18,0) NULL,
	Cobrador varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	AlarmaFraude bit NULL,
	precastigo bit NULL,
	FechaNuevoBeneficiario smalldatetime NULL,
	DocumentoValido bit NULL,
	UsuarioValida varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	PcValida varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	FechaValidacion varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Usuario varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Pc varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	EnTienda bit NULL,
	esfranquicia bit DEFAULT 0 NOT NULL,
	OperadorBusqueda varchar(20) COLLATE Modern_Spanish_CI_AS NULL,
	Externo bit NULL,
	FechaTrabajo date NULL,
	EnCasaCobro bit NULL,
	Score int NULL,
	FechaScore smalldatetime NULL,
	IdSolicitudWeb int NULL,
	IdLlamadaCentrales int NULL,
	UltAumentoTienda datetime NULL,
	FechaValidaHuella datetime NULL,
	NitValidaHuella decimal(18,0) NULL,
	Latitud float NULL,
	Longitud float NULL,
	QTF bit NULL,
	QTC bit NULL,
	UltAlarmaEnTienda datetime NULL,
	BERP_NitPromotor Tipo_NIT NOT NULL,
	Bloqueado int DEFAULT 1 NULL,
	cm_lastupdate datetime NULL,
	FechaAumento date NULL,
	CupoAnterior money NULL,
	CONSTRAINT PK_KCRM_CadenaCreditos_1 PRIMARY KEY (Nit,BERP_NitPromotor)
);


-- ==============================================================================
-- TABLAS DE LOGS DE CENTRALES DE RIESGO (YA EXISTEN — NO MODIFICAR)
-- Estas 4 tablas son los logs de invocación a las centrales de riesgo externas.
-- Cada tabla registra la petición enviada y la respuesta recibida, con fecha y
-- bandera de éxito. Las consultas y escrituras son realizadas por el API externo
-- de cada central — Fábricas NO escribe en ellas directamente.
-- Rol de Fábricas: leer el Id del registro generado por el API externo y
-- guardarlo en fab.EvaluacionesRiesgo para trazabilidad cruzada.
-- ==============================================================================

-- QUAC.dbo.BERP_FABRICASDatacredito_PreselectaDesicion
-- Central: Datacredito | Servicio: Preselecta (VIABILIDAD)
-- Guarda cada consulta de viabilidad/preselecta realizada a Datacredito.
-- Columna Cedula permite buscar el historial de consultas por cliente.
-- FueExitoso = 1 indica que el servicio respondió sin error técnico
-- (independiente del resultado de negocio incluido en Respuesta JSON).
CREATE TABLE QUAC.dbo.BERP_FABRICASDatacredito_PreselectaDesicion (
    Id          int IDENTITY(1,1) NOT NULL,
    Cedula      bigint NOT NULL,
    Respuesta   varchar(3000) COLLATE Modern_Spanish_CI_AS NOT NULL,
    FechaRegistro date NOT NULL,
    Peticion    varchar(1000) COLLATE Modern_Spanish_CI_AS NULL,
    FueExitoso  bit NULL,
    CONSTRAINT PK__BERP_FABRICASDatacredito_PreselectaDesicion PRIMARY KEY (Id)
);
CREATE NONCLUSTERED INDEX IX_BERP_FABRICASDatacredito_PreselectaDesicion_Cedula
    ON QUAC.dbo.BERP_FABRICASDatacredito_PreselectaDesicion (Cedula ASC);


-- QUAC.dbo.BERP_CUPOAprobacion_Reconocer_Log
-- Central: Datacredito | Servicio: Reconocer (CONTACTABILIDAD)
-- Guarda cada consulta de contactabilidad realizada a Reconocer (Datacredito).
-- FechaRegistro es DATETIME (precisión completa) a diferencia de Preselecta (date).
CREATE TABLE QUAC.dbo.BERP_CUPOAprobacion_Reconocer_Log (
    Id          int IDENTITY(1,1) NOT NULL,
    Cedula      bigint NOT NULL,
    Respuesta   varchar(MAX) COLLATE Modern_Spanish_CI_AS NOT NULL,
    FechaRegistro datetime NOT NULL,
    Peticion    varchar(1000) COLLATE Modern_Spanish_CI_AS NULL,
    FueExitoso  bit NOT NULL,
    CONSTRAINT PK__BERP_CUPOAprobacion_Reconocer_Log PRIMARY KEY (Id)
);
CREATE NONCLUSTERED INDEX IX_BERP_CUPOAprobacion_Reconocer_Log_Cedula
    ON QUAC.dbo.BERP_CUPOAprobacion_Reconocer_Log (Cedula ASC);


-- QUAC.dbo.BERP_FABRICASCifinUbicaLog
-- Central: CIFIN (TransUnion) | Servicio: UBICA (CONTACTABILIDAD)
-- Guarda cada consulta de contactabilidad realizada a UBICA (CIFIN).
-- Equivalente funcional a BERP_CUPOAprobacion_Reconocer_Log pero para CIFIN.
-- FechaRegistro es DATE (sin hora), igual que en Preselecta.
CREATE TABLE QUAC.dbo.BERP_FABRICASCifinUbicaLog (
    Id          int IDENTITY(1,1) NOT NULL,
    Cedula      bigint NOT NULL,
    Respuesta   varchar(5000) COLLATE Modern_Spanish_CI_AS NOT NULL,
    FechaRegistro date NOT NULL,
    Peticion    varchar(1000) COLLATE Modern_Spanish_CI_AS NULL,
    FueExitoso  bit NOT NULL,
    CONSTRAINT PK__BERP_FABRICASCifinUbica PRIMARY KEY (Id)
);
CREATE NONCLUSTERED INDEX IX_BERP_FABRICASCifinUbica_Cedula
    ON QUAC.dbo.BERP_FABRICASCifinUbicaLog (Cedula ASC);


-- QUAC.dbo.BERP_FABRICASCifinAdviserLog
-- Central: CIFIN (TransUnion) | Servicio: VariablesAdviser (VIABILIDAD)
-- Guarda cada consulta de viabilidad realizada a VariablesAdviser (CIFIN).
-- Equivalente funcional a BERP_FABRICASDatacredito_PreselectaDesicion.
-- Peticion es varchar(4000) — payload más grande que Preselecta (varchar 1000).
-- FechaRegistro es DATETIME con DEFAULT getdate() — el más preciso de los 4 logs.
CREATE TABLE QUAC.dbo.BERP_FABRICASCifinAdviserLog (
    Id          int IDENTITY(1,1) NOT NULL,
    Cedula      bigint NOT NULL,
    Peticion    varchar(4000) COLLATE Modern_Spanish_CI_AS NOT NULL,
    Respuesta   varchar(MAX) COLLATE Modern_Spanish_CI_AS NOT NULL,
    FechaRegistro datetime DEFAULT getdate() NOT NULL,
    FueExitoso  bit NOT NULL,
    CONSTRAINT PK__BERP_FAB__3214EC0795266C8A PRIMARY KEY (Id)
);