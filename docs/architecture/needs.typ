= Analyse utilisateurs

== Utilisateurs

- Gardes-forestier
- Centre Opérationnel Départemental d’Incendie et de Secours (CODIS)
- Police scientifique
- Scientifique
- Équipe de maintenance

== Story telling

=== Scénario 1 : Détection incendie

Je suis opérateur au CODIS, en charge de la surveillance et de la coordination des secours dans le département.

Je reçois une notification d’alerte automatique indiquant une hausse anormale de la température et la présence de fumée dans une zone forestière.

Je visualise immédiatement la zone concernée sur la carte fournie par l’application du système.

La zone suspecte apparaît en rouge, accompagnée des informations précises de localisation et des relevés des capteurs environnants.

J'accède ensuite au flux en direct de la caméra optique installée à proximité du foyer détecté.

Les images confirment la présence d’un départ de feu actif.

Le système me fournit automatiquement une analyse prédictive de propagation, indiquant les zones alentour vers lesquelles le feu est susceptible de se déplacer, en tenant compte du vent, de la température et de la topographie.

Je déclenche la procédure d’intervention et dépêche immédiatement les équipes de sapeurs-pompiers les plus proches sur place.

=== Scénario 2 : Prévention incendie

De fortes chaleurs sévissent depuis plusieurs jours et certains bois sont très sec.

Je suis le garde forestier en charge de la zone

Le système me notifie lors du dépassement de certains seuil et me propose une carte des zones à risque

Il me propose des zones à débroussailler de manière préventive et à interdire d'accès

Je prend les mesures nécessaires sur la zone et je suis particulièrement vigilant

=== Scénario 3 : Analyse des données

Un incendie semblant être d’origine criminelle a eu lieu dans une zone forestière équipée du système de prévention.

En tant que membre de la police scientifique, je suis chargé d’analyser les données enregistrées par le système au moment de l’incident.

J’accède à l’historique des images capturées par les caméras situées à proximité du point de départ du feu.

Je consulte également les données des capteurs (température, CO₂, fumée, etc...) collectées durant la même période.

En croisant ces informations, je peux reconstituer les événements et identifier la zone exacte d’origine du feu.

Les éléments visuels et les données capteurs sont utilisées pour étoffer les informations de l'enquête.

#pagebreak()

== User stories

En tant qu'opérateur chez le CODIS,
je veux que le système m'indique les zones à risque,
afin d'agir en conséquences

#line(length: 100%)

En tant qu’opérateur chez le CODIS,
je veux être notifié en cas d’incendie et pouvoir visualiser la ou les zones concernées par l’alerte,
afin de pouvoir confirmer qu’un incendie a bien lieu et dépêcher une équipe de pompier sur place.

#line(length: 100%)

En tant qu'opérateur chez le CODIS,
je veux pouvoir prédire les zones sur lesquelles le feu risque de se propager,
afin d’anticiper l’évolution du front de feu, et d’orienter les équipes d’interventions pour faciliter le travail des pompiers

#line(length: 100%)

En tant qu'opérateur chez le CODIS,
je veux que le système s'adapte en cas de perte de données,
afin de conserver une couverture sur l'ensemble de la zone

#line(length: 100%)

En tant que garde forestier,
je veux que le système m'alerte au plus vite en cas d'augmentation du risque incendie pour une zone de la forêt
afin de pouvoir limiter son accès et programmer un débroussaillage préventif.

#line(length: 100%)

En tant que garde forestier,
je veux que le système m'alerte au plus vite en cas de détection d'un début d'incendie,
afin que je puisse me rendre sur place pour assurer la sécurité des personnes et l'éteindre si son ampleur me le permet.

#line(length: 100%)

En tant que police scientifique,
je veux avoir accès aux données enregistrées par le système,
afin pouvoir mener des recherches sur l'origine d'un incendie

#line(length: 100%)

En tant que chargé de la maintenance,
je veux être informé en cas de défaillance capteurs,
afin de pouvoir planifier son remplacement

#line(length: 100%)

En tant que développeur du système,
je veux avoir accès aux données historiques,
afin de pouvoir faire évoluer le modèle en fonction des remontés du terrain.
