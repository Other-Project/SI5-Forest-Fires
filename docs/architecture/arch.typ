= Architecture

== Déploiement

#figure(caption: [Exemple de structure de déploiement], scale(50%, reflow: true, include("figs/global.typ")))

Les capteurs de gaz sont déployé le long des zones à risques (axes routiers ou habitations par exemple). Ils fonctionnent sur batterie et envoies les données récoltées par LoRaWAN à la passerelle.

Les capteurs météos sont rassemblés en un seul appareil (dit "centrale météo") qui sera déployé à des endroits représentatifs de la forets. Les centrales météos fonctionnent elles aussi sur batterie et envoies leurs données par LoRaWAN.

Les passerelles LoRaWAN sont déployées dans des zones dégagées et recevant le réseau cellulaire. Au même endroit, les caméras optiques et thermiques seront reliées à un seul dispositif qui communiquera les flux par réseau cellulaire et fonctionnera sur batteries rechargées par panneaux solaires. L'alimentation est partagée avec les passerelles LoRaWAN.

Le serveur de gestion de la forêt (ou agrégateur) sera chargé de tous les calculs liées aux données remontés et stockera les données.

Finalement, le serveur cloud fournira une interface unifiée entre les différentes forets gérées. Il ne stockera que les données générales (liées aux différentes cartographies proposées et aux alertes), les données plus précise seront obtenu par des requêtes au serveur agrégateur de la forêt concernée.

== Transit des données

#figure(caption: [Vue des sources de données], scale(70%, reflow: true, include("figs/data_sources.typ")))

La première étape concerne la collecte des données via des capteurs environnementaux (température, humidité, pression, gaz, etc.). Ces capteurs, connectés en LoRaWAN ou par liaisons filaires, transmettent leurs mesures à une passerelle locale qui les transmets à son tour à un agrégateur central. 

L'agrégateur de foret fusionne les données locales avec des sources externes telles que les prévisions météorologiques de Météo France, qui fournissent des données fiables sur les températures, les précipitations, la vitesse et l’orientation du vent, essentiels pour évaluer le risque d’incendie et modéliser sa propagation. 
Les images satellitaires, issues notamment de NASA FIRMS ou d’EUMETSAT, offrent une vue macro et permettent de détecter des points de chaleur ou des fumées naissantes à large échelle, complétant ainsi la détection locale. 
Les données de foudre, provenant de services spécialisés comme Kéranos ou Blitzortung, identifient les impacts de foudre susceptibles de déclencher un incendie, particulièrement dans les zones orageuses. 
Enfin, les données cartographiques et altimétriques de l’IGN, comme la BD TOPO ou le RGE ALTI, fournissent une modélisation fine du terrain, de la végétation et des infrastructures, permettant de contextualiser les alertes et d’affiner les prévisions de propagation.

Les données brutes sont conservées dans le fog, permettant une analyse locale rapide et un accès aux historiques. Seules les données traitées, telles que les cartes ou les alertes, sont envoyées vers le cloud.

Le fog est capable d'émettre des notifications push à la maintenance pour signaler une batterie faible, un capteur déconnecté ou envoyant des données incohérentes et aux gardes forestiers pour les alerter d'une élévation du risque d'incendie ou d'un départ de feu suspecté afin qu'ils puissent agir au plus vite avant l'arrivé de potentiels renforts.

Enfin, sur le cloud, les informations synthétisées sont accessibles via une interface globale, offrant des fonctions de visualisation, de consultation et de notification en temps réel aux gardes forestiers, CODIS et aux équipes scientifiques.

== Description détaillée

#figure(caption: [Vue des services], scale(80%, reflow: true, include("figs/services.typ")))

Les éléments déployés intègre tous un module de gestion de l'alimentation qui sera en capacité de donner les tensions et niveaux de charge des batteries, permettant ainsi de s'assurer que les capteurs sont dans des conditions normales d'utilisation et d'être alerté si un changement de batterie est nécessaire avant qu'il ne soit trop tard.

Ils contiennent aussi un module de configuration qui sera chargé de stocker les informations sur la station, à savoir son id et la date actuelle. Ces valeurs pourront être reconfigurées grâce à un message MQTT. Une autre partie de la configuration est stockée sous format JSON, coté fog dans MinIO (voir plus bas). Il y est stocké la position des stations (en fonction de leur id).

Un module d'annotation se chargera de construire le message contenant les données capteurs ainsi que les méta-données mentionnées précédemment (id station, date, niveau de batterie).

Dans le cadre des capteurs environnementaux (centrale météo ou capteurs de gaz), le message est transmis par un module de communication en utilisant LoRaWAN à une passerelle. Le protocole LoRaWAN a été choisi pour sa faible consommation énergétique et sa longue portée, tout deux étant nécessaire pour des systèmes déployées en forêt sur batteries. La passerelle se chargera de retransmettre le message au serveur fog au travers d'MQTT.

