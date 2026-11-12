-- 09 — Match duration: quartiles and mean (finished matches only)

SELECT DISTINCT
  COUNT(*) OVER () AS partidas,
  PERCENTILE_CONT(duracao_s, 0.25) OVER () AS p25,
  PERCENTILE_CONT(duracao_s, 0.50) OVER () AS mediana,
  PERCENTILE_CONT(duracao_s, 0.75) OVER () AS p75,
  ROUND(AVG(duracao_s) OVER (), 1) AS media
FROM `jump_ellie.partidas`
WHERE terminou;
