/* 
=============================================================================
ARQUITECTURA DE DATOS: SISTEMA DE OTORGAMIENTO Y BIOMETRÍA
MOTOR: SQL SERVER 2019+
AUTOR: ARQUITECTURA DE DATOS
FECHA: 2023-10-27
=============================================================================
*/

-- 1. TABLA MAESTRA DE CLIENTES
-- Asume la integración con ERP QUAC. Contiene datos demográficos y banderas de estado global.
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    DocumentType CHAR(3) NOT NULL, -- CC, CE, PPT
    DocumentNumber VARCHAR(20) NOT NULL,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(150),
    MobilePhone VARCHAR(20),
    BirthDate DATE,
    Address VARCHAR(250),
    
    -- Banderas de proceso (Optimizan lecturas sin ir a tablas de detalle)
    HasActiveQuota BIT DEFAULT 0, -- ¿Tiene cupo activo?
    IsBlocked BIT DEFAULT 0, -- ¿Está bloqueado?
    BiometricEnrolled BIT DEFAULT 0, -- ¿Tiene registro fotográfico base?
    LastDataUpdate DATETIME2, -- Para validar "Cambio de datos en los últimos xxx días"
    
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    UpdatedAt DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT UQ_Customer_Document UNIQUE (DocumentType, DocumentNumber)
);

-- Índices para búsqueda rápida en Tienda
CREATE INDEX IX_Customers_Doc ON Customers(DocumentNumber);
CREATE INDEX IX_Customers_Mobile ON Customers(MobilePhone);

