#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern", lang: "fr")
#show raw: set text(size: 4.5pt)

#let _node(pos, label, tint, width: 30mm, id, ..args) = node(pos, label, stroke: tint + 2pt, fill: tint.lighten(90%), name: id, inset: 8pt, width: width, ..args)
#let _edge(from, to, tint, mark: "-|>", ..args) = edge(from, to, mark, stroke: tint + 1pt, ..args)
#let _edge_txt(label, tint, ..args) = text(size: 6pt, fill: tint.darken(30%), label, ..args)



#scale(50%, reflow: true, [#diagram(
  spacing: 15mm,
  node-stroke: 1.5pt,
  edge-stroke: 1.2pt,
  node-corner-radius: 5pt,

  
  (
  // Capteurs
  let x = 6,
  let y = 0,
    
  _node((x,y), [Capteurs\ environnementaux\ #text(size: 6pt, "(météo ou gaz)")], blue, <meteo>),
  _node((x+2,y), [Module de gestion de l'alimentation], blue, <alim_meteo>),
  _edge(<meteo>, <ann_meteo>, blue, label: _edge_txt([Valeurs\ brutes], blue)),
  _edge(<alim_meteo>, <ann_meteo>, blue, label: _edge_txt([Valeurs\ brutes], blue)),
  _node((x,y+1), [Module d'annotation\ #text(size: 6pt, "(id station, date, baterie)")], blue, <ann_meteo>),
  _edge(<conf_meteo>, <ann_meteo>, blue, label: _edge_txt([JSON:\ Configuration], blue)),
  _node((x+2,y+1), [Module de\ configuration], blue, <conf_meteo>),
  _edge(<comm_meteo>, <conf_meteo>, blue, label: _edge_txt([JSON:\ Configuration], blue), label-side: right, label-pos: 60%, corner: left),
  _edge(<ann_meteo>, <comm_meteo>, blue, label: _edge_txt([JSON:\ Valeurs capteurs], blue), label-pos: 40%, corner: left),
  _node((x+1,y+2), [Module\ de communication], blue, <comm_meteo>),
  
  _edge(<comm_meteo>, <lora>, blue, label: _edge_txt([JSON:\ Valeurs capteurs], blue), bend: 15deg),
  _edge(<lora>, <comm_meteo>, orange, label: _edge_txt([JSON:\ Configuration], orange), bend: 15deg),
  _node((x+1,y+3), [Passerelle\ LoRaWAN], orange, <lora>),
  _edge(<lora>, "d", orange, label: _edge_txt([Message MQTT\ (JSON sur `/captors/{meteo|gaz}/{id_station}/raw`):\ Valeurs capteurs], orange), bend: 10deg, shift: 3pt),
  _edge(<lora>, "d", purple, label: _edge_txt([Message MQTT\ (JSON sur `/captors/{meteo|gaz}/{id_station}/config`):\ Configuration], purple), bend: -10deg, mark: "<|-", shift: -3pt),
  ),
  
  (
  // Cameras
  let x = 0,
  let y = 0,
  
  _node((x+0,y+0), [Caméra\ optique], orange, <cam>),
  _node((x+1,y+0), [Caméra\ thermique], orange, <cam_th>),
  _node((x+2,y+0), [Module de gestion de l'alimentation], orange, <alim_cam>),
  _edge(<cam>, <ann_cam>, orange, label: _edge_txt([Image], orange)),
  _edge(<cam_th>, <ann_cam>, orange, label: _edge_txt([Nuage de points], orange)),
  _edge(<alim_cam>, <ann_cam>, orange, label: _edge_txt([Valeurs\ brutes], orange), label-side: left),
  _node((x+0,y+1), [Module d'annotation\  #text(size: 6pt, "(id station, date, baterie)")], orange, <ann_cam>),
  _edge(<conf_cam>, <ann_cam>, orange, label: _edge_txt([JSON:\ Configuration], orange), label-side: left),
  _node((x+2,y+1), [Module de\ configuration], orange, <conf_cam>),
  _edge(<com>, <conf_cam>, orange, label: _edge_txt([JSON:\ Configuration], orange), label-side: right, label-pos: 60%, corner: left),
  _edge(<ann_cam>, <com>, orange, label: _edge_txt([Image et nuage\ de point annotés], orange), label-side: right, label-pos: 40%, corner: left),
  _node((x+1,y+2), [Module de\ communication], orange, <com>),
  _edge(<com>, "d,l,d", orange, label: _edge_txt([RTP:\ Image et nuage de point annotés], orange), label-side: right, shift: 5pt),
  _edge(<com>, "d,rrr,d", mark: "<|-", purple, label: _edge_txt([Message MQTT\ (JSON sur `/captors/cameras/{id_station}/config`):\ Configuration], purple), label-side: left, label-pos: 41%, shift: -15pt),
  _edge(<com>, "d,rrr,d", orange, label: _edge_txt([Message MQTT\ (JSON sur `/captors/cameras/{id_station}/raw`):\ État station (batterie)], orange), label-side: right, label-pos: 80%, shift: -5pt, layer: -1),
  ),
  
  _node(auto, [Broker MQTT], purple, <mqtt>, enclose: ((3,4), (8,4))),
  _edge(<mqtt>, "d", purple, bend: 15deg, label: _edge_txt([Redpanda Connect\ `/captors/{type_station}/{id_station}/raw`], purple)),
  _edge(<mqtt>, "d", mark: "<|-", purple, bend: -15deg, label: _edge_txt([Redpanda Connect\ `/captors/{type_station}/{id_station}/config`], purple)),
  _node(auto, [Cluster Redpanda], purple, <redpanda>, enclose: ((1,5), (8,5))),
  _node(auto, [MinIO\  #text(size: 6pt, [Stockage de l'historique d'images et nuages de points])], purple, <lake>, enclose: ((0,5), (0,7)), shape: fletcher.shapes.cylinder.with(tilt: 4deg)),
  _node(auto, [InfluxDB], purple, <db_fog>, enclose: ((2,7), (7,7)), shape: fletcher.shapes.cylinder.with(tilt: 2deg)),

  _node((0,4), [Réception de flux], purple, <flux>),
  _edge(<flux>, <lake>, purple, label: _edge_txt([Image et\ nuage de points], purple), shift: -5pt),
  _edge(<lake>, <flux>, purple, label: _edge_txt([Infos\ station], purple), shift: -5pt),
  _edge(<lake>, <pretraitement>, purple, label: _edge_txt([Infos station], purple)),
  
  _edge(<flux>, <img_analysis>, purple, label: _edge_txt([Flux optique et infos station], purple), label-side: right),
  _node((1.5,4), [Analyse du\ flux optique], purple, <img_analysis>),
  _edge(<flux>, <th_analysis>, purple, bend: 15deg, label: _edge_txt([Flux thermique et infos station], purple), shift: 5pt),
  _node((2.25,4), [Analyse du\ flux thermique], purple, <th_analysis>),
  _edge(<img_analysis>, "d", purple, label: _edge_txt([JSON sur `/captors/cameras/{id_station}/data`:\ Présence ou non de fumée et sa position sur l'image], purple), label-side: right),
  _edge(<th_analysis>, "d", purple, label: _edge_txt([JSON sur `/captors/cameras/{id_station}/data`:\ Moyenne de température et position des points chauds (avec température)], purple), label-side: left),
  // !!!!! COMMMENT NOMMER LES TOPICS ? !!!!!

  
  _edge(<pretraitement>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/raw`], purple), label-side: left, bend: 10deg),
  _edge(<pretraitement>, "u", mark: "-|>", purple, label: _edge_txt([`/captors/{type}/{id_station}/data`], purple), label-side: right, bend: -10deg, label-pos: 25%),
  _node((2,6), [Prétraitement des données capteurs], purple, <pretraitement>),
  _edge(<pretraitement>, "d", mark: "<|-", purple, label: _edge_txt([Données précédentes], purple), label-side: left),

  _edge(<save>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/*`\ `/alerts/*`\ `/maps/*/*`], purple), label-side: right),
  _edge(<save>, "d", mark: "-|>", purple, label: _edge_txt([], purple), label-side: left, label-pos: 30%),
  _node((6,6), [Service de\ sauvegarde], purple, <save>),

  _edge(<configs>, "uu", purple, label: _edge_txt([`/captors/{type}/{id_station}/config`], purple), label-side: right, label-pos: 25%),
  _edge(<configs>, "l", purple, label: _edge_txt([Config\ générale], purple), label-side: left),
  _node((1,7), [Gestion des\ configurations], purple, <configs>),
  
  _edge(<health>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/raw`], purple), label-side: left, bend: 10deg),
  _edge(<health>, "u", mark: "-|>", purple, label: _edge_txt([`/alerts/{type_alert}/{type_equipment}`], purple), label-side: right, bend: -10deg),
  _node((7,6), [Monitoring des\ équipements], purple, <health>),
  
  _edge(<detec>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/data`], purple), label-side: left, bend: 10deg, label-pos: 65%),
  _edge(<detec>, "u", mark: "-|>", purple, label: _edge_txt([`/alerts/fire`\ `/maps/fire/{area}`], purple), label-side: right, bend: -10deg),
  _edge(<detec>, "d", mark: "<|-", purple, label: _edge_txt([Imagerie satellite], purple), label-side: left),
  _node((3,6), [Service de\ détection\ des incendies], purple, <detec>),
  _edge(<prop>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/data`\ et `/maps/fire/*`], purple), label-side: left, bend: 10deg),
  _edge(<prop>, "u", mark: "-|>", purple, label: _edge_txt([`/maps/evol/{area}`], purple), label-side: right, bend: -10deg),
  _edge(<prop>, "d", mark: "<|-", purple, label: _edge_txt([Altimétrie,\ cartographie\ et boisements], purple), label-side: left),
  _node((4,6), [Service d'analyse de la propagation\ d'incendie], purple, <prop>),
  _edge(<pred>, "u", mark: "<|-", purple, label: _edge_txt([Souscription\ `/captors/*/*/data`], purple), label-side: left, bend: 10deg),
  _edge(<pred>, "u", mark: "-|>", purple, label: _edge_txt([`/alerts/risk`\ `/maps/risk/{area}`], purple), label-side: right, bend: -10deg),
  _edge(<pred>, "d", mark: "<|-", purple, label: _edge_txt([Prédiction météo, foudre,\ altimétrie, cartographie et boisements], purple), label-side: left),
  _node((5,6), [Service de\ prédiction\ des incendies], purple, <pred>),

  
  _edge(<externe>, "u", purple, label: _edge_txt([Image satellite, prédiction
météo, foudre,\ cartographie, altimétrie et boisement], purple)),
  _node((4,8), [Synchronisation des données externes], purple, <externe>),

  
  _edge(<api_fog>, "u,rr,u", mark: "<|-", purple, shift: 25pt, label: _edge_txt([Données temporelles des capteurs\ et configuration des équipements], purple)),
  _edge(<api_fog>, "u,l,u", mark: "<|-", purple, shift: -25pt, label: _edge_txt([Données caméras temporelles], purple)),
  _edge(<api_fog>, "uu", purple, label: _edge_txt([Configuration sur\ `/captors/{type}/{id_station}/config`\ ou `/config`], purple), label-pos: 80%, label-side: right),
  _node((1,9), [API], purple, <api_fog>),
  _edge(<api_fog>, "d", mark: "<|--", gray, shift: -25pt, label: _edge_txt([Configuration], gray), label-side: right),
  
  _edge(<grafana_fog>, "uu", mark: "<|-", purple, label: _edge_txt([Données temporelles], purple)),
  _node((5,9), [Interface de\ monitoring Grafana], purple, <grafana_fog>),
  _edge(<grafana_fog>, "d", mark: "<|--", gray, label: _edge_txt([Monitoring], gray), label-side: right),

  
  _edge(<comm_fog>, "uuuu", mark: "<|-", purple, label: _edge_txt([Souscription\ `/alerts/*`\ et `/maps/*/*`], purple), label-side: left),
  _node((8,9), [Service de\ communication], purple, <comm_fog>),
  _edge(<comm_fog>, "l", mark: "--|>", gray, label: _edge_txt([Notification], gray)),

  
  _edge(<api_cloud>, "uu", mark: "<|-", purple,  label: _edge_txt([Données de la forêt], purple), label-side: right),
  _node((1,11), [API], red, <api_cloud>),

  
  _edge(<mqtt_cloud>, "uu", mark: "<|-", purple, label: _edge_txt([`/alerts/{type}` et\ `/maps/{type}/{area}`], purple), label-side: left),
  _node((8,11), [Cluster Redpanda], red, <mqtt_cloud>),

  _edge(<mqtt_cloud>, <alertes_cloud>, red, label: _edge_txt([Souscription `/alerts/*`], red), label-side: left),
  _node((6,11), [Service de\ gestion des alertes], red, <alertes_cloud>),
  _edge(<alertes_cloud>, "ll", red, label: _edge_txt([Alertes en cours], red), label-side: left),
  
  _edge(<mqtt_cloud>, <tuiles_cloud>, red, label: _edge_txt([Souscription `/maps/*/*`], red), label-side: left, corner: right, label-pos: 70%),
  _node((6,12), [Service de\ génération\ des tuiles], red, <tuiles_cloud>),
  _edge(<tuiles_cloud>, "ll", red, label: _edge_txt([Carte sous format GeoJSON], red), label-side: left),
  
  _node(auto, [MinIO], red, <db_cloud>, enclose: ((4,11), (4,12)), shape: fletcher.shapes.cylinder.with(tilt: 2deg)),
  _edge(<api_cloud>, "rrr", mark: "<|-", red, label: _edge_txt([Cartes et alertes en cours], red), label-side: left),
  
  _edge(<api_cloud>, <ui_cloud>, red, label: _edge_txt([Cartes, alertes en cours\ et données des forêts], red), label-side: right),
  _node((1,12), [Interface de\ visualisation], red, <ui_cloud>),
  _edge(<ui_cloud>, "d", mark: "<|--", gray, label: _edge_txt([Visualisation], gray), label-side: right),
)

#v(0.5cm)

// Légende améliorée
#align(center)[
  #let _legend(thing, label) = grid(columns: 2, align: horizon, inset: (3pt, 0pt, 0pt, 0pt), 
  thing, label)
  #let _color(color) = box(fill: color.lighten(90%), stroke: color + 1.5pt, width: 14pt, height: 10pt, radius: 3pt)
  #let _arrow(kind) = diagram(edge-stroke: 1pt, edge((0,0), "r", kind))
  
  #grid(
    columns: 6,
    column-gutter: 12pt,
    row-gutter: 6pt, 
    align: horizon,
    _legend(_color(blue), [*Thing*]),
    _legend(_color(orange), [*Edge*]),
    _legend(_color(purple), [*Fog*]),
    _legend(_color(green), [*Externe*]),
    _legend(_color(red), [*Cloud*]),
    _legend(_color(gray), [*Utilisateur*])
  )
  /*#grid(
    columns: 4,
    column-gutter: 12pt, 
    align: horizon,
    _legend(_arrow("-|>"), [*Stream*]),
    _legend(_arrow("=>"), [*Batch*])
  )*/
]
])