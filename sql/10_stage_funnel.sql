-- 10 — Stage funnel: where matches end

SELECT
  CASE evolucoes
    WHEN 0 THEN '1 - SPROUT'
    WHEN 1 THEN '2 - STALKER'
    WHEN 2 THEN '3 - HOVERCUKE'
    WHEN 3 THEN '4 - ZAPWING'
    WHEN 4 THEN '5 - OVERLORD'
  END AS fase,
  COUNT(*) AS morreram_nesta_fase,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_morreram_aqui,
  SUM(COUNT(*)) OVER (ORDER BY evolucoes DESC) AS chegaram_a_esta_fase,
  ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY evolucoes DESC) / SUM(COUNT(*)) OVER (), 1) AS pct_chegaram
FROM `jump_ellie.partidas`
WHERE terminou
GROUP BY evolucoes
ORDER BY evolucoes;
