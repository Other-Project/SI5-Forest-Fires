= Descriptif des capteurs

== Contexte environnemental et contraintes du système

Le système de détection et de prévention des incendies est destiné à être déployé dans des zones forestières étendues, potentiellement isolées et caractérisées par une forte variabilité climatique et biologique. Ces environnements présentent plusieurs contraintes structurantes pour la sélection des capteurs et l’architecture du dispositif :

- Conditions météorologiques extrêmes : les équipements doivent être capables de fonctionner dans des plages de température allant de fortes chaleurs estivales à des températures négatives, ainsi que sous des taux d’humidité très élevés ou très faibles. Les épisodes de vent fort, de pluie, de brouillard ou de poussière peuvent altérer les mesures, ce qui impose des capteurs robustes et étalonnés pour résister aux dérives environnementales.

- Environnement physique non contrôlé : la végétation peut obstruer la ligne de vue des capteurs optiques, tandis que les capteurs au sol peuvent être exposés à des contraintes mécaniques (racines, tassement, faune, piétinement). Les dispositifs doivent également être protégés contre la faune sauvage, le vandalisme et la corrosion. Des boîtiers renforcés à indice de protection élevé (IP65 à IP67) sont nécessaires.

- Contraintes énergétiques et de connectivité : en l’absence d’infrastructures, les nœuds capteurs doivent fonctionner sur alimentation autonome (batterie) et utiliser des réseaux radio longue portée et basse consommation. Cela impose d’optimiser la fréquence d’échantillonnage et la volumétrie des données.

== Exemple de déploiement du système

#figure(caption: [Exemple de mise en place du dispositif], [
  #image("figs/carte.png")

// Légende améliorée
#align(center)[
  #let _legend(thing, label) = grid(columns: 2, align: horizon, inset: (3pt, 0pt, 0pt, 0pt), 
  thing, text(size:10pt, label))
  #let _color(color) = box(fill: color.lighten(90%), stroke: color + 1.5pt, width: 14pt, height: 10pt, radius: 3pt)
  
  #grid(
    columns: 3,
    column-gutter: 12pt,
    row-gutter: 6pt, 
    align: horizon,
    _legend(rect(width: 20pt, height: 4pt, fill: blue), [*Capteur de gaz*]),
    _legend(polygon.regular(size: 17pt, vertices: 9, fill: orange.lighten(40%)), [*Centrale météo*]),
    _legend(polygon.regular(fill: red, size: 20pt, vertices: 3), [*Tour de guet (Passerelle LoRaWAN et caméras)*])
  )
]
#v(5pt)  
])<fig1>

La @fig1 représente la carte en relief d'une forêt à côté d'Aix-en-Provence sur laquelle un aperçu de notre système est donné. 

Les tours de guet déjà présentes dans la forêt sont représentées par des triangles rouges.
Nous avons pour objectif d'y installer les caméras ainsi que les passerelle LoRaWAN afin de pouvoir réutiliser l'infrastructure existante que ce soit pour le bâti comme pour l'alimentation électrique.
En effet, il y a d'assez forte chances qu'elle soit dors et déjà alimentée en électricité (par raccord au réseau ou par batteries rechargées par panneaux solaires).

Les centrale météo sont représentées en jaune orangé. Elles sont constituée de l'ensemble de nos capteurs environnementaux excepté les capteurs de gaz (thermomètre, hygromètre, capteur d'humidité du sol, baromètre, pluviomètre et anémomètre). Les centrales météo sont éloignées d'environ 1 à 2 km afin d'éviter les données trop redondantes et de couvrir un maximum de terrain avec un minimum de centrale (pour éviter de perturber l’environnement).

Enfin les capteurs de gaz seront placé tous les 250m environs au bord des axes principaux dans la forêt et à proximité des habitations. Ce sont les zones les plus à risque de départ de feu car l'activité humaine y est plus importante.


== Caméra thermique

#table(
  columns:  (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [matrice 2D en 4k de températures en °C],
  [Plage de#linebreak()fonctionnement], [−20 °C à +300 °C],
  [Précision],[±1°C],
  [Contraintes],[],
  [Fréquence],[1 fps],
  [Taille estimée#linebreak()d’un échantillon],[$3840 × 2160 "(4k)" = 8 294 400 "valeurs"$ sur 9 bits (512 valeurs discrètes) soit $74 649 600 "bits" = 8.9 "Mo"$]
)

== Caméra optique

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Image HD (720p)],
  [Plage de#linebreak()fonctionnement], [400 à 1000nm  (spectre visible + IR)],
  [Précision],[],
  [Contraintes],[],
  [Fréquence],[1 fps],
  [Taille estimée#linebreak()d’un échantillon],[$1 280 × 720 × 3 "(HD RGB)" = 2764800 "valeurs"$ sur 1 octet#linebreak()soit $2.64 "Mo"$]
)

== Thermomètre

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Température en °C],
  [Plage de#linebreak()fonctionnement], [-20°C à 80°C],
  [Précision],[±0.25°C],
  [Contraintes],[],
  [Taille estimée#linebreak()d’un échantillon],[2 octets]
)

#pagebreak()

== Hygromètre (humidité de l'air)

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Pourcentage d'humidité relative (%HR)],
  [Plage de#linebreak()fonctionnement], [0–100 %HR],
  [Précision],[±1%],
  [Contraintes],[La condensation et le givre peuvent saturer le capteur],
  [Taille estimée#linebreak()d’un échantillon],[1 octet]
)

== Capteur capacitif d’humidité du sol

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Humidité volumique (%Hv)],
  [Plage de#linebreak()fonctionnement], [0–60% %Hv],
  [Précision],[±1%],
  [Contraintes],[Gel, saturation, salinité, densité],
  [Taille estimée#linebreak()d’un échantillon],[1 octet]
)

== Baromètre

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Hectopascal (hPa)],
  [Plage de#linebreak()fonctionnement], [300-1100 hPa],
  [Précision],[±0.1 hPa],
  [Contraintes],[Sensible aux variations rapides de température],
  [Taille estimée#linebreak()d’un échantillon],[2 octets]
)

#pagebreak()

== Pluviomètre à auget basculant

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Nombre de basculement de l'auget depuis le dernier envoi],
  [Plage de#linebreak()fonctionnement], [N/A],
  [Précision],[0,2 mm],
  [Contraintes],[Vent → perte ou dérive des gouttes,\ Accumulation de débris → fausse mesure,\ Givre / gel → mesure impossible],
  [Taille estimée#linebreak()d’un échantillon],[2 octets]
)

== Anémomètre

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [vitesse en m/s et direction en degrés],
  [Plage de#linebreak()fonctionnement], [0 à 50 m/s pour la vitesse et 0-360° pour la direction],
  [Précision],[±0,2 m/s et ±0,5°],
  [Contraintes],[Position horizontale à niveau],
  [Taille estimée#linebreak()d’un échantillon],[3 octets]
)

== Capteur de gaz (CO, CO2, H2, VOC: Comp. Organiques Volatiles)

#table(
  columns: (auto, 1fr),
  table.cell(colspan: 2, align: center, [Caractéristiques Souhaitées]),
  [Grandeur & données], [Partie par million (ppm)],
  [Plage de#linebreak()fonctionnement], [
    CO : 0–1000 ppm#linebreak()
    CO₂ : 400–5000 ppm#linebreak()
    H₂ : 0–1000 ppm#linebreak()
    VOC : 0–10 ppm
  ],
  [Précision],[±5 ppm],
  [Contraintes],[],
  [Taille estimée#linebreak()d’un échantillon],[4 gaz × 2 octets = 8 octets]
)
