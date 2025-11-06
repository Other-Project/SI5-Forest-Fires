#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern")

#let _node(pos, label, tint, id, ..args) = node(pos, label, stroke: tint + 2pt, fill: tint.lighten(90%), name: id, inset: 8pt,  ..args)
#let _edge(from, to, tint, mark: "-|>", ..args) = edge(from, to, mark, stroke: tint + 1pt, ..args)
#let _edge_txt(label, tint, ..args) = text(size: 8pt, fill: tint.darken(30%), label, ..args)

#diagram(
  spacing: (10mm, 12mm),
  node-stroke: 1.5pt,
  edge-stroke: 1.2pt,
  node-corner-radius: 5pt,
  
  _node((0, 0), [*Détection des Incendies*], green, <detect>),
  _node((1, 0), [*Propagation des incendies*], green, <propa>),
  _node((2, 0), [*Évaluation des Risques*], green, <risque>),
  _node((0, 2), [*Gestion des Capteurs*], red, <iot>),
  _node((1, 2), [*Infrastructure Réseau*], red, <comm>),
  _node((2, 2), [*Communication et Alerte*], red, <alerte>),
  _node((3, 2), [*Visualisation et Historique*], red, <histo>),
  _node((0, 4), [*Supervision Environnementale*], blue, <env>),
  _node((2, 4), [*Gestion Énergétique*], blue, <energie>),

  _edge(<energie>, <comm>, black),
  _edge(<energie>, <iot>, black),
  
  _edge(<comm>, <env>, black),
  _edge(<comm>, <iot>, black),
  
  _edge(<env>, <detect>, black, bend: 60deg),
  _edge(<env>, <propa>, black),
  _edge(<env>, <risque>, black),
  _edge(<env>, <propa>, black),
  _edge(<env>, <alerte>, black),

  _edge(<iot>, <detect>, black),
  _edge(<iot>, <propa>, black),
  _edge(<iot>, <risque>, black),
  _edge(<iot>, <alerte>, black, bend: -30deg),

  _edge(<comm>, <detect>, black),
  _edge(<comm>, <propa>, black),
  _edge(<comm>, <risque>, black),
  
  _edge(<detect>, <propa>, black),
  _edge(<propa>, <alerte>, black),
  
  _edge(<detect>, <histo>, black),
  _edge(<propa>, <histo>, black),
  _edge(<risque>, <histo>, black),
  _edge(<histo>, <alerte>, black),
)


#v(0.5cm)

#align(center)[
  #let _legend(thing, label) = grid(columns: 2, align: horizon, inset: (3pt, 0pt, 0pt, 0pt), 
  thing, label)
  #let _color(color) = box(fill: color.lighten(90%), stroke: color + 1.5pt, width: 14pt, height: 10pt, radius: 3pt)
  #let _arrow(kind) = diagram(edge-stroke: 1pt, edge((0,0), "r", kind))
  
  #grid(
    columns: 3,
    column-gutter: 12pt,
    row-gutter: 6pt, 
    align: horizon,
    _legend(_color(green), [*Core*]),
    _legend(_color(red), [*Supportive*]),
    _legend(_color(blue), [*Generic*]),
  )
]
