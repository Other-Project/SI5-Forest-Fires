#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern")

#let _node(pos, label, tint, width: 30mm, id, ..args) = node(pos, label, stroke: tint + 2pt, fill: tint.lighten(90%), name: id, inset: 8pt, width: width, ..args)
#let _edge(from, to, tint, mark: "-|>", ..args) = edge(from, to, mark, stroke: tint + 1pt, ..args)
#let _edge_txt(label, tint, ..args) = text(size: 6.5pt, fill: tint.darken(30%), label, ..args)


#diagram(
  spacing: (10mm, 12mm),
  node-stroke: 1.5pt,
  edge-stroke: 1.2pt,
  node-corner-radius: 5pt,
  
  
  _node((0,-2.5), [Capteurs\ environnementaux], blue, <meteo>),
  _node((0,-1.5), [Module de gestion de l'alimentation], blue, <alim_meteo>),
  _edge(<meteo>, <ann_meteo>, blue),
  _edge(<alim_meteo>, <ann_meteo>, blue),
  _node((1,-2), [Module d'annotation\ #text(size: 6pt, "(id station, date, baterie)")], blue, <ann_meteo>),
  _edge(<conf_meteo>, <ann_meteo>, blue),
  _node((1,-1.25), [Module de\ configuration], blue, <conf_meteo>),
  _edge(<comm_meteo>, <conf_meteo>, blue),
  _edge(<ann_meteo>, <comm_meteo>, blue),
  _node((2,-2), [Module\ de communication], blue, <comm_meteo>),
  _edge(<comm_meteo>, <lora>, blue, label: _edge_txt([LoRaWAN], blue), bend: 15deg),
  _edge(<lora>, <comm_meteo>, blue, label: _edge_txt([LoRaWAN], blue), bend: 15deg),
  _node((3,1), [Passerelle\ LoRaWAN], orange, <lora>),
  _edge(<lora>, <mqtt>, orange, label: _edge_txt([Message MQTT], orange), bend: 10deg),
  _edge(<mqtt>, <lora>, orange, label: _edge_txt([Message MQTT], orange), bend: 10deg),
  
  _node((0,0.5), [Caméra\ optique/thermique], orange, <cam>),
  _node((0,1.5), [Module de gestion de l'alimentation], orange, <alim_cam>),
  _edge(<alim_cam>, <ann_cam>, orange),
  _edge(<cam>, <ann_cam>, orange),
  _node((1,1), [Module d'annotation\  #text(size: 6pt, "(id station, date, baterie)")], orange, <ann_cam>),
  _edge(<conf_cam>, <ann_cam>, orange),
  _node((1,0.25), [Module de\ configuration], orange, <conf_cam>),
  _edge(<com>, <conf_cam>, orange),
  _edge(<ann_cam>, <com>, orange),
  _node((2,1), [Module de\ communication], orange, <com>),
  _edge(<com>, <S3>, orange, label: _edge_txt([WebRTC], orange), bend: -40deg),
  _edge(<mqtt>, <com>, orange, label: _edge_txt([Message MQTT], orange)),
  
  _node((1,3), [MinIO], purple, <S3>, shape: fletcher.shapes.cylinder),
  _edge(<S3>, <api>, purple, bend: -20deg),
  _node((1.5,3.5), [Analyse d'image], purple, <analyse_img>),
  _edge(<S3>, <analyse_img>, purple),
  _edge(<analyse_img>, <mqtt>, purple),


  
  _node((2,4), [Broker MQTT], purple, <mqtt>),
  _edge(<mqtt>, <checker>, purple, mark: "<|-|>", bend: -30deg),
  _node((1.5,2.5), [Health check], purple, <checker>),
  _edge(<mqtt>, <db_fog>, purple),
  _node((1,4), [InfluxDB], purple, <db_fog>, shape: fletcher.shapes.cylinder),
  _edge(<db_fog>, <grafana>, purple),
  _edge(<S3>, <grafana>, purple),
  _node((0,4.7), [Interface de\ monitoring Grafana], purple, <grafana>),
  _edge(<grafana>, <police>, purple),
  _node((0,5.35), [Police scientifique], gray, <police>),
  _edge(<db_fog>, <cleaning>, purple, mark: "<|-|>"),
  _node((0,3), [Service de\ nettoyage], purple, <cleaning>),
  _edge(<mqtt>, <inf>, purple, mark: "<|-|>"),
  _edge(<db_fog>, <inf>, purple, mark: "<|-|>"),
  _node((1.5,5), [Inférence des données manquantes], purple, <inf>),
  _edge(<externe>, <db_fog>, purple),
  _node((0,4), [Synchronisation des données externes], purple, <externe>),
  
  _edge(<mqtt>, <detec>, purple, mark: "<|-|>"),
  _edge(<db_fog>, <detec>, purple, mark: "-|>"),
  _node((3,3), [Service de\ détection\ des incendies], purple, <detec>),
  _edge(<mqtt>, <prop>, purple, mark: "<|-|>"),
  _edge(<db_fog>, <prop>, purple, mark: "-|>", bend: 15deg),
  _node((3,4), [Service d'analyse de la propagation\ d'incendie], purple, <prop>),
  _edge(<mqtt>, <pred>, purple, mark: "<|-|>"),
  _edge(<db_fog>, <pred>, purple, mark: "-|>"),
  _node((3,5), [Service de\ prédiction\ des incendies], purple, <pred>),
  
  _edge(<mqtt>, <communication>, purple),
  _node((2,6), [Service de\ communication], purple, <communication>),
  _edge(<mqtt>, <notif>, purple),
  _node((3,6), [Service d'envoi des alertes], purple, <notif>),
  _edge(<notif>, <garde>, purple),
  _node((3,7), [CODIS], gray, <garde>),

  
  _edge(<db_fog>, <api>, purple),
  _node((1,6), [API], purple, <api>),
  _edge(<api>, <mqtt>, purple, bend: -30deg),
  
  _edge(<communication>, <cloud_mqtt>, purple),
  
  _node((2,8), [Broker MQTT], red, <cloud_mqtt>),
  _edge(<cloud_mqtt>, <db_cloud>, red),
  _node((2,9), [MinIO], red, <db_cloud>, shape: fletcher.shapes.cylinder),
  _edge(<cloud_mqtt>, <tuiles>, red),
  _edge(<tuiles>, <db_cloud>, red),
  _node((3,9), [Service de génération des tuiles], red, <tuiles>),
  _edge(<db_cloud>, <api_cloud>, red),
  _edge(<api>, <api_cloud>, purple, mark: "<|-|>"),
  _node((1,9), [API], red, <api_cloud>),
  _edge(<api_cloud>, <ui>, red, mark: "<|-|>"),
  _node((0,9), [Interface de\ visualisation], red, <ui>),
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