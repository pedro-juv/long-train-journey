"""Simulação da Fase 1B: economia da 1A (igual ao balance.gd) + componentes e manutenção."""
import math, copy

ECON = dict(
    producers=[("foguista", 1.0, 15.0, -1), ("carvoaria", 6.0, 250.0, -1), ("mina", 60.0, 4000.0, 0)],
    growth=1.32, milestones=(10, 25, 50), eq_cost={"foguista": 150, "carvoaria": 2500, "mina": 40000},
    click_costs=(50, 500, 5000), station_costs=(1500, 60000, 600000, 3e6),
    stations=(3500, 7000, 14000, 28000), init=20.0,
)

def speed_of(p): return 4 + 2 * max(p, 0) ** 0.35

class Comp:
    def __init__(s, name, kind, life, unlock, reinforce_cost):
        s.name, s.kind, s.base_life, s.unlock, s.rcost = name, kind, life, unlock, reinforce_cost
        s.integrity = 1.0; s.level = 0; s.active = False; s.failures = 0
    def life(s, P): return s.base_life * P["life_mult"] ** s.level
    def reinforce_cost(s, P): return round(s.rcost * P["reinforce_growth"] ** s.level)

def run(P, cps=1.0, style="cuidadoso", T=3000.0, dt=0.1, components=True):
    E = ECON
    lv = {n: 0 for n, *_ in E["producers"]}; eq = set(); click_lvl = 0; glob = 1.0; st_bought = set()
    stock = E["init"]; dist = 0.0; t = 0.0; reached = []; seg_end = E["stations"][0]
    comps = [Comp(*c) for c in P["components"]] if components else []
    stop_left = 0.0; stopped_time = 0.0; repairs = 0; repair_spent = 0.0; tools = False
    click_acc = 0.0; per_min_fail = [0] * 60

    def prod_of(n):
        out = dict((a, b) for a, b, *_ in E["producers"])[n]
        m = 1.0
        for ms in E["milestones"]:
            if lv[n] >= ms: m *= 2
        if n in eq: m *= 2
        return lv[n] * out * m * glob
    def total(): return sum(prod_of(n) for n in lv)
    def unlocked(n):
        u = [x[3] for x in E["producers"] if x[0] == n][0]
        return u < 0 or len(reached) > u

    while t < T and len(reached) < len(E["stations"]):
        prod = total()
        # --- compras da economia (melhor retorno), igual ao teste da 1A
        best = None
        for n, out, base, u in E["producers"]:
            if not unlocked(n): continue
            c = round(base * E["growth"] ** lv[n]); before = total(); lv[n] += 1; g = total() - before; lv[n] -= 1
            if best is None or c / g < best[0]: best = (c / g, c, ("lvl", n))
            if lv[n] > 0 and n not in eq:
                g = prod_of(n); cc = E["eq_cost"][n]
                if c and cc / g < best[0]: best = (cc / g, cc, ("eq", n))
        if click_lvl < 3 and cps > 0:
            g = cps * (2 ** click_lvl); c = E["click_costs"][click_lvl]
            if c / g < best[0]: best = (c / g, c, ("click", None))
        for i in range(len(reached)):
            if i not in st_bought:
                c = E["station_costs"][i]; g = prod * 0.5
                if g > 0 and c / g < best[0]: best = (c / g, c, ("st", i))
        if components and P.get("tools_cost") and len(reached) > P["tools_station"] and not tools and style == "cuidadoso":
            if stock >= P["tools_cost"] and P["tools_cost"] <= 40 * prod:
                stock -= P["tools_cost"]; tools = True; continue
        # --- manutenção (jogador cuidadoso)
        if components and style == "cuidadoso":
            acted = False
            for c in comps:
                if not c.active: continue
                rc = c.reinforce_cost(P)
                if stock >= rc and rc <= P["reinforce_budget_s"] * prod:
                    stock -= rc; c.level += 1; acted = True; break
                if c.integrity < 0.2:
                    cost = P["repair_seconds"] * prod * (1 - c.integrity)
                    if stock >= cost and stop_left <= 0:
                        stock -= cost; repair_spent += cost; c.integrity = 1.0; repairs += 1; acted = True; break
            if acted: continue
        if best and stock >= best[1]:
            stock -= best[1]; k, n = best[2]
            if k == "lvl": lv[n] += 1
            elif k == "eq": eq.add(n)
            elif k == "click": click_lvl += 1
            else: st_bought.add(n); glob *= 1.5
            continue
        # --- tempo passa
        if cps > 0:
            click_acc += dt
            while click_acc >= 1 / cps: click_acc -= 1 / cps; stock += 2 ** click_lvl
        stock += prod * dt
        if stop_left > 0:
            stop_left -= dt; stopped_time += dt
        else:
            v = speed_of(prod); m = v * dt
            stock -= min(stock, m * 0.1); dist += m
            for c in comps:
                if not c.active: continue
                wear = (m if c.kind == "dist" else dt) / c.life(P)
                c.integrity -= wear
                if c.integrity <= 0:
                    c.integrity = 1.0; c.failures += 1
                    stop_left += P["maint_seconds"] * (P["tools_mult"] if tools else 1.0)
                    per_min_fail[min(59, int(t // 60))] += 1
            if dist >= seg_end:
                reached.append(t); i = len(reached)
                for c in comps:
                    if c.unlock == i - 1: c.active = True
                if i < len(E["stations"]): seg_end += E["stations"][i]
        t += dt
    first = reached[0] if reached else T
    return dict(reached=[round(x / 60, 1) for x in reached], stopped=stopped_time,
                stopped_pct=100 * stopped_time / max(1, t - first), failures=sum(c.failures for c in comps),
                repairs=repairs, levels={c.name: c.level for c in comps}, per_min_fail=per_min_fail,
                fails_by={c.name: c.failures for c in comps}, t=t)

P0 = dict(
    components=[  # nome, tipo, vida base (m ou s), estação que libera, custo base do reforço
        ("Rodas", "dist", 6000.0, 0, 2000.0),
        ("Caldeira", "time", 300.0, 0, 2000.0),
        ("Pistões", "dist", 9000.0, 0, 3000.0),
        ("Freios", "dist", 15000.0, 1, 40000.0),
        ("Engates", "time", 480.0, 2, 400000.0),
        ("Chaminé", "time", 420.0, 3, 2500000.0),
    ],
    maint_seconds=15.0, repair_seconds=20.0, life_mult=1.4, reinforce_growth=1.8, reinforce_budget_s=25.0,
    tools_cost=50000.0, tools_station=1, tools_mult=0.6,
)
if __name__ == "__main__":
    for cps in (1.0,):
        base = run(P0, cps, components=False)
        print("1A sem componentes:", base["reached"])
    for style in ("cuidadoso", "ignora"):
        for cps in (0.0, 1.0):
            r = run(P0, cps, style)
            print(f"{style:9s} {cps:.0f} cps -> estações {r['reached']} | parado {r['stopped']:.0f}s ({r['stopped_pct']:.1f}% após a 1ª estação) | falhas {r['failures']} {r['fails_by']} | reparos {r['repairs']} | reforços {r['levels']}")
