"""Application RÉSULTATS-BF : consultation des résultats du baccalauréat."""
import os
import socket

import psycopg2
from flask import Flask, jsonify

# Écrits par scripts/app.sh. bdd_hote.env appartient ensuite à la bascule.
FICHIERS_ENV = ["/etc/resultats-app/app.env", "/etc/resultats-app/bdd_hote.env"]

app = Flask(__name__)


def lire_config():
    """Relit les fichiers à chaque appel pour suivre la bascule de BDD_HOTE."""
    config = dict(os.environ)
    for chemin in FICHIERS_ENV:
        try:
            with open(chemin, encoding="utf-8") as f:
                for ligne in f:
                    ligne = ligne.strip()
                    if ligne and not ligne.startswith("#") and "=" in ligne:
                        cle, valeur = ligne.split("=", 1)
                        config[cle.strip()] = valeur.strip().strip('"')
        except OSError:
            pass
    return config

def requete(sql, params=()):
    """Ouvre une connexion, exécute, renvoie une ligne, referme toujours."""
    c = lire_config()
    cnx = psycopg2.connect(
        host=c["BDD_HOTE"],
        port=5432,
        dbname=c["BDD_NOM"],
        user=c["BDD_UTILISATEUR"],
        password=c["BDD_MOT_DE_PASSE"],
        connect_timeout=2,
    )
    try:
        with cnx.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchone()
    finally:
        cnx.close()


@app.get("/sante")
def sante():
    try:
        requete("SELECT 1")
        return jsonify(etat="ok", machine=socket.gethostname()), 200
    except Exception as erreur:
        return jsonify(etat="ko", machine=socket.gethostname(),
                       erreur=str(erreur)), 503


@app.get("/info")
def info():
    return jsonify(machine=socket.gethostname())


@app.get("/resultats/<matricule>")
def resultat(matricule):
    try:
        ligne = requete(
            "SELECT matricule, nom, serie, moyenne, admis "
            "FROM resultats WHERE matricule = %s",
            (matricule,),
        )
    except Exception as erreur:
        return jsonify(erreur="base indisponible", detail=str(erreur)), 503
    if ligne is None:
        return jsonify(erreur="matricule inconnu"), 404
    return jsonify(
        matricule=ligne[0],
        nom=ligne[1],
        serie=ligne[2],
        moyenne=float(ligne[3]),
        admis=ligne[4],
        machine=socket.gethostname(),
    )


@app.get("/")
def accueil():
    return jsonify(
        service="RÉSULTATS-BF",
        routes=["/resultats/<matricule>", "/sante", "/info"],
        machine=socket.gethostname(),
    )