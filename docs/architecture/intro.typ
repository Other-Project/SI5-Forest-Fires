= Description du projet

La prévention et la gestion des incendies de forêt représentent aujourd’hui un enjeu majeur, tant pour la protection de l’environnement que pour la sécurité des populations et des infrastructures. 
Un système basé sur l’Internet des Objets (IoT) permet d’apporter une réponse innovante et efficace à ces défis.

== Forêt intelligente et prévention proactive

L’intégration de capteurs connectés, de caméras thermiques et de systèmes de détection rend la forêt « intelligente ». 
Les données collectées en temps réel permettent d’identifier les signaux faibles d’un départ de feu et de déclencher des alertes immédiates avant que la situation ne devienne critique.

== Analyse des risques d'incendie et cartographie dynamique

Un module de cartographie interactive évalue en continu le risque d’incendie par secteur, en prenant en compte plusieurs paramètres :

- conditions météo (humidité du sol et de l’air, vent, chaleur, sécheresse, ...),
- caractéristiques du terrain (type d’arbres, densité de végétation, éléments naturels coupe-feu, topographie),
- proximité des habitations et infrastructures sensibles,
- accessibilité pour les secours.

Cette analyse permet de hiérarchiser les zones à surveiller et de renforcer la prévention dans les secteurs les plus vulnérables.

== Détection avancée des menaces

Notre système offrent plusieurs couches de détection :

- caméras thermiques pour repérer les points de chaleur anormaux,
- caméras optiques pour identifier les fumées
- capteurs environnementaux pour mesurer les seuils critiques (humidité de l'air, humidité du sol, pluviométrie, température, vitesse du vent, pression de l'air, présence de gaz).

La combinaison de ces données améliore considérablement la précision des alertes.
  
== Réduction du risque de propagation

