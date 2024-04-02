/*** SEÇÃO 1 - EXPLORAÇÃO PRELIMINAR ***/

--Todos os códigos são iguais
SELECT *
FROM ocorrencia_clean
WHERE codigo_ocorrencia <> codigo_ocorrencia1 OR codigo_ocorrencia <> codigo_ocorrencia2 OR codigo_ocorrencia <> codigo_ocorrencia3 OR codigo_ocorrencia <> codigo_ocorrencia4;


-- Múltiplas aeronaves possuem o mesmo código de ocorrência (possivel colisão, encontro, etc)
SELECT COUNT(codigo_ocorrencia2)
FROM aeronave
GROUP BY codigo_ocorrencia2
HAVING COUNT(codigo_ocorrencia2) > 1
;

--Identificando quais códigos estão duplicados
SELECT codigo_ocorrencia2, COUNT(codigo_ocorrencia2)
FROM aeronave
GROUP BY codigo_ocorrencia2
HAVING COUNT(codigo_ocorrencia2) > 1;


-- Checando o motivo da ocorrência dos duplicados, evidentemente são ocorrências que incluem mais de uma aeronave (como colisões)
SELECT *
FROM ocorrencia_tipo
WHERE codigo_ocorrencia1 IN (SELECT codigo_ocorrencia2
FROM aeronave
GROUP BY codigo_ocorrencia2
HAVING COUNT(codigo_ocorrencia2) > 1)

-- Maiores causas de morte
SELECT ocorrencia_tipo, COUNT(ocorrencia_tipo) AS total
FROM aeronave aer
LEFT OUTER JOIN ocorrencia_tipo ocorr
	ON aer.codigo_ocorrencia2 = ocorr.codigo_ocorrencia1
WHERE aeronave_fatalidades_total > 0
GROUP BY ocorrencia_tipo
ORDER BY total DESC;


-- Curiosamente, nenhuma morte por colisão com ave 
SELECT ocorrencia_tipo, aeronave_fatalidades_total
FROM aeronave aer
RIGHT OUTER JOIN ocorrencia_tipo ocorr
	ON aer.codigo_ocorrencia2 = ocorr.codigo_ocorrencia1
WHERE ocorrencia_tipo LIKE '% COM AVE' AND aeronave_fatalidades_total > 0;


-- Curiosamente muitas ocorrências possuem diversas "ocorrencias_tipo", como por exemplo excursão de pista + colisão com obstáculo (81712), ou ainda falha
-- de motor em voo + pouso em local não previsto (81688) 
SELECT *
FROM ocorrencia_tipo
WHERE codigo_ocorrencia1 IN (SELECT codigo_ocorrencia1
FROM ocorrencia_tipo
GROUP BY codigo_ocorrencia1
HAVING COUNT(codigo_ocorrencia1) > 1
)

-------------------------------------------------------------------------------------------------

/*** SEÇÃO 2 - INVESTIGANDO FATALIDADES E TAXA DE MORTALIDADE ***/

/*** 2.1 - Qual tipo de ocorrencia é mais mortal? (Normalizado pelo total de ocorrencias) ***/

SELECT ocorrencia_tipo, COUNT(ocorrencia_tipo) AS total
FROM ocorrencia_tipo
GROUP BY ocorrencia_tipo
ORDER BY total DESC;

--número(ID) das ocorrências em que ocorreu fatalidades
SELECT codigo_ocorrencia2
FROM aeronave
WHERE aeronave_fatalidades_total > 0
ORDER BY aeronave_fatalidades_total DESC;

--causa das ocorrências em que ocorreu fatalidades
SELECT ocorrencia_tipo
FROM ocorrencia_tipo
WHERE codigo_ocorrencia1 IN (SELECT codigo_ocorrencia2
FROM aeronave
WHERE aeronave_fatalidades_total > 0);

--causa das mortes
SELECT ocorrencia_tipo, COUNT(ocorrencia_tipo) as total_com_fatalidades
FROM ocorrencia_tipo
WHERE codigo_ocorrencia1 IN (SELECT codigo_ocorrencia2
FROM aeronave
WHERE aeronave_fatalidades_total > 0)
GROUP BY ocorrencia_tipo
ORDER BY total_com_fatalidades DESC;

--fator contribuinte
SELECT fator_nome, COUNT(fator_nome) AS total
FROM fator_contribuinte
WHERE codigo_ocorrencia3 IN (SELECT codigo_ocorrencia2
FROM aeronave
WHERE aeronave_fatalidades_total > 0)
GROUP BY fator_nome
ORDER BY total DESC;

--------------Criando temp tables para análise------------------------------

DROP TABLE IF EXISTS #com_fatal
CREATE TABLE #com_fatal (
ocorrencia_tipo varchar(50),
total_com_fatalidades int
)

