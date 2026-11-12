-- 16 — Tables that feed the Looker Studio dashboard
-- Small, pre-aggregated tables keep the dashboard fast and the numbers identical to the analysis.

CREATE OR REPLACE TABLE `jump_ellie.painel_partidas` AS
SELECT * FROM `jump_ellie.partidas`;

CREATE OR REPLACE TABLE `jump_ellie.painel_kpis` AS
WITH duracao AS (
  SELECT DISTINCT PERCENTILE_CONT(duracao_s, 0.5) OVER () AS duracao_mediana_s
  FROM `jump_ellie.partidas`
  WHERE terminou
),
totais AS (
  SELECT
    COUNT(DISTINCT jogador_id) AS jogadores,
    COUNT(*) AS partidas,
    ROUND(100 * COUNTIF(ordem_na_sessao = 2) / COUNT(DISTINCT sessao_id), 1) AS pct_jogam_2a
  FROM `jump_ellie.partidas`
)
SELECT jogadores, partidas, ROUND(duracao_mediana_s, 1) AS duracao_mediana_s, pct_jogam_2a
FROM totais
CROSS JOIN duracao;

CREATE OR REPLACE TABLE `jump_ellie.painel_funil` AS
SELECT
  CASE evolucoes
    WHEN 0 THEN '1 - SPROUT'
    WHEN 1 THEN '2 - STALKER'
    WHEN 2 THEN '3 - HOVERCUKE'
    WHEN 3 THEN '4 - ZAPWING'
    WHEN 4 THEN '5 - OVERLORD'
  END AS fase,
  COUNT(*) AS morreram_nesta_fase,
  ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY evolucoes DESC) / SUM(COUNT(*)) OVER (), 1) AS pct_chegaram
FROM `jump_ellie.partidas`
WHERE terminou
GROUP BY evolucoes;

CREATE OR REPLACE TABLE `jump_ellie.painel_ab` AS
WITH por_jogador AS (
  SELECT DISTINCT
    jogador_id,
    variante,
    PERCENTILE_CONT(pontuacao_final, 0.5) OVER (PARTITION BY jogador_id) AS mediana_jogador
  FROM `jump_ellie.partidas`
  WHERE terminou
)
SELECT DISTINCT
  IF(variante = 'A', 'A - catnip 7 s', 'B - catnip 10 s') AS grupo,
  COUNT(*) OVER (PARTITION BY variante) AS jogadores,
  ROUND(PERCENTILE_CONT(mediana_jogador, 0.5) OVER (PARTITION BY variante)) AS pontuacao_mediana
FROM por_jogador;
