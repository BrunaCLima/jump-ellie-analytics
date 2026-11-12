-- 13 — First match of players who quit vs players who played again (same session)

WITH primeira AS (
  SELECT sessao_id, duracao_s, pontuacao_final
  FROM `jump_ellie.partidas`
  WHERE ordem_na_sessao = 1
),
voltou AS (
  SELECT sessao_id, MAX(ordem_na_sessao) > 1 AS jogou_de_novo
  FROM `jump_ellie.partidas`
  GROUP BY sessao_id
),
base AS (
  SELECT v.jogou_de_novo, p.duracao_s, p.pontuacao_final
  FROM primeira p
  JOIN voltou v USING (sessao_id)
)
SELECT DISTINCT
  jogou_de_novo,
  COUNT(*) OVER (PARTITION BY jogou_de_novo) AS sessoes,
  PERCENTILE_CONT(duracao_s, 0.5) OVER (PARTITION BY jogou_de_novo) AS duracao_mediana_1a,
  PERCENTILE_CONT(pontuacao_final, 0.5) OVER (PARTITION BY jogou_de_novo) AS pontuacao_mediana_1a
FROM base;
