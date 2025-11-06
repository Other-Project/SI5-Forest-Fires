#import table: cell, header

= Analyse des risques

La mise en place d’un système IoT pour la prévention des feux de forêt comporte plusieurs risques techniques et organisationnels qui peuvent compromettre son efficacité.

#figure(caption: [Matrice de risques], [
#set text(9pt)
#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 10pt,
  align: horizon,
  header(
     [], [Mineur], [Modéré], [Majeur], [Catastrophique],
  ),
  [Très#linebreak()fréquent], 
  cell(fill: red.lighten(20%),[]), 
  cell(fill: red.lighten(20%),[]), 
  cell(fill: black.lighten(40%),text(fill: white)[]), 
  cell(fill: black.lighten(40%),text(fill: white)[]),
  
  [Fréquent], 
  cell(fill: orange.lighten(50%),[]), 
  cell(fill: red.lighten(20%),[Perte de données\ \ Qualité des données]), 
  cell(fill: red.lighten(20%),[]), 
  cell(fill: black.lighten(40%),text(fill: white)[]),
  
  [Possible],
  cell(fill: yellow.lighten(50%),[]), 
  cell(fill: orange.lighten(50%),[] ), 
  cell(fill: red.lighten(20%),[Faux positifs\ \ non conformité\ légal]), 
  cell(fill: red.lighten(20%),[Incendie non détecté]), 
  
  [Rare],
  cell(fill: yellow.lighten(50%),[]), 
  cell(fill: yellow.lighten(50%),[Cyberattaque]), 
  cell(fill: orange.lighten(50%),[]), 
  cell(fill: red.lighten(20%),[Perte de disponibilité]), 
)
])


== Perte de données

Un premier risque concerne la perte de données, qui peut survenir en cas de dégradations matérielles (par des animaux ou des actes de vandalisme), de pannes réseau (interférences locales ou coupure globale) ou encore de problèmes électriques (panne d’alimentation, court-circuit, surtension). 
L’architecture du réseau doit donc prévoir des mécanismes de redondance (réseau maillé, plusieurs passerelles, priorisation des flux critiques).

== Qualité des données

Avoir des capteurs opérationnels ne suffit pas : encore faut-il que les données remontées soient fiables. 
Or, en pleine forêt, la qualité des relevés peut rapidement se détériorer. 
Avec le temps, des branches, de la poussière ou de la mousse peuvent obstruer les capteurs ; certains équipements peuvent dériver ; des capteurs peuvent être en dehors de leur plage de fonctionnement (tension électrique par exemple) et fournir de mauvaises valeurs. 
À cela s’ajoute le risque de recevoir de mauvaises données issues de sources externes (par exemple de l'API météo). 

== Cyberattaque

Tout système connecté est une cible potentielle, et celui-ci ne fait pas exception. 
Une attaque de type « Man-in-the-Middle » pourrait par exemple intercepter ou modifier les données en transit. 
Un attaquant pourrait injecter de fausses alertes… ou en masquer de vraies. 
Une compromission de la base centrale permettrait même de modifier les historiques ou les seuils d’alerte. 
Sans protection suffisante, un tel scénario pourrait remettre en question la crédibilité du système. 

== Perte de disponibilité

Même sans attaque, un système peut devenir inutilisable à cause d’une surcharge ou d’un simple bug serveur. 
Les problèmes serveurs constituent une menace majeure : attaque par DoS, surcharge, panne ou mauvaise configuration.
Ces problèmes peuvent entraîner une perte de disponibilité ou une altération de l’intégrité des données.
Si la plateforme centrale tombe en panne, le système ne peut transmettre d’alerte en temps réel, ce qui annule tout l’intérêt du dispositif. 

== Faux positif ou incendie non détécté

Un système de détection automatisé n’est jamais parfait, et deux erreurs opposées peuvent se produire : ne pas détecter un incendie réel (faux négatif), ou déclencher régulièrement des fausses alertes (faux positif). 
Le premier cas est évidemment le plus critique, mais le second ne doit pas être négligé, car un système qui alerte trop souvent finit par ne plus être pris au sérieux par les équipes terrain. 

== Non-acceptation

Même avec une technologie performante, le système peut échouer si les utilisateurs finaux ne l’adoptent pas réellement. 
Plusieurs scénarios peuvent poser problème : des opérateurs qui ignorent ou contournent une alerte parce qu’ils n’ont pas confiance dans l’outil, des équipes terrain qui ne sont pas formées à l’interprétation des indicateurs, ou encore un manque de coordination entre les différents acteurs.
Le risque n’est pas technique ici, mais lié à l’usage : un mauvais alignement entre les procédures existantes et les nouvelles fonctionnalités peut entraîner une incompréhension, voire un rejet. 

== Risques environnementaux

Installer des capteurs, caméras ou antennes en forêt n’est pas neutre. Certaines zones protégées comme les réserves naturelles ou les espaces classés Natura 2000 imposent des restrictions strictes sur les installations permanentes.
Enfin, l’ajout d’équipements physiques peut être perçu comme une pollution visuelle ou une perturbation écologique, notamment pour certaines espèces sensibles aux perturbations lumineuses ou électromagnétiques. 

#figure(caption: [Bow tie], image("figs/bowtie.png"))
