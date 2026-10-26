// Présentation de soutenance — RÉSULTATS-BF, Groupe 6
// Couleurs reprises du logo IBAM : orange #EA663B, bleu #42B5D9
const pptxgen = require("pptxgenjs");
const path = require("path");

const LOGOS = process.argv[2];
const SCHEMA = process.argv[3];
const OUT = process.argv[4];

const THEME = {
  name: "IBAM RESULTATS-BF",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "1A2B33",   // texte
    lt1: "FFFFFF",
    dk2: "0F3B4C",   // bleu profond dérivé du logo : fonds sombres
    lt2: "F1F8FB",   // bleu très clair : cartes
    accent1: "EA663B", // orange IBAM
    accent2: "42B5D9", // bleu IBAM
    accent3: "0F3B4C",
    accent4: "9BDCEC",
    accent5: "F7B49B",
    accent6: "5E7883",
    hlink: "42B5D9",
    folHlink: "9BDCEC",
  },
};

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE";           // 13.3 x 7.5
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.author = "Groupe 6 — M1 Informatique IBAM";
pres.title = "RESULTATS-BF — soutenance";
const C = pres.SchemeColor;
const W = 13.33, H = 7.5;

// ---------------------------------------------------------------- layouts
pres.defineSlideMaster({
  title: "TITRE",
  background: { color: THEME.colors.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.9, y: 2.5, w: 11.5, h: 1.5,
        fontSize: 44, bold: true, color: C.background1, align: "left" }, text: " " } },
    { placeholder: { options: { name: "body", type: "body", x: 0.9, y: 4.05, w: 11.5, h: 2.2,
        fontSize: 15, color: THEME.colors.accent4, align: "left" }, text: " " } },
  ],
});

pres.defineSlideMaster({
  title: "SECTION",
  background: { color: THEME.colors.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 1.4, y: 3.0, w: 10.5, h: 1.3,
        fontSize: 38, bold: true, color: C.background1, align: "left" }, text: " " } },
    { placeholder: { options: { name: "body", type: "body", x: 1.4, y: 4.3, w: 10.5, h: 1.2,
        fontSize: 16, color: THEME.colors.accent4, align: "left" }, text: " " } },
  ],
  slideNumber: { x: 12.5, y: 6.95, fontSize: 10, color: THEME.colors.accent6 },
});

pres.defineSlideMaster({
  title: "CONTENU",
  background: { color: C.background1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.75, y: 0.45, w: 11.9, h: 0.85,
        fontSize: 32, bold: true, color: THEME.colors.dk2, align: "left" }, text: " " } },
    { text: { text: "RÉSULTATS-BF — Groupe 6", options: { x: 0.75, y: 6.95, w: 6, h: 0.3,
        fontSize: 9, color: THEME.colors.accent6, align: "left", isTextBox: true } } },
  ],
  slideNumber: { x: 12.5, y: 6.95, fontSize: 10, color: THEME.colors.accent6 },
});

// ------------------------------------------------------------- utilitaires
const ombre = () => ({ type: "outer", color: "0F3B4C", opacity: 0.1, blur: 8, offset: 2, angle: 90 });

function carte(s, x, y, w, h, opts = {}) {
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.1,
    fill: { color: opts.fill || THEME.colors.lt2 },
    line: { color: opts.line || THEME.colors.lt2, width: 1 },
    shadow: ombre(), objectName: opts.name || "carte",
  });
}

// Pastille ronde numérotée — le motif répété du jeu de diapositives
function pastille(s, x, y, texte, couleur) {
  const d = 0.62;
  s.addShape(pres.ShapeType.ellipse, {
    x, y, w: d, h: d, fill: { color: couleur || THEME.colors.accent1 },
    line: { color: couleur || THEME.colors.accent1, width: 1 }, objectName: "pastille " + texte,
  });
  s.addText(texte, { x, y, w: d, h: d, fontSize: 15, bold: true, color: "FFFFFF",
    align: "center", valign: "middle", margin: 0, isTextBox: true });
}

