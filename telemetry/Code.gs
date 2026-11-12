/**
 * Jump Ellie — receptor de telemetria
 * Recebe eventos do jogo (POST) e grava na aba "eventos" da planilha.
 *
 * Formato aceito (corpo da requisição em JSON, enviado como text/plain):
 *   { "eventos": [ {evento}, {evento}, ... ] }   // lote, até 200 eventos
 *   ou um único {evento}
 *
 * Campos de cada evento:
 *   evento      partida_inicio | morte | catnip | evolucao | abandono   (obrigatório)
 *   jogador_id  id anônimo, 8 a 40 caracteres [a-z0-9-]               (obrigatório)
 *   partida_id  id da partida, mesmo formato                           (obrigatório)
 *   sessao_id   id da sessão (abertura do jogo), mesmo formato         (obrigatório)
 *   variante    A | B  (teste A/B da duração do catnip)                (obrigatório)
 *   fonte       real | simulado | teste                                (obrigatório)
 *   ts          data/hora do jogo em ISO 8601 (ex.: 2026-10-26T13:02:11.512Z)
 *   pontuacao   número inteiro 0 a 1.000.000
 *   duracao_s   segundos desde o início da partida, 0 a 36.000
 *   vilao       SPROUT | STALKER | HOVERCUKE | ZAPWING | OVERLORD  (quem matou / nova evolução)
 *   nivel       mesma lista: evolução em que a partida estava no momento do evento
 *   versao      versão do jogo, até 20 caracteres (ex.: 1.1.0)
 *
 * Datas são gravadas como texto em UTC ("2026-10-26 13:02:11.512"), formato que o
 * BigQuery lê direto como TIMESTAMP.
 */

const ABA = 'eventos';

const COLUNAS = [
  'recebido_em', 'ts_cliente', 'fonte', 'versao', 'variante',
  'jogador_id', 'sessao_id', 'partida_id',
  'evento', 'pontuacao', 'duracao_s', 'vilao', 'nivel'
];

const EVENTOS = ['partida_inicio', 'morte', 'catnip', 'evolucao', 'abandono'];
const VILOES = ['SPROUT', 'STALKER', 'HOVERCUKE', 'ZAPWING', 'OVERLORD'];
const FONTES = ['real', 'simulado', 'teste'];
const VARIANTES = ['A', 'B'];
const ID_OK = /^[a-z0-9-]{8,40}$/;

const MAX_LOTE = 200;            // eventos por requisição
const MAX_POR_JOGADOR_MIN = 300; // eventos por jogador por minuto (anti-abuso)

function doPost(e) {
  try {
    const corpo = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    const lista = Array.isArray(corpo.eventos) ? corpo.eventos : [corpo];

    if (lista.length === 0 || lista.length > MAX_LOTE) {
      return resposta_({ ok: false, erro: 'lote vazio ou grande demais' });
    }

    const agora = new Date();
    const linhas = [];
    let rejeitados = 0;

    for (const ev of lista) {
      const linha = validar_(ev, agora);
      if (linha) linhas.push(linha); else rejeitados++;
    }

    if (linhas.length && !dentroDoLimite_(linhas[0][5], linhas.length)) {
      return resposta_({ ok: false, erro: 'limite de envio excedido' });
    }

    if (linhas.length) gravar_(linhas);
    return resposta_({ ok: true, gravados: linhas.length, rejeitados: rejeitados });
  } catch (err) {
    return resposta_({ ok: false, erro: 'corpo inválido' });
  }
}

/** Permite testar no navegador se o app da web está no ar. */
function doGet() {
  return resposta_({ ok: true, servico: 'jump-ellie-telemetria' });
}

