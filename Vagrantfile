# -*- mode: ruby -*-
# vi: set ft=ruby :
# RÉSULTATS-BF — Groupe 6 — Vagrantfile (source unique de vérité)
# Responsable : SIMPORE (architecte réseau et répartition)
#
# Utilisation (dossier du dépôt) :
#   PowerShell                         Git Bash
#   vagrant up                         vagrant up                -> socle : bdd1, bdd2, app1, app2, lb1
#   $env:NB_APP=4; vagrant up          NB_APP=4 vagrant up       -> 4 serveurs applicatifs (R3)
#   $env:EXT="e1"; vagrant up          EXT=e1 vagrant up         -> + lb2 (extension E1)
#   $env:EXT="e1,e2"; vagrant up       EXT=e1,e2 vagrant up      -> + lb2 + obs (E1 et E2)
#
# ATTENTION :
# - Définir NB_APP / EXT une fois en début de session ($env:NB_APP=4 en PowerShell,
#   export NB_APP=4 en Git Bash) : config/noeuds.yml est réécrit à chaque commande
#   Vagrant, et un « vagrant up lb1 » sans NB_APP ramènerait HAProxy à 2 serveurs.
# - Détruire avec les MÊMES variables que pour créer : après NB_APP=4, faire
#   « $env:NB_APP=4; vagrant destroy -f », sinon app3/app4 (ou lb2/obs) restent
#   allumées dans VirtualBox sans être gérées par Vagrant.
require 'yaml'
require 'fileutils'

GROUPE  = (ENV['GROUPE'] || 6).to_i           # groupe 6 -> 192.168.61.0/24
NB_APP  = (ENV['NB_APP'] || 2).to_i           # nombre de serveurs applicatifs
EXT     = (ENV['EXT'] || "").downcase         # extensions actives : "", "e1", "e1,e2"
RESEAU  = "192.168.#{55 + GROUPE}"
BOITE   = "bento/ubuntu-24.04"
VERSION = "202510.26.0"                       # version épinglée, identique pour tous
                                              # (202404.23.0 du sujet n'est pas publiée)

abort "GROUPE doit être entre 1 et 8"  unless (1..8).cover?(GROUPE)
abort "NB_APP doit être entre 2 et 9"  unless (2..9).cover?(NB_APP)

# Arrêt immédiat si .env manque (secrets lus par commun.sh / charger_env, R7)
if %w[up provision reload].include?(ARGV[0]) && !File.exist?(File.join(File.dirname(__FILE__), ".env"))
  abort "Fichier .env absent : lancer « cp .env.exemple .env » (PowerShell : Copy-Item .env.exemple .env) puis le compléter."
end

# Source unique de vérité : cette table crée les VM ET alimente la
# configuration du répartiteur (lue par les scripts dans /vagrant/config/noeuds.yml).
NOEUDS = []
NOEUDS << { nom: "bdd1", ip: "#{RESEAU}.31", mem: 768, role: "bdd" }
NOEUDS << { nom: "bdd2", ip: "#{RESEAU}.32", mem: 768, role: "replique" }
(1..NB_APP).each do |i|
  NOEUDS << { nom: "app#{i}", ip: "#{RESEAU}.#{20 + i}", mem: 512, role: "app" }
end
NOEUDS << { nom: "lb1", ip: "#{RESEAU}.11", mem: 512, role: "lb" }
NOEUDS << { nom: "lb2", ip: "#{RESEAU}.12", mem: 512, role: "lb" }  if EXT.include?("e1")
NOEUDS << { nom: "obs", ip: "#{RESEAU}.41", mem: 768, role: "obs" } if EXT.include?("e2")

FileUtils.mkdir_p(File.join(File.dirname(__FILE__), "config"))
File.binwrite(File.join(File.dirname(__FILE__), "config", "noeuds.yml"), NOEUDS.to_yaml)

Vagrant.configure("2") do |config|
  config.vm.box              = BOITE
  config.vm.box_version      = VERSION
  config.vm.box_check_update = false
  config.vm.boot_timeout     = 600

  NOEUDS.each do |n|
    config.vm.define n[:nom] do |m|
      m.vm.hostname = n[:nom]
      m.vm.network "private_network", ip: n[:ip]
      # R8 : seul le répartiteur lb1 expose un port vers l'hôte (8080 -> 80)
      if n[:nom] == "lb1"
        m.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
      end
      m.vm.provider "virtualbox" do |vb|
        vb.name   = "g#{GROUPE}-#{n[:nom]}"
        vb.memory = n[:mem]
        vb.cpus   = 1
        # DNS des VM confié à Windows : apt continue de marcher si le PC
        # change de réseau (Wi-Fi, partage de connexion) pendant la session.
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      end
      # Toutes les machines : node_exporter (métriques lues par obs, E2),
      # installé avant le script de rôle.
      m.vm.provision "node_exporter", type: "shell", run: "once",
        inline: "#!/usr/bin/env bash\nsource /vagrant/scripts/commun.sh\ninstaller_node_exporter"
      # Les lb sont reprovisionnés à chaque "vagrant up" : si NB_APP change,
      # la configuration HAProxy suit toute seule (R3).
      toujours = (n[:role] == "lb") ? "always" : "once"
      m.vm.provision "shell", path: "scripts/#{n[:role]}.sh", run: toujours
    end
  end
end
