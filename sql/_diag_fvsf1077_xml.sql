SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @CNS VARCHAR(20) = N'2500001087';
DECLARE @xml XML;

SELECT TOP 1 @xml = CAST(xml_solicitud AS XML)
FROM dbo.FDIANR
WHERE CNSDOCUMENTO = @CNS AND METODO = N'SendBillSync' AND TIPO = N'FV'
ORDER BY ITEM DESC;

WITH XMLNAMESPACES (
  'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' AS inv,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2' AS cac,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc
)
SELECT
  @xml.value('(/inv:Invoice/cbc:ID)[1]', 'varchar(30)') AS XML_ID,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:LineExtensionAmount)[1]', 'decimal(18,2)') AS LineExtensionAmount,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount)[1]', 'decimal(18,2)') AS TaxInclusiveAmount,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount)[1]', 'decimal(18,2)') AS PayableAmount,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PrepaidAmount)[1]', 'decimal(18,2)') AS PrepaidAmount;

WITH XMLNAMESPACES (
  'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' AS inv,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2' AS cac,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc
)
SELECT
  L.i.value('(cbc:ID)[1]', 'varchar(10)') AS LINE_ID,
  L.i.value('(cbc:InvoicedQuantity)[1]', 'decimal(18,2)') AS QTY,
  L.i.value('(cac:Price/cbc:PriceAmount)[1]', 'decimal(18,2)') AS PRICE,
  L.i.value('(cbc:LineExtensionAmount)[1]', 'decimal(18,2)') AS LINE_EXT
FROM @xml.nodes('/inv:Invoice/cac:InvoiceLine') AS L(i);

SELECT COUNT(*) AS FILAS_FDIANR, MIN(ITEM) MIN_IT, MAX(ITEM) MAX_IT
FROM dbo.FDIANR WHERE CNSDOCUMENTO = @CNS;
