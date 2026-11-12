-- 15 — A/B test: Mann-Whitney U test written in SQL
-- Compares every A player with every B player (CROSS JOIN) and counts how often B scores higher.
-- z = (U - nA*nB/2) / sqrt(nA*nB*(nA+nB+1)/12). |z| < 1.96 means not significant at 95%.

WITH por_jogador AS (
  SELECT DISTINCT
    jogador_id,
    variante,
    PERCENTILE_CONT(pontuacao_final, 0.5) OVER (PARTITION BY jogador_id) AS mediana_jogador
  FROM `jump_ellie.partidas`
  WHERE terminou
),
pares AS (
  SELECT
    COUNT(DISTINCT a.jogador_id) AS n_a,
    COUNT(DISTINCT b.jogador_id) AS n_b,
    COUNT(*) AS total_pares,
    SUM(CASE
          WHEN b.mediana_jogador > a.mediana_jogador THEN 1
          WHEN b.mediana_jogador = a.mediana_jogador THEN 0.5
          ELSE 0
        END) AS vitorias_b
  FROM por_jogador a
  CROSS JOIN por_jogador b
  WHERE a.variante = 'A' AND b.variante = 'B'
)
SELECT
  n_a,
  n_b,
  ROUND(100 * vitorias_b / total_pares, 1) AS pct_pares_b_ganha,
  ROUND((vitorias_b - total_pares / 2) / SQRT(n_a * n_b * (n_a + n_b + 1) / 12), 2) AS z
FROM pares;