INSERT INTO #com_fatal
SELECT ocorrencia_tipo, COUNT(ocorrencia_tipo) as total_com_fatalidades
FROM ocorrencia_tipo
WHERE codigo_ocorrencia1 IN (SELECT codigo_ocorrencia2
FROM aeronave
WHERE aeronave_fatalidades_total > 0)
GROUP BY ocorrencia_tipo

----------

DROP TABLE IF EXISTS #ocorr_total
CREATE TABLE #ocorr_total (
ocorrencia_tipo varchar(100),
total int
)

INSERT INTO #ocorr_total
SELECT ocorrencia_tipo, COUNT(ocorrencia_tipo) as total
FROM ocorrencia_tipo
GROUP BY ocorrencia_tipo

----------

SELECT *
FROM #ocorr_total

SELECT *, ROUND(CAST(total_com_fatalidades AS FLOAT)/CAST(total AS FLOAT),2) AS mortalidade
FROM #ocorr_total tot
JOIN #com_fatal fat
	ON tot.ocorrencia_tipo = fat.ocorrencia_tipo
ORDER BY mortalidade DESC

/*** 2.2 - Mortalidades por tipo de veículo normalizado pelo total de ocorrências ***/

-- número de ocorrências em que ocorreu fatalidade por tipo de veículo
SELECT aeronave_tipo_veiculo, COUNT(aeronave_tipo_veiculo) total
FROM aeronave
WHERE aeronave_fatalidades_total > 0
GROUP BY aeronave_tipo_veiculo
ORDER BY total DESC;

-- ocorr total por veículo
SELECT aeronave_tipo_veiculo, COUNT(aeronave_tipo_veiculo) total
FROM aeronave
GROUP BY aeronave_tipo_veiculo
ORDER BY total DESC;


--------------Criando temp tables para análise------------------------------
DROP TABLE IF EXISTS #ocorr_fatal_veiculo	
CREATE TABLE #ocorr_fatal_veiculo (
tipo_veiculo varchar(50),
total_fatal float
)

INSERT INTO #ocorr_fatal_veiculo
SELECT aeronave_tipo_veiculo, COUNT(aeronave_tipo_veiculo) total
FROM aeronave
WHERE aeronave_fatalidades_total > 0
GROUP BY aeronave_tipo_veiculo

--------

DROP TABLE IF EXISTS #ocorr_total_veiculo	
CREATE TABLE #ocorr_total_veiculo (
tipo_veiculo varchar(50),
total float
)

INSERT INTO  #ocorr_total_veiculo
SELECT aeronave_tipo_veiculo, COUNT(aeronave_tipo_veiculo) total
FROM aeronave
GROUP BY aeronave_tipo_veiculo
ORDER BY total DESC

-------

SELECT * , ROUND(total_fatal/total,2) AS mortalidade
FROM #ocorr_fatal_veiculo fat
JOIN #ocorr_total_veiculo tot
	ON fat.tipo_veiculo = tot.tipo_veiculo
ORDER BY mortalidade DESC

/*** 2.3 - Mortalidade por fabricante normalizado pelo número de ocorrências ***/

--ocorrências com fatalidades por fabricante
SELECT aeronave_fabricante, COUNT(aeronave_fabricante) total
FROM aeronave
WHERE aeronave_fatalidades_total > 0
GROUP BY aeronave_fabricante
ORDER BY total DESC;

--ocorrências totais por fabricante
SELECT aeronave_fabricante, COUNT(aeronave_fabricante) total
FROM aeronave
GROUP BY aeronave_fabricante
ORDER BY total DESC;

--------------Criando temp tables para análise ------------------------------

DROP TABLE IF EXISTS #ocorr_fatal_fabr	
CREATE TABLE #ocorr_fatal_fabr (
fabricante varchar(50),
total_fatal float
)

INSERT INTO #ocorr_fatal_fabr
SELECT aeronave_fabricante, COUNT(aeronave_fabricante) total
FROM aeronave
WHERE aeronave_fatalidades_total > 0
GROUP BY aeronave_fabricante;

----------

DROP TABLE IF EXISTS #ocorr_total_fabr
CREATE TABLE #ocorr_total_fabr (
fabricante varchar(50),
total float
)

INSERT INTO  #ocorr_total_fabr
SELECT aeronave_fabricante, COUNT(aeronave_fabricante) total
FROM aeronave
GROUP BY aeronave_fabricante;

------------

SELECT * , ROUND(total_fatal/total,2) AS mortalidade
FROM #ocorr_fatal_fabr fat
JOIN #ocorr_total_fabr tot
	ON fat.fabricante = tot.fabricante
ORDER BY mortalidade DESC