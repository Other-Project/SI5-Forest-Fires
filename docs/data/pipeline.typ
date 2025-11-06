= Data Ingestion Pipeline

== Messages en transits

#figure(caption: [Vue de la circulation des données au travers des topics], include("figs/pipeline.typ"))

Données Brutes (exemple pour une centrale météo: `/captors/meteo/50/raw`)
```json
{
  "metadata": {
    "device_id": 50,
    "timestamp": 1761955200,
    "battery_voltage": 360,
    "statut_bits": 0
  },
  
  "temperature": 162,
  "air_humidity": 60,
  "soil_humidity": 30,
  "air_pressure": 10132,
  "rain": 10,
  "wind_speed": 16,
  "wind_direction": 360  
}
```

#pagebreak()

Données Traitées (exemple pour une centrale météo: `/captors/meteo/50/data`)
```json
{
  "metadata": {
    "device_id": 50,
    "location": {
      "latitude": 43.700123,
      "longitude": 7.266012,
      "altitude": 305.5 
    },
    "forest_area": "grand_sambuc",
    "timestamp": "2025-11-01T00:00:00Z",
    "processed_timestamp": "2025-11-01T00:20:00Z",
    "battery_voltage": 3.6,
    "is_charging": false,
    "data_quality_flag": "OK"
  }, 
  
  "temperature": 20.5,
  "air_humidity": 0.6,
  "soil_humidity": 0.3,
  "air_pressure": 1013.2,
  "rain": 2,
  "wind_speed": 3.2,
  "wind_direction": 180
}
```
Détection d'Incendie (`/maps/fire/grand_sambuc`)
```json
{
  "type": "fire",
  "analysis_timestamp": "2025-11-01T00:45:00Z",
  "forest_area": "grand_sambuc",
  "fire_detected": true,
  "confidence_score": 0.99,
  "hotspot_location": {"latitude": 43.6800, "longitude": 7.2500},
  "severity_index": 4 
}
```
Alerte d'Équipement (`/alerts/maintenance/meteo/50`)
```json
{
  "device_id": 50,
  "location": {
    "latitude": 43.700123,
    "longitude": 7.266012,
    "altitude": 305.5 
  },
  "forest_area": "grand_sambuc",
  "timestamp": "2025-11-01T00:00:00Z",
  "processed_timestamp": "2025-11-01T00:05:00Z",
  
  "type": "maintenance",
  "alert_id": "MAINT_BATTERY_01",
  "message": "Niveau de batterie faible (inférieur à 20%). Intervention requise.",
}
```
== Mise en œuvre / Maintenance

La réussite du projet repose sur une mise en œuvre méthodique et sur l'établissement de procédures de maintenance rigoureuses pour garantir la fiabilité et la pérennité du système.

=== Mise en œuvre (Déploiement)

La mise en œuvre du système s’articule autour de deux volets complémentaires, le déploiement sur le terrain (Edge) et l’installation de l’infrastructure de traitement et de stockage (Fog/Cloud).

Le déploiement sur le terrain vise à assurer une couverture optimale du réseau et la fiabilité des mesures collectées. Il débute par une cartographie des zones d’intérêt, afin de sélectionner les emplacements les plus pertinents pour l’installation des centrales météo et les capteurs de gaz.