/** Devolve a linha pronta para a planilha, ou null se o evento for inválido. */
function validar_(ev, agora) {
  if (!ev || typeof ev !== 'object') return null;

  if (!EVENTOS.includes(ev.evento)) return null;
  if (!FONTES.includes(ev.fonte)) return null;
  if (!VARIANTES.includes(ev.variante)) return null;
  for (const campo of ['jogador_id', 'sessao_id', 'partida_id']) {
    if (typeof ev[campo] !== 'string' || !ID_OK.test(ev[campo])) return null;
  }

  const pontuacao = inteiro_(ev.pontuacao, 0, 1000000);
  const duracao = numero_(ev.duracao_s, 0, 36000);
  const vilao = VILOES.includes(ev.vilao) ? ev.vilao : '';
  const nivel = VILOES.includes(ev.nivel) ? ev.nivel : '';

  // Regras por tipo de evento
  if (ev.evento === 'morte' && (pontuacao === '' || duracao === '' || !vilao)) return null;
  if (ev.evento === 'evolucao' && !vilao) return null;

  let ts = '';
  if (typeof ev.ts === 'string') {
    const d = new Date(ev.ts);
    if (!isNaN(d)) ts = dataUtc_(d);
  }

  const versao = typeof ev.versao === 'string' ? ev.versao.slice(0, 20) : '';

  return [
    dataUtc_(agora), ts, ev.fonte, versao, ev.variante,
    ev.jogador_id, ev.sessao_id, ev.partida_id,
    ev.evento, pontuacao, duracao, vilao, nivel
  ];
}

function dataUtc_(d) {
  return Utilities.formatDate(d, 'UTC', 'yyyy-MM-dd HH:mm:ss.SSS');
}

function inteiro_(v, min, max) {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : '';
}

function numero_(v, min, max) {
  const n = Number(v);
  return Number.isFinite(n) && n >= min && n <= max ? Math.round(n * 100) / 100 : '';
}

/** Conta eventos por jogador em janelas de 1 minuto. */
function dentroDoLimite_(jogadorId, qtd) {
  const cache = CacheService.getScriptCache();
  const chave = 'lim_' + jogadorId + '_' + Math.floor(Date.now() / 60000);
  const atual = Number(cache.get(chave) || 0) + qtd;
  if (atual > MAX_POR_JOGADOR_MIN) return false;
  cache.put(chave, String(atual), 120);
  return true;
}

function gravar_(linhas) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const aba = obterAba_();
    aba.getRange(aba.getLastRow() + 1, 1, linhas.length, COLUNAS.length).setValues(linhas);
  } finally {
    lock.releaseLock();
  }
}

function obterAba_() {
  const planilha = SpreadsheetApp.getActiveSpreadsheet();
  let aba = planilha.getSheetByName(ABA);
  if (!aba) {
    aba = planilha.insertSheet(ABA);
    aba.getRange(1, 1, 1, COLUNAS.length).setValues([COLUNAS]).setFontWeight('bold');
    aba.setFrozenRows(1);
    aba.getRange('A:B').setNumberFormat('@');   // datas como texto, sem conversão do Sheets
  }
  return aba;
}

function resposta_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Teste local: rode esta função pelo editor do Apps Script.
 * Grava 3 eventos com fonte "teste" e 1 inválido (que deve ser rejeitado).
 */
function testarRecebimento() {
  const id = 'teste-' + Utilities.getUuid().slice(0, 8);
  const corpo = {
    eventos: [
      { evento: 'partida_inicio', fonte: 'teste', variante: 'A', versao: '1.1.0',
        jogador_id: id, sessao_id: id + '-s1', partida_id: id + '-p1',
        ts: new Date().toISOString() },
      { evento: 'evolucao', fonte: 'teste', variante: 'A', versao: '1.1.0',
        jogador_id: id, sessao_id: id + '-s1', partida_id: id + '-p1',
        pontuacao: 400, duracao_s: 21.4, vilao: 'STALKER', nivel: 'STALKER', ts: new Date().toISOString() },
      { evento: 'morte', fonte: 'teste', variante: 'A', versao: '1.1.0',
        jogador_id: id, sessao_id: id + '-s1', partida_id: id + '-p1',
        pontuacao: 730, duracao_s: 38.9, vilao: 'SPROUT', nivel: 'STALKER', ts: new Date().toISOString() },
      { evento: 'pulo_infinito', fonte: 'teste', variante: 'A',
        jogador_id: id, sessao_id: id, partida_id: id }
    ]
  };
  const r = doPost({ postData: { contents: JSON.stringify(corpo) } });
  Logger.log(r.getContent()); // esperado: {"ok":true,"gravados":3,"rejeitados":1}
}