Pour les caméras, la transmission se fait en deux parties, le module de communication envoi les données batteries sur le topic MQTT dédiée et les flux caméras sont eux envoyé par RTP (Real-time Transport Protocol). Ce mécanisme en deux composantes était nécessaire car un flux image est trop lourd pour MQTT. RTP est un protocole particulièrement adapté pour ce genre de tache, puisqu'il permet le streaming quasi-temps réel de flux de données importants. Nous avons tout de même conservé une communication MQTT pour les batteries pour unifier le traitement de celles-ci. 

MQTT est utilisé en interface avec les dispositifs edge mais c'est en suite Redpanda, une alternative à Kafka, plus moderne et performante qui prend la relève pour le traitement. Redpanda Connect est utilisé pour faire le pont entre les deux plateformes.

Les données caméras sont archivés dans un data lake MinIO. Nous avons choisi MinIO car il constitue un équivalent open-source à S3 d'AWS et permet le stockage de masse de données de type objet.
Ces données sont aussi traitées au fur et à mesure par deux services intégrant un modèle d'IA. Un service sera dédié à la reconnaissance de fumée sur le flux optique, l'autre se chargera de déterminer les zones anormalement chaudes pouvant indiquer la présence d'un incendie.
Les résultats seront envoyés sur le topic dédiés au données traités (voir @mqtt).

Un service se charge de vérifier que les stations répondent et le niveau de batterie indiqué et émet des alertes en cas de problème.

Des données sont récupérer régulièrement depuis des acteurs externes par un service dédié qui stocke ces informations dans une base InfluxDB. 
Cette base InfluxDB est aussi utilisée pour sauvegarder les différentes données qui circulent de sorte à conserver un historique. Cet historique pourra être récupérer grâce à une API proposée par le fog. 
Elle permettra l'accès à l'historique vidéo, capteurs et d'analyse. L'API sera aussi utilisée pour la configuration à la fois du fog et des stations edge au travers d'un service dédié. 
Ce service stockera les données dans la base MinIO sous format JSON et effectuera un envoi minimal vers les stations si une mise à jour de leur configuration est demandée (le reste des informations de la station est obtenue par MinIO grâce à l'id de station).

Les données collectée et traitées sont utilisées par trois services qui correspondent à notre cœur métier:

- Le service de détection agrège les données pour identifier les anomalies et notifier d'un départ de feu

- Le service d’analyse de la propagation utilise les données topographiques (altimétrie, végétation, direction du vent) pour estimer la trajectoire probable du feu et les zones menacées à court terme

- Le service de prédiction combine les informations météorologiques (issues de services externes et des stations locales) et les données de terrains (altimétrie, végétation, présence de zone à plus forte activité humaine) afin de calculer un indice de risque d’incendie dynamique.

Un service de communication est chargé de réceptionner les alertes et les résultats d'analyse. Il est capable d’émettre des notifications push pour plus de réactivité. Il retransmet aussi ces infos à un cluster cloud Redpanda.

Celui-ci se charge d'agréger les informations générales de chaque foret pour permettre une gestion plus aisée.

Des services se chargent de mettre en forme les données reçus en vue d'être affichées (génération de GeoJSON par exemple).

Les données sont stocké dans une base MinIO accessible depuis l'extérieur via une API sur laquelle vont se greffer nos interfaces de visualisation (site web et application mobile).

Les données plus détaillées (flux caméra ou données de station par exemple), peuvent être obtenu au travers de l'API du cloud qui communiquera avec celle du fog.


== Topics <mqtt>

#box(fill: gray.lighten(80%), inset: 10pt, width: 100%, radius: 5pt, text(fill: gray.darken(50%), style: "italic")[
  Les messages échangées sont décrits plus en détail dans le rapport dédié aux données.
])

- `/captors`: 
  Topics liés aux stations terrains
  - `/captors/{type_station}`:
    Topics liés à un type précis de stations terrains (cameras, meteo, gaz)
    - `/captors/{type_station}/{id_station}`:
      Topics liées à une station précise
      - `/captors/{type_station}/{id_station}/raw`:
        Permet la remontée "crue" (non-traitée) des données capteurs de la station.
        Contient à minima les méta-données de la station telles que la date et le niveau de batterie.
      - `/captors/{type_station}/{id_station}/config`:
        Permet de configurer la station (id, date)
      - `/captors/{type_station}/{id_station}/data`:
        Les données traitées y transitent. Elles sont annotées avec l'id de station, la position de la station, la zone de rattachement, la date et l'heure de collecte et la confiance en la donnée.
- `/maps`:
  Topics liés aux sorties d'une analyse
  - `/maps/{type}`:
    Topics liés aux sorties d'une analyse spécifique\
    #pad(left: 10pt, text(size: .8em, fill: black.lighten(20%))[`fire` pour la détection d'incendie,\
    `evol` pour la prédiction de déplacement de l'incendie\
    et `risk` pour le risque de déclenchement d'incendie])
    - `/maps/{type}/{area}`:
      Sortie d'une analyse spécifique d'une zone de forêt donnée
- `/alerts`:
  Topics liés au différentes alertes
  - `/alerts/{type}`:
    Alertes de type spécifique
    - `/alerts/{type}/{equipement}`:
      Alertes de type spécifique relative à un équipement
- `/config`:
  Configuration générale pour le traitement
