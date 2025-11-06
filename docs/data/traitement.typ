= Pré-traitements

#figure(caption: [Chaîne de pré-traitements], include("figs/traitements.typ"))

== Calibration

Pour garantir la fiabilité des mesures de chaque capteur, un calibrage est réalisé à partir de valeurs de référence. Concrètement, de manière régulière, la valeur de chaque capteur est comparé à une valeur connue, permettant de détecter et corriger d’éventuels biais ou déviations systématiques propres au capteur.

Cette approche assure que les mesures reflètent fidèlement la réalité locale de chaque zone. Il est important de noter que, même après calibration, des différences entre zones peuvent subsister : elles reflètent les variations naturelles de l’environnement (ensoleillement, topographie, humidité, etc.). Ainsi, le calibrage garantit la précision de chaque capteur, tandis que les variations interzones sont conservées.

== Compression

Afin d’optimiser la transmission des informations et de réduire la quantité de données envoyées, les mesures collectées par le capteur sur la période écoulée depuis le dernier envoi sont compressées en une seule valeur représentative. Cette compression repose sur un traitement statistique fondé sur une moyenne pondérée, conçue pour refléter à la fois la stabilité générale du signal et les évolutions récentes susceptibles d’indiquer une anomalie.

Concrètement, chaque mesure enregistrée au cours de la période reçoit un poids dans le calcul de la moyenne. La majorité des valeurs, correspondant au comportement habituel du capteur, conservent un poids standard. Toutefois, si une évolution significative est détectée vers la fin de la période (par exemple une hausse progressive des valeurs pouvant signaler un début de phénomène anormal), les mesures les plus récentes sont pondérées plus fortement.

== Discrétisation

Les capteurs mesurent des grandeurs sous forment de valeurs analogiques. Afin de réduire la volumétrie des données, nous procédons à une discrétisation des données. Cette discrétisation est adapté pour chaque type de capteur en fonction de sa plage de fonctionnement et de sa précision.

== Annotation des données 

Chaque donnée collectée par le système est associée à un identifiant unique correspondant à la station à laquelle appartient le capteur. Cet identifiant permet de retracer l’origine des mesures et d’assurer une traçabilité complète des données.

Chaque mesure est également horodatée avec la date et l’heure précises de collecte (sous forme d'un timestamp UNIX). Cette information temporelle est essentielle pour reconstituer la chronologie des événements et analyser l’évolution des paramètres dans le temps. 

En complément, le niveau de batterie de chaque station est transmis à chaque envoi de données. Cette information garantit la véracité et la fiabilité des mesures, en permettant de détecter toute anomalie potentielle liée à une tension trop faible. De plus, elle offre la possibilité de planifier la maintenance préventive des stations, notamment le remplacement des batteries avant qu’elles ne deviennent critiques.

Les messages transmis par les stations contiennent donc à la fois les valeurs mesurées et un ensemble de métadonnées techniques permettant leur identification, leur datation et le suivi de l’état matériel. Ces métadonnées suivent la structure suivante :
```c
struct {
    uint16_t device_id;      // Identifiant de l'appareil
    uint32_t timestamp;      // Date et heure du message
    uint8_t battery_voltage; // Tension de la batterie en pas de 10 mV
    uint8_t statut_bits;     // Bits de statuts (1er bit pour charge/décharge)
};
```

Une fois les données transmises au fog, le système utilise l’identifiant de chaque message pour lui associer les données relatives à la station correspondante (la position géographique, zone de rattachement dans la forêt). 

La position exacte permet de croiser les informations provenant de plusieurs stations et d’effectuer des analyses en tenant compte de leur emplacement. Ainsi, lorsqu’un événement anormal est détecté, il est possible de vérifier si des stations voisines enregistrent des variations similaires, ce qui renforce la fiabilité et la pertinence de la détection.
