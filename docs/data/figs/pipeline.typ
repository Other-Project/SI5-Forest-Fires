#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern", lang: "fr")
#show raw: set text(size: 4.5pt)

#let _node(pos, label, tint, width: 30mm, id, ..args) = node(pos, label, stroke: tint + 2pt, fill: tint.lighten(90%), name: id, inset: 8pt, width: width, ..args)
#let _edge(from, to, tint, mark: "-|>", ..args) = edge(from, to, mark, stroke: tint + 1pt, ..args)
#let _edge_txt(label, tint, ..args) = text(size: 6pt, fill: tint.darken(30%), label, ..args)



#scale(60%, reflow: true, [#diagram(
  spacing: 30mm,
  node-stroke: 1.5pt,
  edge-stroke: 1.2pt,
  node-corner-radius: 5pt,

  _node((0,0), [Caméras], orange, <cam>),
  _node((2,0), [Centrales météo], orange, <meteo>),
  _node((4,0), [Capteurs de gaz], orange, <gaz>),

  _edge(<cam>, (0,0.66), mark: "-", orange, label: _edge_txt([Flux RTP], orange), label-side: right, label-pos: 70%),
  _edge((0,0.66), <fumee>, orange, corner: right),
  _edge((0,0.66), <minio>, orange),
  
  _edge(<cam>, (2,0.33), mark: "-", orange, corner: left, shift: (-5pt, 0)),
  _edge(<meteo>, (2,0.33), mark: "-", orange),
  _edge(<gaz>, (2,0.33), mark: "-", orange, corner: right),
  _edge((3,0.33), (3,0.66), mark: "-", orange, label: _edge_txt([`/captors/{type_station}/{id_station}/raw`], orange)),
  _edge((3,0.66), <monitor>, orange, corner: right),
  _edge((3,0.66), <traitement>, orange, corner: left),
  _edge((3,0.66), <influx>, orange),
  
  _node((1,1), [Analyse de fumée et de points chauds], purple, <fumee>),
  _node((0,1), [MinIO], purple, <minio>, shape: fletcher.shapes.cylinder),
  _node((3,1), [InfluxDB], purple, <influx>, shape: fletcher.shapes.cylinder),
  _node((4,1), [Monitoring des\ équipements], purple, <monitor>),
  _node((2,1), [Prétraitement des\ données capteurs], purple, <traitement>),

  
  _edge(<monitor>, <influx>, purple),

  
  _edge(<fumee>, (2,1.33), mark: "-", purple),
  _edge(<traitement>, (2,1.33), mark: "-", purple),
  _edge((2,1.33), <influx>, purple),
  _edge((2,1.33), (2,1.66), mark: "-", purple, label: _edge_txt([`/captors/{type_station}/{id_station}/data`], purple), label-pos: 10%),
  _edge((2,1.66), <detec>, purple),
  _edge((2,1.66), <prop>, purple),
  _edge((2,1.66), <pred>, purple),
  _edge(<influx>, <detec>, purple.lighten(60%), label: _edge_txt([\ Imagerie satellite], purple.lighten(60%)), label-pos: 30%, label-side: left),
  _edge(<influx>, <prop>, purple.lighten(60%), label: _edge_txt([Altimétrie, cartographie\ et boisements], purple.lighten(60%)), label-side: left),
  _edge(<influx>, <pred>, purple.lighten(60%), label: _edge_txt([Prédiction météo, foudre,\ altimétrie, cartographie\ et boisements], purple.lighten(60%)), label-side: left),
  
  _node((1,2), [Service de\ détection\ des incendies], purple, <detec>),
  _edge(<detec>, <prop>, purple, label: _edge_txt([`/maps/fire/{area}`], purple)),
  _node((2,2), [Service d'analyse de la propagation\ d'incendie], purple, <prop>),
  _node((3,2), [Service de\ prédiction\ des incendies], purple, <pred>),

  _edge(<detec>, (1.95,2.3), mark: "-", purple.lighten(60%), corner: left, shift: (-5pt, 0)),
  _edge(<prop>, (1.95,2.3), mark: "-", purple.lighten(60%)),
  _edge(<pred>, (1.95,2.3), mark: "-", purple.lighten(60%), corner: right, shift: (5pt, 0)),
  _edge(<detec>, (2.05,2.4), mark: "-", purple, corner: left, shift: (5pt, 0)),
  _edge(<prop>, (2.05,2.4), mark: "-", purple),
  _edge(<pred>, (2.05,2.4), mark: "-", purple, corner: right, shift: (-5pt, 0)),

  
  _edge((1.95,2.3), (1.95,2.6), mark: "-", purple.lighten(60%)),
  _edge((2.05,2.4), (2.05,2.7), mark: "-", purple),

  
  _edge((2.05,2.7), (3.55,1), mark: "-", purple, corner: left),
  _edge((3.55,1), <influx>, purple),
  _edge((1.95,2.6), (3.45,1.05), mark: "-", purple.lighten(60%), corner: left),
  _edge((3.45,1.05), <influx>, purple.lighten(60%), shift: (0pt, 6pt)),

  
  _edge(<ext>, (4, 2.5), green, mark: "<|-", label: _edge_txt([Données\ externes], green)),
  _node((4,2), [Synchronisation des\ données externes], purple, <ext>),
  
  _edge(<ext>, (3.65, 2), purple.darken(20%), mark: "-"),
  _edge((3.65, 2), <influx>, purple.darken(20%), corner: left, shift: (0pt, 7pt)),

  
  _edge((2.05,2.7), <alert>, purple, corner: left, label: _edge_txt([`/alerts/{type}`], purple), label-pos: 20%, label-side: left),
  _edge((1.95,2.6), <tuiles>, purple.lighten(60%), corner: right, label: _edge_txt([`/maps/{type}/{area}`], purple.lighten(60%)), label-pos: 0%, label-side: right),
  
  _node((2.5, 3), [Gestion des alertes], red, <alert>),
  _node((1.5, 3), [Génération\ des tuiles], red, <tuiles>),
  
  _edge(<tuiles>, <minio_cloud>, red, corner: left),
  _edge(<alert>, <minio_cloud>, red, corner: right),
  
  _node((2,4), [MinIO], red, <minio_cloud>, shape: fletcher.shapes.cylinder),
)

#v(0.5cm)

// Légende améliorée
#align(center)[
  #let _legend(thing, label) = grid(columns: 2, align: horizon, inset: (3pt, 0pt, 0pt, 0pt), 
  thing, label)
  #let _color(color) = box(fill: color.lighten(90%), stroke: color + 1.5pt, width: 14pt, height: 10pt, radius: 3pt)
  #let _arrow(kind) = diagram(edge-stroke: 1pt, edge((0,0), "r", kind))
  
  #grid(
    columns: 4,
    column-gutter: 12pt,
    row-gutter: 6pt, 
    align: horizon,
    _legend(_color(orange), [*Edge*]),
    _legend(_color(green), [*Externe*]),
    _legend(_color(purple), [*Fog*]),
    _legend(_color(red), [*Cloud*])
  )
  #text(style: "italic")[Les flèches plus claires ne le sont que pour des raisons visuelles]
]
])