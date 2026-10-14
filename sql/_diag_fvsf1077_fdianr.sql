SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @xml XML;
SELECT TOP 1 @xml = CAST(xml_solicitud AS XML)
FROM dbo.FDIANR WHERE CNSDOCUMENTO = N'2500001086' AND METODO = N'SendBillSync' ORDER BY ITEM DESC;

WITH XMLNAMESPACES (
  'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' AS inv,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2' AS cac
)
SELECT N'1086' AS CNS,
  @xml.value('(/inv:Invoice/cbc:ID)[1]', 'varchar(30)') AS XML_ID,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount)[1]', 'decimal(18,2)') AS Payable;

SELECT TOP 1 @xml = CAST(xml_solicitud AS XML)
FROM dbo.FDIANR WHERE CNSDOCUMENTO = N'2500001087' AND METODO = N'SendBillSync' ORDER BY ITEM DESC;

WITH XMLNAMESPACES (
  'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2' AS inv,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2' AS cbc,
  'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2' AS cac
)
SELECT N'1087' AS CNS,
  @xml.value('(/inv:Invoice/cbc:ID)[1]', 'varchar(30)') AS XML_ID,
  @xml.value('(/inv:Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount)[1]', 'decimal(18,2)') AS Payable;

SELECT TOP 5 FT.N_FACTURA, FT.CNSFCT, FT.VR_TOTAL, FT.CUFE
FROM dbo.FTR FT WHERE FT.CUFE = (
  SELECT CUFE FROM FTR WHERE N_FACTURA = N'FVSF1077'
);

SELECT COUNT(*) AS XML_CON_59200
FROM dbo.FDIANR D
WHERE D.METODO = N'SendBillSync' AND D.TIPO = N'FV'
  AND CAST(D.xml_solicitud AS NVARCHAR(MAX)) LIKE N'%59200%'
  AND D.FECHA >= '2026-09-08';
