-- 01 — Events by type (validation against the pivot table in Sheets)

SELECT evento, COUNT(*) AS qtd
FROM `jump_ellie.eventos_raw`
WHERE fonte = 'simulado'
GROUP BY evento
ORDER BY qtd DESC;
