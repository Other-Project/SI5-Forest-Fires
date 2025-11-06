= Avant-Propos

Des outils d'intelligence artificielle ont été utilisés pour la reformulation des phrases de ce rapport

== Ubiquitous langage

#table(
  columns: (auto, 1fr),
  inset: 7pt,
  align: horizon,
  table.header([Terme], [Définition]),

[Capteur],
[Dispositif IoT installé en forêt mesurant un ou plusieurs paramètres environnementaux (température, humidité, pression, gaz, vent…). Source principale de données brutes du système.],

[Centrale météo],
[Station combinant plusieurs capteurs environnementaux pour évaluer les conditions climatiques locales (humidité, vent, température, pluviométrie). Sert à l’évaluation du risque d’incendie.],

[Agrégateur forêt],
[Serveur Fog dédié à une zone forestière donnée. Centralise, traite et stocke les données locales avant transmission vers le Cloud.],

[Alerte incendie],
[Notification automatique transmise au CODIS ou aux opérateurs lorsqu’un risque ou un départ de feu est confirmé. Peut être graduée selon le niveau de confiance.],

[Carte de risque],
[Représentation dynamique (heatmap) du niveau de danger d’incendie par zone, calculée à partir des données locales et externes.],

[CODIS],
[Centre Opérationnel Départemental d’Incendie et de Secours. Destinataire principal des alertes et interface de validation humaine des détections.],

[Données externes],
[Informations provenant de sources tierces (Météo France, satellites FIRMS, Kéranos, IGN, etc.) utilisées pour enrichir les modèles.],

[Interface de visualisation],
[Application web ou mobile permettant la consultation en temps réel des alertes, cartes et historiques.],
)

== Hypothèse de travail

Nous posons comme hypothèse que les tours de guet forestières bénéficient d'un accès au réseau cellulaire. Cette hypothèse est plutôt réalise car les tours de guets sont généralement localisées à relative proximité d'axes routiers et en altitude sur des points topographiques dominants. Ce qui leur permet de capter les signaux cellulaires sans blocage des ondes dû au relief. Sur 20 tours de guet étudiées seules 4 disposaient d'une connectivité limitée (sans être nulle pour autant).