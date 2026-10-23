#!/usr/bin/env bash
# Sonde de keepalived (extension E1) : ce répartiteur est-il capable de
# servir ? Code 0 = oui, sinon keepalived lui retire l'IP virtuelle et
# lb2 la reprend.
#
# À installer par scripts/lb.sh dans /usr/local/bin/verifier_haproxy, puis
# à déclarer dans keepalived.conf :
#
#     vrrp_script verifier_haproxy {
#         script "/usr/local/bin/verifier_haproxy"
#         interval 1      # une vérification par seconde
#         timeout 2
#         fall 2          # 2 échecs -> l'IP virtuelle part (~2 s, cible V6 < 5 s)
#         rise 2
#     }
#     vrrp_instance VI_1 { ... track_script { verifier_haproxy } }
#
# On vérifie que HAProxy RÉPOND sur le port 80, quel que soit le code HTTP :
# un 503 « aucun serveur applicatif » ne doit pas faire basculer l'IP, car
# lb2 a exactement les mêmes serveurs derrière lui, et l'IP ferait
# des allers-retours sans rien réparer.

PORT="${1:-80}"

# 1. Le processus tourne-t-il ?
pidof haproxy >/dev/null 2>&1 || exit 1

# 2. Répond-il en HTTP sur le port du frontend ? (code 000 = pas de réponse)
# /lb_sante est servi par HAProxy lui-même (monitor-uri dans scripts/lb.sh) :
# la sonde ne consomme pas de tour du roundrobin vers les serveurs applicatifs.
code="$(curl -s -o /dev/null -w '%{http_code}' -m 1 "http://127.0.0.1:${PORT}/lb_sante")"
[ -n "$code" ] && [ "$code" != "000" ] || exit 2

exit 0
