"""
Jump Ellie — simulador de jogadores

Gera eventos no mesmo formato que o jogo envia (fonte = "simulado"), para treinar
a análise enquanto os dados reais não chegam. Saída: eventos_simulados.csv,
pronto para importar na aba "eventos" da planilha.

Como funciona (resumo para o README do case):
- Cada jogador tem um perfil (iniciante, casual, bom, expert) que define a chance
  de morrer em cada obstáculo, quantos itens coleta e a vontade de continuar jogando.
- A partida avança obstáculo por obstáculo, com as mesmas regras do jogo:
  velocidade cresce com o tempo, vilões evoluem por pontuação (400, 1200, 2500, 4500),
  o vilão mais novo aparece com peso 1,6 e o catnip aparece no máximo a cada 14 s.
- Variante A = catnip de 7 s, B = 10 s. Com o catnip ativo a Ellie não morre.
- Depois de cada morte o jogador decide se joga de novo (menos chance se foi mal).
- Alguns jogadores voltam em outros dias (novas sessões).

Uso:  python simulador.py            (300 jogadores, semente 42)
      python simulador.py 500 7      (500 jogadores, semente 7)
"""
import csv
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone

N_JOGADORES = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SEMENTE = int(sys.argv[2]) if len(sys.argv) > 2 else 42
rnd = random.Random(SEMENTE)

COLUNAS = ['recebido_em', 'ts_cliente', 'fonte', 'versao', 'variante',
           'jogador_id', 'sessao_id', 'partida_id',
           'evento', 'pontuacao', 'duracao_s', 'vilao', 'nivel']

# mesmas constantes do jogo
BASEV, MAXV = 150, 420
EVO = [('SPROUT', 0), ('STALKER', 400), ('HOVERCUKE', 1200), ('ZAPWING', 2500), ('OVERLORD', 4500)]
CATNIP_S = {'A': 7, 'B': 10}

# chance base de morrer ao passar por cada forma de vilão (sem catnip)
PERIGO = {'SPROUT': 0.020, 'STALKER': 0.035, 'HOVERCUKE': 0.075, 'ZAPWING': 0.050, 'OVERLORD': 0.045}

PERFIS = {
    #            peso  perigo  coleta  pega_catnip  continua  volta_outro_dia
    'iniciante': (0.30, 2.10,   0.45,   0.50,        0.55,     0.15),
    'casual':    (0.40, 1.30,   0.60,   0.65,        0.65,     0.30),
    'bom':       (0.22, 0.75,   0.75,   0.80,        0.75,     0.45),
    'expert':    (0.08, 0.40,   0.90,   0.90,        0.80,     0.60),
}

INICIO = datetime(2026, 10, 27, tzinfo=timezone.utc)
DIAS = 14


def fmt(d):
    """Texto em UTC no formato que o BigQuery lê como TIMESTAMP."""
    return d.strftime('%Y-%m-%d %H:%M:%S.') + f'{d.microsecond // 1000:03d}'


def nivel(score):
    lv = 0
    for i, (_, at) in enumerate(EVO):
        if score >= at:
            lv = i
    return lv


def sorteia_vilao(lv):
    nomes = [n for n, _ in EVO[:lv + 1]]
    pesos = [1.6 if (i == lv and lv > 0) else 1.0 for i in range(len(nomes))]
    return rnd.choices(nomes, pesos)[0]


