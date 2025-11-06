= Impacts architecturaux et fonctionnels

== Perte de données

Pour éviter la perte de données le protocole de transmission que nous avons choisi (LoRaWAN) permet le routage des messages par plusieurs passerelles, ce qui est utile en cas de défaillance de l'une d'elles.

Nous prévoyons aussi une double alimentation au niveau des passerelles (batterie + solaire) pour éviter la perte de transmission liée à une panne énergétique.

Pour éviter une perte d'énergie au niveau des stations capteurs, nous transmettons le niveau des batteries, ce qui permet d'être alerté avant qu'elles ne se vident.

Nous effectuons aussi un suivi de l’absence de perte de données grâce à une vérification automatique des paquets transmis.

En cas de perte ou d’interruption de transmission, le système met en œuvre des mécanismes d’inférence de données permettant d'estimer les valeurs manquantes à partir des mesures précédentes ou valeurs des capteurs voisins.

== Qualité des données

Pour garantir la cohérence du système, nous allons intégrer des contrôles automatiques.
Cela inclura la comparaison entre capteurs proches, la détection d’anomalies statistiques, l'alerte en cas de dérive importante et la surveillance de l'état du système lui-même.

== Risques de sécurité

Pour maîtriser les risques de sécurité, nous allons concevoir le système en intégrant la sécurité dès sa conception. 

Nous mettrons en œuvre le chiffrement systématique des échanges, l'authentification forte entre les équipements, la journalisation des accès et la segmentation du réseau pour contenir d'éventuelles compromissions.

== Perte de disponibilité

Pour éviter la perte de disponibilité, nous concevons un système capable de fonctionner sans cloud, grâce à un traitement sur le fog et l'envoi d'alertes push depuis celui-ci.

Les paquets LoRaWAN sont reçu par plusieurs antennes, ce qui permet de limiter l'impact de la perte de l'une d'entre-elles.

== Mauvaise détection ou mauvaise prévention

Pour éviter une mauvaise détection ou une mauvaise prévention, nous allons concevoir le système pour qu'il associe un niveau de confiance à ses alertes. 
Nous conserverons un historique des données pour affiner continuellement les algorithmes. Enfin, nous nous assurerons que toute alerte soit explicable.

== Acceptation

Pour assurer l'acceptation du système, nous prévoyons une phase d'accompagnement lors le déploiement. 
Cet accompagnement comprendra des formations, une documentation claire, des démonstrations concrètes et une écoute active des retours terrain.

== Risques environnementaux

Pour minimiser l'impact environnemental, nous limitons la densité de capteur à déployer. Et nous utiliserons un matériel discret, par exemple grâce à une peinture camouflage ou une intégration paysagère.

Nous anticiperons aussi les démarches administratives en amont, et nous garantirons que la collecte des données respecte strictement la réglementation en vigueur. 