function statistique(s, x, y, w, valeur, unite, libelle, couleur) {
  carte(s, x, y, w, 1.95, { name: "stat " + libelle });
  s.addText([{ text: valeur, options: { fontSize: 42, bold: true, color: couleur } },
             { text: unite ? " " + unite : "", options: { fontSize: 17, bold: true, color: couleur } }],
    { x: x + 0.25, y: y + 0.28, w: w - 0.5, h: 0.8, align: "left", margin: 0, isTextBox: true });
  s.addText(libelle, { x: x + 0.25, y: y + 1.12, w: w - 0.5, h: 0.65, fontSize: 12,
    color: THEME.colors.dk1, align: "left", margin: 0, isTextBox: true });
}

// --------------------------------------------------------------- 1. titre
pres.addSection({ title: "Ouverture" });
let s = pres.addSlide({ masterName: "TITRE", sectionTitle: "Ouverture" });
s.addImage({ path: path.join(LOGOS, "image1.png"), x: 0.9, y: 0.6, h: 1.0, w: 1.0 });
s.addImage({ path: path.join(LOGOS, "image2.png"), x: 2.1, y: 0.62, h: 0.95, w: 1.43 });
s.addText("Université Joseph KI-ZERBO — Institut Burkinabè des Arts et Métiers", {
  x: 0.9, y: 1.85, w: 11.5, h: 0.3, fontSize: 12, color: THEME.colors.accent4, isTextBox: true, margin: 0 });
s.addText("RÉSULTATS-BF", { placeholder: "title" });
s.addText([
  { text: "Une infrastructure résiliente et scalable, entièrement décrite en code", options: { fontSize: 17, color: "FFFFFF" } },
], { x: 0.9, y: 3.95, w: 11.5, h: 0.4, isTextBox: true, margin: 0 });
s.addText([
  { text: "Groupe 6", options: { bold: true, color: THEME.colors.accent1 } },
  { text: "   SIMPORE Wend-Yam Lysias Eldad · OUEDRAOGO D. Adan Franck · KAGAMBEGA Hermann · NIKIEMA Shun Arion · KUELA Abdoul Raof", options: {} },
], { x: 0.9, y: 4.6, w: 11.5, h: 0.6, fontSize: 13, color: THEME.colors.accent4, isTextBox: true, margin: 0 });
s.addText("M1 Informatique — Virtualisation et Cloud Computing — Dr SOMDA — 2026-2027", {
  x: 0.9, y: 5.5, w: 11.5, h: 0.3, fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });
s.addNotes("Présentation du projet RÉSULTATS-BF par le groupe 6. Annoncer le plan : le problème, l'architecture, les résultats mesurés, la démonstration.");

// ------------------------------------------------------------ 2. problème
pres.addSection({ title: "Le problème" });
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Le problème" });
s.addText("Chaque année, le même incident", { placeholder: "title" });
s.addText("Le site des résultats tombe dans les dix minutes qui suivent l'annonce. Rarement parce que le programme est mal écrit — presque toujours parce que son infrastructure n'a été pensée ni pour absorber un pic, ni pour survivre à la panne d'une seule machine.",
  { x: 0.75, y: 1.45, w: 7.1, h: 1.3, fontSize: 15, color: THEME.colors.dk1, isTextBox: true, margin: 0 });

const causes = [
  ["Un seul serveur applicatif", "Il tombe, le service tombe avec lui"],
  ["Une seule base de données", "Aucune reprise possible, aucune réplique"],
  ["Une configuration faite à la main", "Impossible à reconstruire à l'identique"],
];
causes.forEach(([t, d], i) => {
  const y = 3.0 + i * 1.25;
  carte(s, 0.75, y, 7.1, 1.05, { name: "cause " + i });
  pastille(s, 1.0, y + 0.22, String(i + 1), THEME.colors.accent1);
  s.addText(t, { x: 1.82, y: y + 0.14, w: 5.8, h: 0.35, fontSize: 14, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });
  s.addText(d, { x: 1.82, y: y + 0.5, w: 5.8, h: 0.35, fontSize: 12,
    color: THEME.colors.accent6, isTextBox: true, margin: 0 });
});