def partida(perfil, variante):
    """Simula uma partida. Devolve a lista de (segundos, evento, pontuacao, vilao, nivel)."""
    _, mult, coleta, pega, _, _ = PERFIS[perfil]
    eventos = [(0.0, 'partida_inicio', 0, '', 'SPROUT')]
    t, score, speed, power, ultimo_poder, lv = 0.0, 0.0, BASEV, 0.0, -99.0, 0
    vai_abandonar = rnd.random() < 0.03           # sai pelo menu no meio
    fecha_aba = rnd.random() < 0.02               # fecha o jogo: partida sem fim registrado
    limite = rnd.uniform(5, 60)
    while True:
        gap = speed * rnd.uniform(0.85, 1.45) + 80
        dt = gap / speed
        t += dt
        speed = min(MAXV, BASEV + t * 3.2)
        power = max(0.0, power - dt)

        # pontos: distância + bolinhas + peixe (proporcional ao que o perfil coleta)
        itens = 0.6 * 70 + 0.5 * max(0, gap - 65) / 11 * 10 + 0.18 * 50
        score += gap * 0.06 + itens * coleta * rnd.uniform(0.7, 1.3)

        novo = nivel(score)
        while lv < novo:
            lv += 1
            eventos.append((t, 'evolucao', int(score), EVO[lv][0], EVO[lv][0]))

        # catnip: no máximo a cada 14 s, como no jogo
        if t - ultimo_poder > 14 and power <= 0 and rnd.random() < 0.22:
            ultimo_poder = t
            if rnd.random() < pega:
                power = CATNIP_S[variante]
                score += 50
                eventos.append((t, 'catnip', int(score), '', EVO[lv][0]))

        if (vai_abandonar or fecha_aba) and t > limite:
            if vai_abandonar:
                eventos.append((t, 'abandono', int(score), '', EVO[lv][0]))
            return eventos, int(score), t

        vilao = sorteia_vilao(lv)
        if power > 0:
            score += 100 if vilao != 'ZAPWING' else 200 * rnd.choice([1, 1, 2, 4])
            continue
        p = PERIGO[vilao] * mult * (speed / BASEV) ** 0.6
        if rnd.random() < min(p, 0.9):
            eventos.append((t, 'morte', int(score), vilao, EVO[lv][0]))
            return eventos, int(score), t


def main():
    linhas = []
    nomes = list(PERFIS)
    pesos = [PERFIS[n][0] for n in nomes]
    for _ in range(N_JOGADORES):
        perfil = rnd.choices(nomes, pesos)[0]
        _, _, _, _, continua, volta = PERFIS[perfil]
        jogador = str(uuid.UUID(int=rnd.getrandbits(128)))
        variante = rnd.choice('AB')

        # dias em que joga: o primeiro e, com alguma chance, outros depois
        dia0 = rnd.randrange(DIAS)
        dias = [dia0]
        d = dia0
        while rnd.random() < volta:
            d += rnd.randint(1, 4)
            if d >= DIAS:
                break
            dias.append(d)

        melhor = 0
        for dia in dias:
            sessao = str(uuid.UUID(int=rnd.getrandbits(128)))
            relogio = INICIO + timedelta(days=dia, hours=rnd.uniform(9, 23.5))
            n = 0
            while True:
                n += 1
                partida_id = str(uuid.UUID(int=rnd.getrandbits(128)))
                eventos, score, dur = partida(perfil, variante)
                for seg, ev, pts, vilao, niv in eventos:
                    ts = relogio + timedelta(seconds=seg)
                    rec = ts + timedelta(seconds=rnd.uniform(0.2, 2.0))
                    linhas.append([fmt(rec), fmt(ts), 'simulado', '1.1.0', variante,
                                   jogador, sessao, partida_id,
                                   ev, pts, round(seg, 2), vilao, niv])
                if eventos[-1][1] != 'morte':
                    break                          # abandonou ou fechou: fim da sessão
                relogio += timedelta(seconds=dur + 4 + rnd.uniform(1, 8))
                chance = continua - (0.12 if score < 0.5 * melhor else 0) - 0.02 * n
                melhor = max(melhor, score)
                if n >= 30 or rnd.random() > chance:
                    break

    linhas.sort(key=lambda l: l[0])
    with open('eventos_simulados.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(COLUNAS)
        w.writerows(linhas)
    print(f'{len(linhas)} eventos de {N_JOGADORES} jogadores -> eventos_simulados.csv')


if __name__ == '__main__':
    main()
