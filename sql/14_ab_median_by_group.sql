-- 14 — A/B test: median score per player, by group
-- Decision metric (chosen before looking at the result): median final score per player.
-- Each player counts once, so a few very active players cannot dominate the group.

WITH por_jogador AS (
  SELECT DISTINCT
    jogador_id,
    variante,
    PERCENTILE_CONT(pontuacao_final, 0.5) OVER (PARTITION BY jogador_id) AS mediana_jogador
  FROM `jump_ellie.partidas`
  WHERE terminou
)
SELECT DISTINCT
  variante,
  COUNT(*) OVER (PARTITION BY variante) AS jogadores,
  PERCENTILE_CONT(mediana_jogador, 0.5) OVER (PARTITION BY variante) AS mediana_do_grupo
FROM por_jogador
ORDER BY variante;