Les caméras thermiques et optiques ainsi que les passerelles LoRaWAN seront installées sur les tours de guet ayant une connexion réseau.
L’installation comprend également la mise en place des systèmes d’alimentation (panneaux solaires et batteries) sur les tours dans les cas où une installation électrique n’est pas déjà disponible. 
Une fois les équipements installés, des tests de connectivité sont réalisés pour vérifier la qualité du signal (RSSI#footnote[Received Signal Strength indicator], SNR #footnote[Signal to noise ratio]) entre les capteurs et les passerelles, ainsi que la bonne transmission des premiers messages MQTT vers l’infrastructure de traitement.

Le déploiement de l’infrastructure de traitement et de stockage se concentre sur la mise en place du pipeline de données. Les services de base sont déployés sous forme de conteneurs (via Kubernetes ou Docker Compose) et comprennent le broker MQTT, le cluster Redpanda, les services et les instances de stockage (InfluxDB et MinIO). Le pipeline est configuré pour assurer l’ingestion fluide des données grâce à un pont MQTT–Redpanda, et intègre des micro-services dédiés au pré-traitement ainsi qu’à l’analyse, à l’aide de modèles tels que Rothermel, Huygens et FWI (@algo). Des tests de performance et de résilience sont ensuite menés pour simuler des charges importantes provenant des capteurs et des caméras, afin d’évaluer le débit de Redpanda, le temps de réponse d’InfluxDB et l’efficacité des mécanismes d’auto-redémarrage.

=== Maintenance Opérationnelle

La fiabilité de notre système de surveillance reposent sur une stratégie de maintenance complète, organisée autour de trois axes principaux : l'entretien préventif sur site, la gestion corrective à distance, et l'évolution logicielle.

La maintenance préventive permet d'anticiper toute défaillance matérielle et de garantir l'exactitude des données. Il est prévu de faire inspections trimestrielles au cours desquelles auront lieux des vérifications sur l'état physique des boîtiers pour détecter toute corrosion ou problème de fixation. Nous contrôlons également l'intégrité des capteurs, en veillant à l'absence d'obstruction ou de dépôts. 

De plus, un recalibrage annuel des capteurs est essentiel, les capteurs de gaz, d'humidité et les thermomètres étant naturellement sujets à la dérive. Pour y remédier, nous procédons soit au remplacement des capteurs, soit à l'ajustement des courbes de calibration en utilisant des mesures de référence précises. 

Enfin, un nettoyage optique régulier est indispensable pour les lentilles des caméras thermiques et optiques, assurant ainsi une qualité d'image non dégradée par la poussière, la sève ou l'humidité.

Une maintenance corrective et surveillance à distance assure la réactivité et permet un diagnostic rapide des incidents grâce à une surveillance continue du système. Nous utilisons des outils de monitoring en temps réel pour surveiller en permanence la latence des messages, le taux de perte de données. Des seuils d'alerte critiques sont établis à partir des données d'annotation, notamment pour la tension de la batterie. Si cette tension passe sous un seuil critique, une alerte est déclenchée, ce qui nous permet de planifier une intervention avant la défaillance totale du capteur. Le diagnostic de pannes est facilité par le traçage des données à l'aide de l'identifiant unique de la station, permettant une identification rapide des capteurs défaillants ou des problèmes de connectivité LoRaWAN.

La maintenance logicielle garantit la sécurité de la plateforme et l'amélioration continue de ses capacités d'analyse prédictive. Nous assurons des mises à jour de sécurité régulières, appliquant des correctifs aux systèmes d'exploitation et à toutes les dépendances logicielles critiques (Redpanda, InfluxDB, MinIO, librairies de Machine Learning) pour prévenir les vulnérabilités. 

L'efficacité du modèle d'analyse prédictive (YOLOFM, FWI, Rothermel/Huygens) nécessite un ré-entraînement périodique. Ce processus utilise de nouvelles données, y compris des faux positifs et des feux réels, afin de maintenir et d'améliorer constamment sa précision. L'infrastructure MinIO sert de référentiel central pour ces jeux de données d'entraînement. 

Enfin, nous gérons la rétention des données en configurant des politiques de down-sampling dans InfluxDB pour les données très anciennes. Cette démarche optimise l'espace de stockage tout en conservant les données nécessaires à l'analyse et au ré-entraînement des algorithmes.

== Couches technologiques

=== MQTT

Notre architecture de communication entre la couche edge et la couche fog repose sur le protocole MQTT. Ce choix a été dicté par les contraintes matérielles et opérationnelles : une faible puissance de calcul, une mémoire limitée et une connectivité réseau cellulaire parfois capricieuse, pouvant souffrir d'une bande passante réduite ou de latences importantes.

Dans ce contexte, MQTT s’est rapidement imposé comme la solution la plus adaptée. Son modèle de publication/souscription, léger et asynchrone, ainsi que sa conception minimaliste en font un protocole idéal pour les environnements limités. Il permet de réduire la consommation énergétique, la charge processeur et l’empreinte mémoire, tout en restant résilient face à des réseaux intermittents.

À l'inverse, une communication directe avec un client type Kafka, bien que techniquement possible, se serait avérée contre-productive dans notre cas. L'infrastructure et les clients Kafka sont intrinsèquement plus gourmands en ressources, conçus pour des débits élevés et une forte fiabilité des communications. 

MQTT joue donc un rôle d’intermédiaire. Il collecte les données, puis les retransmet via un bridge dédié vers l’écosystème en fog, où elles sont traitées, analysées et stockées de manière intensive.

=== Redpanda

Pour le cœur de notre fog et de notre cloud, nous souhaitions utiliser une solution de type Kafka pour sa capacité à gérer des flux de données massifs en temps réel, son modèle de publication/souscription à haut débit et sa garantie de durabilité des messages.

Redpanda représente l'évolution naturelle de la technologie Kafka.
Il s'agit d'une réécriture moderne en C++, entièrement compatible avec l'écosystème Kafka au niveau de son API. 
Cette fondation technique lui permet de se séparer des inconvénients de son aîné : Redpanda est conçu dès l'origine pour être plus performant, avec une latence réduite et un débit accru, tout en étant significativement plus facile à déployer et à administrer. 

C'est donc tout naturellement que notre choix s'est porté pour cette solution.

== Algorithmes <algo>

=== Détection de feu

Pour la détection d’incendie via caméra, nous prévoyons d’utiliser le modèle YOLO-FM. Ce modèle est une variante optimisée de YOLO, spécialement conçue pour la détection de fumée. Il combine rapidité et précision grâce à une architecture de réseau neuronal convolutif (CNN) allégée mais performante. Cette approche permet une détection visuelle en temps réel, qui vient compléter les mesures des capteurs environnementaux. (température, CO₂, etc.). @yolofm.

Pour la détection d'incendie via capteurs environnementaux, nous prévoyons d’utiliser un modèle de machine learning (par exemple Random Forest). L’objectif est de permettre au système d’identifier automatiquement les situations anormales pouvant indiquer un début d’incendie. Le principe consiste à entraîner le modèle sur un ensemble de données comprenant à la fois des situations normales et des situations d’incendie. Le modèle apprendra ainsi à reconnaître les combinaisons de valeurs caractéristiques d’un départ de feu. 
Une fois intégré dans notre système, lorsque un pic de données est détecté par l’un de nos capteurs, nous utiliserons le modèle avec les valeurs issues de nos différents capteurs afin de déterminer si ces variations sont significatives d’un départ d’incendie.
  
=== Détection de la propagation du feu

Le modèle de Rothermel est un modèle empirique qui permet d’estimer la vitesse de propagation du front de feu (Rate of Spread) à partir de paramètres physiques du milieu. Il prend en compte les caractéristiques du combustible (type de végétation, densité, humidité, hauteur du lit), les conditions météorologiques (vent, température, humidité de l’air) et la topographie (pente, orientation). Ce modèle calcule, pour chaque zone, la vitesse locale de propagation et la direction probable du front. @maths_pred_fire @model_wind

La méthode de Huygens, quant à elle, repose sur une approche géométrique de la propagation. Chaque point du front de feu est considéré comme une source d’onde qui se propage selon une forme elliptique dépendant du vent et de la pente. L’enveloppe de ces ellipses définit la nouvelle position du front après un certain temps. Cette méthode permet de modéliser de manière réaliste la forme et la direction du front dans un environnement complexe et de produire une carte de propagation du feu à partir des vitesses calculées par le modèle de Rothermel. @prop_slope

Combinés, ces deux modèles offrent une approche robuste pour une de propagation d'incendies de forêt : Rothermel fournit la vitesse locale de propagation, tandis que Huygens met à jour la position géométrique du front. Ensemble, ils permettent d’estimer non seulement où le feu risque de se propager, mais aussi à quelle vitesse.

=== Calcul du risque d'un feu

Il existe un indicateur permettant d’évaluer le risque de départ et de propagation des feux de forêt : l’Indice Forêt Météo (IFM), également appelé Fire Weather Index (FWI). Développé initialement par le Service canadien des forêts, l’Indice Forêt Météo est un indicateur calculé à partir de données météorologiques : la température de l’air, l’humidité de l’air, la vitesse du vent, et les précipitations des dernières 24 heures. Ces données sont utilisées pour estimer plusieurs sous-indices qui modélisent la teneur en eau de différents types de combustibles végétaux, puis pour produire un indice global de danger de feu.
@fwi @ifm

Dans notre système, ces variables sont directement mesurées par les capteurs locaux. Cette adaptation permet d’obtenir une évaluation locale en temps réel du risque d’incendie, sans dépendre des prévisions météorologiques. De plus, nos capteurs permettent de récolter d’autre données tels que l’humidité du sol, et les gaz. Ces paramètres agissent donc comme des facteurs amplificateur du risque, venant renforcer l’indice lorsque la sécheresse du sol est importante ou que des gaz sont détectés.


== Stockage

Nous utiliserons InfluxDB pour le stockage temporel des données capteurs non-traitées comme traitées. Chaque donnée étant associée à un timestamp, une base de données relationnelle classique (comme PostgreSQL) serait moins adaptée. Le choix d'InfluxDB se justifie par ses performances d'ingestion et de requêtage temporel, ainsi que par sa capacité de contrôle de la rétention (downsampling en fonction du temps passé).
De plus, nous souhaitions privilégier la Disponibilité (A) et la Tolérance aux Partitions (P) du Théorème CAP, au détriment d'une Cohérence (C) immédiate, ce à quoi correspond InfluxDB.

Nous avons choisi MinIO, une alternative open-source à S3 d'AWS pour le stockage d'historisation des données caméras. Nous y stockerons aussi les configurations des stations sous format JSON. MinIO est compatible avec l'API S3, offre une excellente scalabilité pour le stockage d'objets de grande taille, tout en garantissant une durabilité et une accessibilité adaptées à nos besoins de données non-structurées.
Pour un système de surveillance critique, pouvoir toujours enregistrer la donnée (A) en cas de défaillance réseau (P) est prioritaire sur la cohérence transactionnelle stricte, ce qui correspond bien aux propriétés de MinIO.

Finalement, sur notre plateforme centrale cloud, nous utiliserons à nouveau MinIO pour le stockage des cartes sous format GeoJSON générée à partir des données d'analyse.


== Communication

Nos centrales météos et nos capteurs de gaz communiquerons par LoRaWAN. 
LoRaWAN s'est imposé de part sa faible empreinte énergétique, chose importante pour ces capteurs qui fonctionneront sur batterie uniquement et sa longue portée, indispensable en forêt où les étendus sont larges.

Afin de bénéficier de la portée la plus importante possible, nous prévoyons d'utiliser le Data Rate 0 de la bande EU863-870 MHz. En revanche, cela nous impose un débit très restreint de 250 bits/s.

Le choix du Data Rate 0 de LoRaWAN limite la taille maximale du payload à 51 octets. Compte tenu du débit de 250 bits/s et de la contrainte réglementaire imposant un cycle de service (Max duty cycle) de 1%, le débit maximum utilisable pour l'application est réduit à seulement 2,5 bits/s.

Chaque message de capteur inclut des méta-données de traçabilité (ID de l'appareil, horodatage, niveau de batterie) représentant un volume fixe de 8 octets.

Pour la centrale météo, la somme des données brutes (11 octets) et des méta-données (8 octets) aboutit à un volume total de 19 octets, soit 152 bits. En se basant sur le débit maximum de 2,5 bits/s, la fréquence maximale théorique d'envoi est de 60.8 secondes. Nous retenons alors une fréquence d'échantillonnage de 1 minute 15.

Pour les capteurs de gaz, qui transmettent un volume de données brutes plus faible (8 octets), le message complet atteint 16 octets (128 bits). La fréquence maximale possible est alors de 51.2 secondes. Nous retenons aussi une fréquence d'échantillonnage de 1 minute.

== Résilience

La résilience du système est cruciale pour garantir la continuité de la surveillance et la fiabilité des alertes, en particulier dans un environnement critique comme la forêt où la connectivité et l'alimentation peuvent être précaires. Notre stratégie de résilience repose sur la sécurisation, la tolérance aux pannes et la capacité de récupération, englobant les couches physique, réseau et applicative.

===  Sécurité et Intégrité des Données

Des firewalls sont mis en place pour segmenter le réseau et isoler les différentes couches de l'architecture. Au niveau du Fog et du Cloud, ils contrôlent les flux entrants et sortants pour n'autoriser que les ports et protocoles nécessaires (ex: MQTT, Kafka/Redpanda, HTTPS), limitant ainsi la surface d'attaque et empêchant la propagation latérale d'éventuelles menaces.

Bien que LoRaWAN intègre un chiffrement, les données sont également chiffrées au niveau applicatif avant la publication sur le broker MQTT. L'utilisation de protocoles sécurisés (TLS/SSL) entre le broker MQTT et le bridge vers Redpanda prévient les attaques de type Man-in-the-Middle en s'assurant que seules les entités authentifiées peuvent décoder et ingérer les messages des capteurs.

=== Continuité des Services et Tolérance aux Pannes

Les équipements critiques, notamment les passerelles LoRaWAN et les caméras dans les tours de guet, ainsi que les serveurs du Fog et du Cloud, sont protégés contre les intrusions physiques, le vandalisme et les conditions environnementales extrêmes. Les boîtiers sont de robustesse élevée (IP65/67), et les locaux serveurs sont sécurisés par un accès physique contrôlé.

L'alimentation électrique des infrastructures critiques (Passerelles LoRaWAN, serveurs Fog, Cloud) est protégée par des onduleurs (UPS). Cela permet de maintenir l'activité pendant de courtes coupures et d'assurer une extinction propre des systèmes en cas de panne prolongée, prévenant ainsi la corruption des données ou des systèmes d'exploitation.

L'ensemble des services (Redpanda, InfluxDB, micro-services de traitement) est déployé via des conteneurs orchestrés (ex : Kubernetes ou Docker Compose). En cas de défaillance d'un service ou d'un nœud, l'orchestrateur s'assure de son redémarrage immédiat sur un autre nœud fonctionnel. Cette fonction d'auto-guérison minimise le temps d'interruption du pipeline d'ingestion.

Les outils de monitoring surveillent en temps réel l'état du système (utilisation CPU/mémoire, latence du pipeline, état de la réplication des bases, niveaux de batterie des capteurs). En cas de dépassement de seuils ou de panne, une alerte est immédiatement envoyée aux équipes de maintenance.

=== Sauvegarde et Récupération des Données

Une stratégie de sauvegarde est appliquée à toutes les couches de stockage :

- Redpanda assure une durabilité élevée grâce à la réplication des topics sur plusieurs nœuds.
- Des instantanés réguliers de la base InfluxDB et MinIO sont effectuées, permettant un retour arrière.