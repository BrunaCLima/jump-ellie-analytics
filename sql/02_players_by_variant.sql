-- 02 — Players per A/B variant (input for the SRM check)

SELECT variante, COUNT(DISTINCT jogador_id) AS jogadores
FROM `jump_ellie.eventos_raw`
WHERE fonte = 'simulado'
GROUP BY variante;