carte(s, 8.3, 1.45, 4.3, 5.1, { fill: THEME.colors.dk2, line: THEME.colors.dk2, name: "mandat" });
s.addText("Notre mandat", { x: 8.65, y: 1.75, w: 3.6, h: 0.4, fontSize: 13, bold: true,
  color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText("Construire la plateforme qui permet à un candidat de consulter son résultat à partir de son matricule.",
  { x: 8.65, y: 2.2, w: 3.6, h: 1.0, fontSize: 14, color: "FFFFFF", isTextBox: true, margin: 0 });
s.addText("Deux exigences priment sur tout le reste :", { x: 8.65, y: 3.35, w: 3.6, h: 0.35,
  fontSize: 12, color: THEME.colors.accent4, isTextBox: true, margin: 0 });
[["Résilience", "la panne d'une machine n'interrompt pas le service"],
 ["Scalabilité", "absorber plus de trafic = ajouter des machines"]].forEach(([t, d], i) => {
  const y = 3.85 + i * 1.25;
  s.addText(t, { x: 8.65, y, w: 3.6, h: 0.32, fontSize: 15, bold: true, color: THEME.colors.accent2, isTextBox: true, margin: 0 });
  s.addText(d, { x: 8.65, y: y + 0.34, w: 3.6, h: 0.7, fontSize: 12, color: "FFFFFF", isTextBox: true, margin: 0 });
});
s.addNotes("Le sujet : ce n'est pas un exercice de programmation. L'application est minuscule. Ce qui est évalué, c'est l'infrastructure autour d'elle.");

// -------------------------------------------------------- 3. architecture
pres.addSection({ title: "Architecture" });
s = pres.addSlide({ masterName: "SECTION", sectionTitle: "Architecture" });
s.addText("L'architecture", { placeholder: "title" });
s.addText("Six machines, un réseau privé, une seule source de vérité", { placeholder: "body" });

s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Architecture" });
s.addText("Du navigateur à la base, tout passe par le réseau privé", { placeholder: "title" });
s.addImage({ path: SCHEMA, x: 0.75, y: 1.35, w: 11.9, h: 4.85 });
s.addText("Seul le répartiteur lb1 expose un port vers l'hôte (8080 → 80). Base de données, métriques, réplication et supervision ne quittent jamais 192.168.61.0/24.",
  { x: 0.75, y: 6.3, w: 11.9, h: 0.5, fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });
s.addNotes("Montrer le chemin d'une requête : navigateur, lb1, un serveur applicatif choisi en tourniquet, bdd1. En parallèle : réplication vers bdd2, métriques vers obs.");

// ------------------------------------------------- 4. source de vérité R3
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Architecture" });
s.addText("Une seule source de vérité pour toute la plateforme", { placeholder: "title" });
carte(s, 0.75, 1.5, 5.6, 2.5, { name: "code" });
s.addText("Vagrantfile", { x: 1.05, y: 1.72, w: 5.0, h: 0.3, fontSize: 11, bold: true,
  color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText('NOEUDS << { nom: "bdd1", ip: "#{RESEAU}.31",\n            mem: 768, role: "bdd" }\n\n(1..NB_APP).each do |i|\n  NOEUDS << { nom: "app#{i}",\n      ip: "#{RESEAU}.#{20 + i}", role: "app" }\nend',
  { x: 1.05, y: 2.12, w: 5.0, h: 1.7, fontSize: 11, fontFace: "Courier New",
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });

[["config/noeuds.yml", "engendré à chaque commande Vagrant"],
 ["Configuration HAProxy", "engendrée depuis le même fichier"],
 ["Scripts de provisionnement", "lisent les adresses, n'en inventent aucune"]].forEach(([t, d], i) => {
  const y = 1.5 + i * 0.88;
  pastille(s, 6.85, y + 0.1, "↓", THEME.colors.accent2);
  s.addText(t, { x: 7.65, y: y + 0.05, w: 5.0, h: 0.35, fontSize: 14, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });
  s.addText(d, { x: 7.65, y: y + 0.4, w: 5.0, h: 0.35, fontSize: 12,
    color: THEME.colors.accent6, isTextBox: true, margin: 0 });
});

carte(s, 0.75, 4.35, 11.87, 1.85, { fill: THEME.colors.dk2, line: THEME.colors.dk2, name: "consequence" });
s.addText("Conséquence directe", { x: 1.1, y: 4.6, w: 5, h: 0.35, fontSize: 13, bold: true,
  color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText([{ text: "Passer de 2 à 4 serveurs ne demande que ", options: { color: "FFFFFF" } },
           { text: "NB_APP=4 vagrant up", options: { fontFace: "Courier New", bold: true, color: THEME.colors.accent2 } },
           { text: ". Aucune adresse n'est écrite en dur, nulle part : la configuration du répartiteur suit toute seule.", options: { color: "FFFFFF" } }],
  { x: 1.1, y: 5.0, w: 11.2, h: 0.95, fontSize: 15, isTextBox: true, margin: 0 });
s.addNotes("C'est le cœur de R3. Sans cette table unique, scalable n'est qu'un mot, et le barème retire deux points.");

// ------------------------------------------------------- 5. résilience
pres.addSection({ title: "Résilience" });
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Résilience" });
s.addText("Supprimer les points de défaillance unique, un par un", { placeholder: "title" });
const couches = [
  ["Serveur applicatif", "HAProxy interroge GET /sante chaque seconde. Deux échecs : le serveur est écarté. Une requête restée sans réponse est rejouée ailleurs.", THEME.colors.accent2],
  ["Base de données", "bdd2 réplique bdd1 en flux. En cas de panne, scripts/bascule.sh promeut bdd2 et redirige les serveurs sans les redémarrer.", THEME.colors.accent1],
  ["Répartiteur", "Extension E1 : keepalived porte une IP virtuelle. Si lb1 tombe, lb2 la reprend à la même adresse.", THEME.colors.accent2],
];
couches.forEach(([t, d, col], i) => {
  const x = 0.75 + i * 4.06;
  carte(s, x, 1.5, 3.8, 3.0, { name: "couche " + i });
  pastille(s, x + 0.3, 1.78, String(i + 1), col);
  s.addText(t, { x: x + 0.3, y: 2.6, w: 3.2, h: 0.4, fontSize: 16, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });
  s.addText(d, { x: x + 0.3, y: 3.05, w: 3.2, h: 1.3, fontSize: 12,
    color: THEME.colors.dk1, isTextBox: true, margin: 0 });
});
carte(s, 0.75, 4.85, 11.87, 1.4, { fill: "FDF0EB", line: "F7B49B", name: "jamais deux" });
s.addText("Un garde-fou qui compte", { x: 1.1, y: 5.05, w: 4, h: 0.3, fontSize: 12, bold: true,
  color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText("La bascule refuse de s'exécuter tant que bdd1 accepte encore des écritures : deux bases primaires divergeraient, et aucune réconciliation ne serait possible.",
  { x: 1.1, y: 5.4, w: 11.2, h: 0.7, fontSize: 13, color: THEME.colors.dk1, isTextBox: true, margin: 0 });
s.addNotes("R4 pour le serveur applicatif, R5 et R6 pour la base, E1 pour le répartiteur.");

// --------------------------------------------------------- 6. résultats
pres.addSection({ title: "Résultats" });
s = pres.addSlide({ masterName: "SECTION", sectionTitle: "Résultats" });
s.addText("Ce que nous avons mesuré", { placeholder: "title" });
s.addText("Chaque chiffre vient d'un fichier de sortie brute, horodaté et versionné", { placeholder: "body" });

s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Résultats" });
s.addText("Trois mesures sur machines virtuelles", { placeholder: "title" });
statistique(s, 0.75, 1.5, 3.8, "17", "min 38 s", "Reconstruction intégrale, plateforme conforme, sans une seule commande tapée à la main", THEME.colors.accent1);
statistique(s, 4.81, 1.5, 3.8, "1,2", "s", "Interruption maximale quand le répartiteur tombe — 0 erreur sur 688 requêtes", THEME.colors.accent2);
statistique(s, 8.87, 1.5, 3.75, "0", "%", "Écart de répartition entre 4 serveurs applicatifs : 5 / 5 / 5 / 5", THEME.colors.accent1);

carte(s, 0.75, 3.75, 11.87, 2.45, { name: "methode" });
s.addText("Une mesure sans contexte ne vaut rien", { x: 1.1, y: 3.98, w: 6, h: 0.35, fontSize: 15,
  bold: true, color: THEME.colors.dk2, isTextBox: true, margin: 0 });
s.addText([
  { text: "Chaque sortie d'essai commence par la commande exacte, la date, le poste, le nombre de serveurs et le commit du dépôt.", options: { breakLine: true, bullet: true } },
  { text: "Les fichiers bruts sont versionnés dans essais/resultats/ : l'enseignant peut rejouer et comparer.", options: { breakLine: true, bullet: true } },
  { text: "Un essai interrompu n'écrase jamais une mesure réussie ; il est compté à part.", options: { bullet: true } },
], { x: 1.1, y: 4.4, w: 11.2, h: 1.6, fontSize: 13, color: THEME.colors.dk1, paraSpaceAfter: 6, isTextBox: true, margin: 0 });
s.addNotes("Les scénarios V2, V3 et V4 seront exécutés en direct pendant la démonstration.");

// ------------------------------------------- 7. la mesure qui trompait
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Résultats" });
s.addText("La mesure la plus utile du projet est celle qui était fausse", { placeholder: "title" });

carte(s, 0.75, 1.5, 5.7, 2.1, { fill: "FDF0EB", line: "F7B49B", name: "avant" });
s.addText("Avant", { x: 1.05, y: 1.72, w: 2, h: 0.3, fontSize: 12, bold: true, color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText([{ text: "40 %", options: { fontSize: 36, bold: true, color: THEME.colors.accent1 } },
           { text: "  d'écart de répartition", options: { fontSize: 14, color: THEME.colors.dk1 } }],
  { x: 1.05, y: 2.1, w: 5.1, h: 0.6, isTextBox: true, margin: 0 });
s.addText("6 / 5 / 5 / 4 puis 6 / 4 / 4 / 6 sur quatre serveurs", { x: 1.05, y: 2.78, w: 5.1, h: 0.4,
  fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });

carte(s, 6.92, 1.5, 5.7, 2.1, { fill: "EBF7FB", line: "9BDCEC", name: "apres" });
s.addText("Après", { x: 7.22, y: 1.72, w: 2, h: 0.3, fontSize: 12, bold: true, color: THEME.colors.accent2, isTextBox: true, margin: 0 });
s.addText([{ text: "0 %", options: { fontSize: 36, bold: true, color: THEME.colors.accent2 } },
           { text: "  d'écart de répartition", options: { fontSize: 14, color: THEME.colors.dk1 } }],
  { x: 7.22, y: 2.1, w: 5.1, h: 0.6, isTextBox: true, margin: 0 });
s.addText("5 / 5 / 5 / 5, deux essais consécutifs", { x: 7.22, y: 2.78, w: 5.1, h: 0.4,
  fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });

carte(s, 0.75, 3.85, 11.87, 2.35, { fill: THEME.colors.dk2, line: THEME.colors.dk2, name: "explication" });
s.addText("Ce n'était pas le répartiteur", { x: 1.1, y: 4.1, w: 6, h: 0.35, fontSize: 15, bold: true,
  color: THEME.colors.accent1, isTextBox: true, margin: 0 });
s.addText("La sonde de keepalived interrogeait /sante à travers le répartiteur : elle consommait un tour du tourniquet chaque seconde. Nos 20 appels se partageaient entre les quatre serveurs et la sonde.",
  { x: 1.1, y: 4.5, w: 11.2, h: 0.8, fontSize: 14, color: "FFFFFF", isTextBox: true, margin: 0 });
s.addText([{ text: "Correction : ", options: { color: THEME.colors.accent4 } },
           { text: "monitor-uri /lb_sante", options: { fontFace: "Courier New", bold: true, color: THEME.colors.accent2 } },
           { text: ", une réponse servie par HAProxy lui-même, qui ne traverse plus les serveurs applicatifs.", options: { color: THEME.colors.accent4 } }],
  { x: 1.1, y: 5.42, w: 11.2, h: 0.6, fontSize: 13, isTextBox: true, margin: 0 });
s.addNotes("Le premier chiffre n'était pas faux : il mesurait autre chose que ce que nous croyions. C'est en l'expliquant que nous avons corrigé l'infrastructure.");

// ------------------------------------------------------ 8. observabilité
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Résultats" });
s.addText("Voir ce qui se passe pendant une panne", { placeholder: "title" });
s.addText("Extension E2 — Prometheus interroge toutes les machines toutes les cinq secondes ; Grafana montre en direct ce que les scénarios provoquent.",
  { x: 0.75, y: 1.4, w: 11.9, h: 0.5, fontSize: 15, color: THEME.colors.dk1, isTextBox: true, margin: 0 });
const vues = [
  ["Pendant la montée en charge", "Le débit total monte, et se répartit entre les serveurs applicatifs", THEME.colors.accent2],
  ["Pendant la panne d'un serveur", "« Serveurs en service » passe de 2 à 1 ; le débit du serveur arrêté tombe à zéro", THEME.colors.accent1],
  ["Sur chaque machine", "Processeur, mémoire, disque et réseau, par node_exporter sur le port 9100", THEME.colors.accent2],
  ["Sur le répartiteur", "Réponses par code HTTP et nombre de serveurs actifs, exportés par HAProxy", THEME.colors.accent1],
];
vues.forEach(([t, d, col], i) => {
  const x = 0.75 + (i % 2) * 6.06;
  const y = 2.2 + Math.floor(i / 2) * 2.1;
  carte(s, x, y, 5.8, 1.8, { name: "vue " + i });
  pastille(s, x + 0.3, y + 0.28, "•", col);
  s.addText(t, { x: x + 1.1, y: y + 0.26, w: 4.4, h: 0.35, fontSize: 15, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });
  s.addText(d, { x: x + 1.1, y: y + 0.68, w: 4.4, h: 0.95, fontSize: 12,
    color: THEME.colors.dk1, isTextBox: true, margin: 0 });
});
s.addText("Grafana est accessible sur le réseau privé, à l'adresse 192.168.61.41:3000 — aucun port supplémentaire n'est exposé vers l'hôte.",
  { x: 0.75, y: 6.45, w: 11.9, h: 0.4, fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });

// ------------------------------------- 9. reproductibilité : le vrai sens
pres.addSection({ title: "Ce que nous avons appris" });
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Ce que nous avons appris" });
s.addText("La reproductibilité vérifiée sur trois postes", { placeholder: "title" });

carte(s, 0.75, 1.5, 5.7, 1.5, { name: "posteA" });
s.addText([{ text: "17 min 38 s", options: { fontSize: 26, bold: true, color: THEME.colors.accent2 } }],
  { x: 1.05, y: 1.72, w: 5.1, h: 0.5, isTextBox: true, margin: 0 });
s.addText("Poste A — plateforme conforme, sans intervention", { x: 1.05, y: 2.3, w: 5.1, h: 0.5,
  fontSize: 13, color: THEME.colors.dk1, isTextBox: true, margin: 0 });

carte(s, 6.92, 1.5, 5.7, 1.5, { fill: "FDF0EB", line: "F7B49B", name: "posteB" });
s.addText([{ text: "6 h 18", options: { fontSize: 26, bold: true, color: THEME.colors.accent1 } },
           { text: "  puis échec", options: { fontSize: 15, color: THEME.colors.dk1 } }],
  { x: 7.22, y: 1.72, w: 5.1, h: 0.5, isTextBox: true, margin: 0 });
s.addText("Poste B — même dépôt, même commande, deux échecs", { x: 7.22, y: 2.3, w: 5.1, h: 0.5,
  fontSize: 13, color: THEME.colors.dk1, isTextBox: true, margin: 0 });

s.addText("Trois facteurs, tous du côté de l'hôte :", { x: 0.75, y: 3.25, w: 11.9, h: 0.35,
  fontSize: 14, bold: true, color: THEME.colors.dk2, isTextBox: true, margin: 0 });
[["VirtualBox au-dessus de Hyper-V", "WSL 2 et Docker Desktop l'activent : VirtualBox passe en mode de compatibilité"],
 ["Mémoire réellement libre", "1,1 Go disponibles pour un socle qui en demande 3"],
 ["Lien réseau instable", "un partage de connexion mobile fait échouer le téléchargement des paquets"]].forEach(([t, d], i) => {
  const y = 3.75 + i * 0.85;
  pastille(s, 0.85, y + 0.05, String(i + 1), THEME.colors.accent6);
  s.addText(t, { x: 1.65, y: y - 0.02, w: 3.6, h: 0.4, fontSize: 13, bold: true, color: THEME.colors.dk2, isTextBox: true, margin: 0, valign: "middle" });
  s.addText(d, { x: 5.4, y: y - 0.02, w: 7.1, h: 0.4, fontSize: 12, color: THEME.colors.dk1, isTextBox: true, margin: 0, valign: "middle" });
});
carte(s, 0.75, 6.08, 11.87, 0.62, { fill: THEME.colors.dk2, line: THEME.colors.dk2, name: "lecon" });
s.addText("Le code est reproductible ; l'expérience ne l'est pas. Un projet livré devrait déclarer ses prérequis d'hôte, pas seulement ses versions d'outils.",
  { x: 1.1, y: 6.2, w: 11.2, h: 0.4, fontSize: 13, bold: true, color: "FFFFFF", isTextBox: true, margin: 0 });
s.addNotes("Nos scripts se sont comportés à l'identique sur les deux postes : mêmes étapes, mêmes messages, reprises automatiques d'apt-get update comprises.");

// ----------------------------------------------------------- 10. limites
s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Ce que nous avons appris" });
s.addText("Ce que nous ferions autrement", { placeholder: "title" });
const limites = [
  ["Bascule déclenchée à la main", "Déclenchement automatique, avec un témoin extérieur pour éviter la double promotion"],
  ["bdd1 ne revient pas en réplique", "Script de retour en réplique avec pg_rewind, au lieu d'une reconstruction complète"],
  ["Une connexion à la base par requête", "Une réserve de connexions, qui lèverait la limite observée en charge"],
  ["Toutes les machines sur un seul hôte", "Répartir sur plusieurs machines physiques : les mesures de débit auraient alors un sens"],
];
limites.forEach(([t, d], i) => {
  const y = 1.5 + i * 1.2;
  carte(s, 0.75, y, 11.87, 1.0, { name: "limite " + i });
  pastille(s, 1.05, y + 0.19, String(i + 1), THEME.colors.accent1);
  s.addText(t, { x: 1.9, y: y + 0.12, w: 4.1, h: 0.75, fontSize: 14, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0, valign: "middle" });
  s.addText(d, { x: 6.2, y: y + 0.12, w: 6.2, h: 0.75, fontSize: 12.5,
    color: THEME.colors.dk1, isTextBox: true, margin: 0, valign: "middle" });
});
s.addText("Deux extensions sur quatre ont été réalisées : E1, le répartiteur redondant, et E2, l'observabilité. La priorité est allée au socle.",
  { x: 0.75, y: 6.45, w: 11.9, h: 0.35, fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });

// ------------------------------------------------------ 11. démonstration
pres.addSection({ title: "Démonstration" });
s = pres.addSlide({ masterName: "SECTION", sectionTitle: "Démonstration" });
s.addText("Démonstration", { placeholder: "title" });
s.addText("Destruction, reconstruction en direct, puis trois scénarios tirés au sort", { placeholder: "body" });

s = pres.addSlide({ masterName: "CONTENU", sectionTitle: "Démonstration" });
s.addText("Les six scénarios de validation", { placeholder: "title" });
const scenarios = [
  ["V1", "Répartition", "Les N serveurs répondent tour à tour"],
  ["V2", "Panne d'un serveur applicatif", "Le service continue, aucune erreur au-delà de 5 s"],
  ["V3", "Montée en charge", "Débit à 2 puis 4 serveurs, commenté honnêtement"],
  ["V4", "Panne de la base primaire", "503 propre, puis bascule chronométrée sur bdd2"],
  ["V5", "Reconstruction intégrale", "destroy puis up, sans aucune intervention"],
  ["V6", "Panne du répartiteur", "lb2 reprend l'adresse virtuelle"],
];
scenarios.forEach(([n, t, d], i) => {
  const x = 0.75 + (i % 2) * 6.06;
  const y = 1.5 + Math.floor(i / 2) * 1.62;
  carte(s, x, y, 5.8, 1.35, { name: "scenario " + n });
  pastille(s, x + 0.3, y + 0.36, n, i % 2 === 0 ? THEME.colors.accent1 : THEME.colors.accent2);
  s.addText(t, { x: x + 1.12, y: y + 0.22, w: 4.4, h: 0.38, fontSize: 15, bold: true,
    color: THEME.colors.dk2, isTextBox: true, margin: 0 });
  s.addText(d, { x: x + 1.12, y: y + 0.63, w: 4.4, h: 0.55, fontSize: 12,
    color: THEME.colors.dk1, isTextBox: true, margin: 0 });
});
s.addText("Chaque scénario se lance par une seule commande et écrit sa sortie brute dans essais/resultats/.",
  { x: 0.75, y: 6.42, w: 11.9, h: 0.4, fontSize: 12, color: THEME.colors.accent6, isTextBox: true, margin: 0 });

// ---------------------------------------------------------- 12. clôture
pres.addSection({ title: "Clôture" });
s = pres.addSlide({ masterName: "TITRE", sectionTitle: "Clôture" });
s.addText("Ce que nous retenons", { placeholder: "title" });
[["Mesurer tôt, et comprendre chaque chiffre", "Les deux mesures les plus utiles du projet sont celles qui étaient fausses."],
 ["Un provisionnement non idempotent ne se voit qu'au second passage", "Rejouer systématiquement a révélé plusieurs défauts invisibles au premier essai."],
 ["La reproductibilité se vérifie sur le poste d'un autre", "Les erreurs les plus coûteuses n'apparaissaient pas sur le poste qui avait écrit le code."]]
  .forEach(([t, d], i) => {
    const y = 4.05 + i * 0.95;
    pastille(s, 0.9, y, String(i + 1), THEME.colors.accent1);
    s.addText(t, { x: 1.72, y: y - 0.04, w: 10.6, h: 0.35, fontSize: 15, bold: true,
      color: "FFFFFF", isTextBox: true, margin: 0 });
    s.addText(d, { x: 1.72, y: y + 0.32, w: 10.6, h: 0.4, fontSize: 12.5,
      color: THEME.colors.accent4, isTextBox: true, margin: 0 });
  });
s.addText("Merci de votre attention — nous répondons à vos questions.", { x: 0.9, y: 6.85, w: 11.5, h: 0.4,
  fontSize: 13, bold: true, color: THEME.colors.accent2, isTextBox: true, margin: 0 });

// ------------------------------------------------------------------ sortie
(async () => {
  await pres.writeFile({ fileName: OUT });
  const { applyTheme } = require(process.argv[5]);
  await applyTheme(OUT, THEME);
  console.log("ok", OUT);
})();
