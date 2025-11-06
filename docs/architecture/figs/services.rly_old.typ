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
  
  _edge(<lora>, "ll", blue, mark: "<|-", label: _edge_txt([LoRaWAN], blue)),
  _node((0,0), [Module de\ réception\ LoRaWAN], orange, <lora>),
  _edge(<cam>, "ll", blue, mark: "<|-", label: _edge_txt([Filaire], blue)),
  _node((0,1), [Module d’acquisition vidéo], orange, <cam>),

  
  _edge(<lora>, <filtre>, orange),
  _edge(<cam>, <filtre>, orange),
  _node((1,0.5), [Module de filtrage], orange, <filtre>),
  _edge(<filtre>, <compr.west>, orange),
  _node((2,1), [Module de\ réduction\ des données], orange, <compr>),
  _edge(<seuil>, <compr>, orange, mark: "<|-|>"),
  _node((2,0), [Détection de seuil], orange, <seuil>),
  _edge(<compr.east>, <com>, orange),
  _node((3,1), [Module de\ communication], orange, <com>),
  _edge(<com>, <db_edge>, orange, mark: "<|-|>"),
  _node((3,0), [Cache], orange, <db_edge>, shape: fletcher.shapes.cylinder),

  _edge(<com>, "d,lll,dd", orange),
  
  _node((0,4), [Broker MQTT], purple, <mqtt>),
  _edge(<mqtt>, <checker>, purple),
  _node((0,6), [Health check], purple, <checker>),
  _edge(<checker>, <communication>, purple),
  _edge(<mqtt>, <db_fog>, purple),
  _node((2,4), [InfluxDB], purple, <db_fog>, shape: fletcher.shapes.cylinder),
  _edge(<db_fog>, <grafana>, purple),
  _node((3,3.7), [Interface de\ monitoring Grafana], purple, <grafana>),
  _edge(<grafana>, <police>, purple),
  _node((3,4.35), [Police scientifique], gray, <police>),
  _edge(<db_fog>, <cleaning>, purple, mark: "<|-|>"),
  _node((2,3), [Service de\ nettoyage], purple, <cleaning>),
  _edge(<db_fog>, <inf>, purple, mark: "<|-|>"),
  _node((1,3), [Inférence des données manquantes], purple, <inf>),
  _edge(<externe>, <db_fog>, purple),
  _node((3,3), [Synchronisation des données externes], purple, <externe>),
  _edge(<db_fog>, <detec>, purple, mark: "<|-|>"),
  _node((1,5), [Service de\ détection\ des incendies], purple, <detec>),
  _edge(<db_fog>, <prop>, purple, mark: "<|-|>"),
  _node((2,5), [Service d'analyse de la propagation\ d'incendie], purple, <prop>),
  _edge(<db_fog>, <pred>, purple, mark: "<|-|>"),
  _node((3,5), [Service de\ prédiction\ des incendies], purple, <pred>),
  _edge(<detec>, <communication>, purple),
  _edge(<prop>, <communication>, purple),
  _edge(<pred>, <communication>, purple),
  _node((2,6), [Service de communication], purple, <communication>),
  _edge(<communication>, <notif>, purple),
  _node((3,6), [Service d'alerte], purple, <notif>),
  _edge(<notif>, <garde>, purple),
  _node((3,7), [Garde forestier], gray, <garde>),

  _edge(<communication>, "d,ll,d", purple),
  
  _node((0,8), [Broker MQTT], red, <cloud_mqtt>),
  _edge(<cloud_mqtt>, <db_cloud>, red),
  _node((2,8), [InfluxDB], red, <db_cloud>, shape: fletcher.shapes.cylinder),
  _edge(<db_cloud>, <tuiles>, red, mark: "<|-|>"),
  _node((3,9), [Service de génération des tuiles], red, <tuiles>),
  _edge(<db_cloud>, <ui>, red),
  _node((1,9), [Interface de visualisation], red, <ui>),
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