-- 2. PRODUCTO DE CRÉDITO (EL CUPO)
-- Maneja la persistencia del cupo, bloqueos y cancelaciones.
CREATE TABLE CreditProducts (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    CreditLimit DECIMAL(18,2) NOT NULL DEFAULT 0,
    CurrentStatus VARCHAR(20) NOT NULL, -- ACTIVE, BLOCKED, CANCELLED
    BlockReason VARCHAR(50), -- MORA, FRAUDE, SOLICITUD_CLIENTE
    
    CancellationDate DATETIME2, -- Vital para "Renunció en los últimos XXX días"
    ReactivationEligibility BIT DEFAULT 0, -- Si cumple condiciones para reactivación exprés
    
    LastPurchaseDate DATETIME2, -- Para validar "Compras en los últimos xxxx"
    
    CONSTRAINT FK_Product_Customer FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- 3. SOLICITUD DE CRÉDITO (EL PROCESO)
-- Tabla central que orquesta todo el flujo del diagrama Miro.
CREATE TABLE CreditRequests (
    RequestID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    AdvisorID INT, -- Código del Asesor que gestiona (Tienda/Call)
    OriginChannel VARCHAR(20) NOT NULL, -- TIENDA, WEB, CALL_CENTER
    
    -- Estado de la Máquina de Estados
    RequestStatus VARCHAR(30) NOT NULL, -- DRAFT, PENDING_OTP, PENDING_BIO, APPROVED, REJECTED
    RejectionReason VARCHAR(100), -- ANTECEDENTES, CAPACIDAD_PAGO, BIOMETRIA_FALLIDA
    
    -- Tiempos para control de SLA y expiración (90 días)
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    LastActivityDate DATETIME2 DEFAULT GETDATE(),
    CompletedDate DATETIME2,
    
    IsPreApproved BIT DEFAULT 0, -- Estado intermedio "Cupo Preaprobado"
    
    CONSTRAINT FK_Request_Customer FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- Índice para validar "Estudio tokenizado en últimos 90 días"
CREATE INDEX IX_Requests_Customer_Date ON CreditRequests(CustomerID, CreatedDate);

-- 4. RETOS DE SEGURIDAD (OTP / TOKENIZACIÓN)
-- Maneja los tokens de WhatsApp/Email y la regla de 24h.
CREATE TABLE SecurityChallenges (
    ChallengeID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RequestID BIGINT NOT NULL,
    CustomerID INT NOT NULL, -- Redundancia controlada para búsquedas rápidas
    Channel VARCHAR(20) NOT NULL, -- WHATSAPP, EMAIL, SMS
    TokenHash VARCHAR(256) NOT NULL, -- Por seguridad no guardar el token plano si es posible
    
    SentAt DATETIME2 DEFAULT GETDATE(),
    ExpiresAt DATETIME2 NOT NULL,
    ValidatedAt DATETIME2, -- NULL si no se ha validado
    
    AttemptCount INT DEFAULT 0, -- Contador de intentos
    IsSuccessful BIT DEFAULT 0,
    
    CONSTRAINT FK_Challenge_Request FOREIGN KEY (RequestID) REFERENCES CreditRequests(RequestID)
);

-- Índice para regla de "Bloqueo 24h por intentos fallidos"
CREATE INDEX IX_Security_Attempts ON SecurityChallenges(CustomerID, SentAt);

-- 5. EVALUACIÓN DE RIESGO Y ANTECEDENTES
-- Almacena resultados de Listas Restrictivas, Buró y Preselecta.
CREATE TABLE RiskAssessments (
    AssessmentID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RequestID BIGINT NOT NULL,
    
    -- Banderas de decisión
    RestrictiveListMatch BIT DEFAULT 0, -- Antecedentes Negativos
    BureauScore INT,
    PreselectaViable BIT DEFAULT 0, -- ¿Viable en preselecta?
    
    -- Datos específicos del flujo "Jubilados/Cotizantes"
    IsPensioner BIT, -- Mayor 75 años
    HasSocialSecurityHistory BIT, -- Cotiza o tiene historia
    
    DetailsJSON NVARCHAR(MAX), -- Respuesta completa del proveedor (JSON) para auditoría
    EvaluatedAt DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Risk_Request FOREIGN KEY (RequestID) REFERENCES CreditRequests(RequestID)
);

-- 6. BIOMETRÍA Y OCR
-- Soporta el flujo de Fábrica de Créditos (Fotos, Liveness, Comparación).
CREATE TABLE BiometricLogs (
    BiometricID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RequestID BIGINT NOT NULL,
    
    ProviderTransactionID VARCHAR(100), -- ID del proveedor biométrico
    VerificationType VARCHAR(20) NOT NULL, -- ONBOARDING (Nueva), AUTH (Selfie vs Stored)
    
    -- Resultados
    LivenessPassed BIT DEFAULT 0, -- Prueba de vida
    FaceMatchScore DECIMAL(5,2), -- % de coincidencia (Para flujo "Selfie anterior y actual igual")
    OCRMatchStatus VARCHAR(20), -- OK, DATA_MISMATCH, DOC_INVALID
    
    Attempts INT DEFAULT 1, -- Para controlar el ciclo de "Reintentar"
    ProcessStatus VARCHAR(20), -- SUCCESS, FAILED, MANUAL_REVIEW (3ra validación)
    
    CreatedAt DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Bio_Request FOREIGN KEY (RequestID) REFERENCES CreditRequests(RequestID)
);

-- 7. VALIDACIÓN DE CONTACTABILIDAD (UBICA)
-- Clasificación del cliente para el grupo A (Auto) o B (Manual).
CREATE TABLE ContactVerifications (
    VerificationID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RequestID BIGINT NOT NULL,
    
    UbicaScore VARCHAR(20), -- OK_UBICA_CEL, SIN_INFO, ETC.
    IsAutoActivatable BIT DEFAULT 0, -- Grupo A vs Grupo B
    
    -- Gestión Manual (Call Center)
    ManualVerificationStatus VARCHAR(20), -- PENDING, CONFIRMED, REJECTED
    AgentComments VARCHAR(500),
    
    VerifiedAt DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Contact_Request FOREIGN KEY (RequestID) REFERENCES CreditRequests(RequestID)
);