En analysant la topographie, la densité forestière, et les données météorologiques remontées par nos capteurs (telles que l'humidité et le vent) le système peut anticiper les trajectoires probables d’un incendie. 
De plus, il peut suggérer des actions de prévention ciblées comme le débroussaillage ou le déboisement sélectif dans des zones stratégiques pour limiter la propagation des flammes.

== Communication et alerte en temps réel

Un élément essentiel du projet est la capacité à notifier rapidement le centre de traitement de l'alerte (CTA) au sein du centre opérationnel départemental d'incendie et de secours (CODIS) de rattachement. 

En cas de dépassement de seuil critique de risque incendie (Température > 30 °C, humidité de l’air < 30 %, Indice Forêt Météorologique (IFM) ≥ 40, ...) ou en cas de détection d’un départ de feu, le système alerte le CTA en lui indiquant l'ensemble des données de la zone concernée.

Cette réactivité améliore le traitement préventif des forets et le temps nécessaire à la coordination des pompiers au travers du CODIS lors de départ d'incendie.

== Valeur ajoutée du projet

Le projet apporte une valeur ajoutée majeure à la prévention et à la gestion des incendies de forêt en combinant détection précoce, analyse prédictive, transmission instantanée de l’information et déclenchement automatisé d'alertes.

Grâce à notre réseau de capteurs et caméras, les départs de feu sont identifiés avant qu’ils ne deviennent incontrôlables, améliorant ainsi la réactivité des secours par conséquent les dommages. 

La connaissance fine du terrain et des risques par le système permet de produire une cartographie dynamique du risque et donc d’anticiper la propagation potentielle des flammes et d’adapter les actions préventives sur les zones les plus vulnérables. 
En offrant une vision en temps réel de l’état de la forêt et des conditions environnementales, le système optimise la surveillance, la prise de décision et la coordination des acteurs.

== Contraintes

Sur le plan environnemental, l’installation de capteurs, caméras et antennes peut entraîner une pollution visuelle et être perçue comme une dégradation du paysage naturel. Les équipements introduisent également une empreinte écologique, notamment par l’utilisation de batteries et de matériaux potentiellement polluants, ou par les perturbations qu’ils peuvent provoquer sur la faune locale. Il est donc essentiel de minimiser l’impact du dispositif et de garantir sa parfaite intégration dans l’écosystème forestier.

L’énergie constitue également une contrainte majeure. Les zones forestières sont souvent difficiles d’accès, ce qui rend la maintenance et le remplacement des sources d’alimentation complexes et coûteux. Les dispositifs doivent assurer une autonomie durable, capable de supporter un fonctionnement continu sur plusieurs années. Le choix de solutions énergétiques résilientes, telles que des systèmes solaires ou des technologies basse consommation, est indispensable pour éviter toute interruption de surveillance pouvant compromettre la détection précoce des incendies.

À cette difficulté s’ajoute celle de la connectivité. Les réseaux traditionnels (comme la 4G ou la 5G) étant rarement disponibles en milieu forestier, il est nécessaire de mettre en place une infrastructure de communication dédiée. Les technologies longue portée et faible consommation (par exemple LoRaWAN) doivent garantir l’acheminement fiable des données en temps réel vers les centres de supervision. Le réseau doit rester opérationnel, même dans des conditions extrêmes telles que la dégradation des équipements causée par un incendie, ce qui nécessite des solutions robustes et redondantes.

Enfin, le projet doit relever des défis économiques et organisationnels importants. Le déploiement initial représente un investissement considérable, auquel s’ajoutent les coûts de maintenance, de gestion des données et de renouvellement du matériel. Sa pérennité suppose ainsi un modèle financier viable, soutenu par des partenariats publics et privés.

== Domain Driven Design

#figure(caption: [Machine à état métier], scale(60%, reflow: true, include("figs/etat_metier.typ")))

#figure(caption: [Context map], scale(80%, reflow: true, include("figs/context_map.typ")))


=== Domaines principaux

- Détection d’incendie :
  Analyse en temps réel des données remontées pour identifier les signes précurseurs d’un départ de feu et déclencher des alertes précises dès qu’un seuil critique est atteint .

- Propagation de l’incendie :
  Anticipe la trajectoire et la vitesse de propagation des flammes en analysant la topographie, la densité de végétation et la direction du vent. 
  Aide à identifier les zones à risque afin de planifier les interventions et l'évacuation des zones menacées.

- Évaluation du risque d’incendie :
  Calcule dynamiquement le niveau de risque incendie par zone forestière en tenant compte de multiples paramètres : conditions météorologiques, sécheresse, type de sol, végétation, proximité d’habitations ou de routes. Cette analyse prédictive offre une vision dynamique et hiérarchisée du niveau de danger.

===  Domaines de support

- Gestion des capteurs :
  Un mécanisme d’auto-diagnostic identifie automatiquement les capteurs défectueux ou déconnectés afin d’assurer la continuité et la qualité des données collectées.

- Visualisation et historique : 
  Les informations issues du réseau IoT (données des capteurs et des images capturées par les caméras) sont centralisées dans une interface permettant leur exploitation par les autorités, chercheurs ou opérateurs. Cette base de données facilite le suivi en temps réel et l’analyse historique des phénomènes.     

- Communication et alertes :
  Lorsqu’un risque ou un incendie est détecté, le système émet des alertes automatiques à destination des gardes forestiers et du CODIS, avec la localisation exacte du danger.

- Infrastructure Réseau :
  Garantit la connectivité fiable en milieu forestier via des technologies LoRaWAN. Assure la redondance et la résilience des communications même en conditions extrêmes.

=== Domaines génériques

- Gestion énergétique :
  Maximise la durée de vie des batteries et gère les sources d'énergie alternatives (solaire). Prédit les besoins de maintenance énergétique.

- Supervision Environnementale :
  Mesure et archive en continu les paramètres environnementaux. Fournit les données brutes aux autres sous-systèmes.
  