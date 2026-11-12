-- 11 — Which villain causes each death

SELECT
  vilao_que_matou,
  COUNT(*) AS mortes,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_mortes
FROM `jump_ellie.partidas`
WHERE terminou
GROUP BY vilao_que_matou
ORDER BY mortes DESC;
