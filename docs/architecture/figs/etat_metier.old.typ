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
  
  _node((0, 0), [*Normal*\ Aucun risque particulier détecté], black, <normal>),
  _edge(<normal.east>, <risque.west>, black, label: _edge_txt([Seuil de risque dépassé], black), bend: 20deg),
  _edge(<risque.west>, <normal.east>, black, label: _edge_txt([Conditions redevenues sûres], black), bend: 20deg),
  _node((6, 0), [*Risque accru*\ Conditions météo ou environnementales défavorables], black, <risque>),
  _edge(<risque.south>, <incendie.east>, black, label: _edge_txt([Détection d’un départ de feu], black), label-side: left, bend: 20deg),
  _edge(<incendie.east>, <risque.south>, black, label: _edge_txt([Extinction réussie], black), label-side: left, bend: 20deg),
  _node((3, 3), [*Incendie*\ Suivi de la propagation], black, <incendie>),
  
  _edge(<normal.south>, <incendie.west>, black, label: _edge_txt([Détection d’un départ de feu], black), label-side: left, bend: 20deg),
  _edge(<incendie.west>, <normal.south>, black, label: _edge_txt([Extinction réussie], black), label-side: left, bend: 20deg),
)
