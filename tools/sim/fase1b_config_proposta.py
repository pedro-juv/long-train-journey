import copy
from simular_fase1b import run, P0, speed_of
P = copy.deepcopy(P0)
P["components"] = [("Rodas","dist",15000.0,0,2000.0),("Caldeira","time",750.0,0,2000.0),("Pistões","dist",22500.0,0,3000.0),
                   ("Freios","dist",37500.0,1,40000.0),("Engates","time",1200.0,2,400000.0),("Chaminé","time",1050.0,3,2500000.0)]
P["reinforce_growth"]=2.5; P["reinforce_budget_s"]=10.0; P["maint_seconds"]=15.0
print("1A sem componentes (1 cps):", run(P,1.0,components=False)["reached"], "| AFK:", run(P,0.0,components=False)["reached"])
for style in ("cuidadoso","ignora"):
    for cps in (0.0,1.0,3.0):
        r=run(P,cps,style)
        print(f"{style:9s} {cps:.0f} cps: {r['reached']} | parado {r['stopped']:.0f}s = {r['stopped_pct']:.1f}% | falhas {r['failures']} {r['fails_by']} | reparos {r['repairs']} | reforços {r['levels']}")
        print("          falhas por minuto:", r['per_min_fail'][:25])
print("\nOffline: fração do tempo parado em manutenção (todos os 6 componentes, sem reforço / com reforço nv 3 / nv 6)")
for prod in (100, 1000, 10000):
    v = speed_of(prod)
    for lvl in (0, 3, 6):
        rate = 0.0
        for n,k,life,u,c in P["components"]:
            L = life * 1.4**lvl
            t_life = L / v if k=="dist" else L
            rate += 15.0 / t_life
        frac = rate/(1+rate)
        print(f"  produção {prod:>6}/s (vel {v:5.1f} m/s) reforço nv {lvl}: {100*frac:5.1f}% parado")
