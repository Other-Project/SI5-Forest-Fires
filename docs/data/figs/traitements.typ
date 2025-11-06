#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern")

#let _node(pos, label, tint, id, ..args) = node(pos, label, stroke: tint + 2pt, fill: tint.lighten(90%), name: id, inset: 8pt, ..args)
#let _edge(from, to, tint, mark: "-|>", ..args) = edge(from, to, mark, stroke: tint + 1pt, ..args)
#let _edge_txt(label, tint, ..args) = text(size: 6.5pt, fill: tint.darken(30%), label, ..args)


#diagram(
  spacing: (10mm, 12mm),
  node-stroke: 1.5pt,
  edge-stroke: 1.2pt,
  node-corner-radius: 5pt,

  _node((0,0), [Calibration\ des données], orange, <calibration>, width: 30mm),
  _node((1,0), [Compression\ des données], orange, <compression>, width: 30mm),
  _node((2,0), [Discrétisation\ des données], orange, <discretisation>, width: 30mm),
  _node((3,0), [Annotation\ des données], orange, <annotation>, width: 30mm),
  _node((4,0), [Association des\ données sur\ la station], purple, <position>, width: 30mm),

  _edge(<calibration>, <compression>, orange),
  _edge(<compression>, <discretisation>, orange),
  _edge(<discretisation>, <annotation>, orange),
  _edge(<annotation>, <position>, purple),
  
)

#v(0.5cm)

// Légende améliorée
#align(center)[
  #let _legend(thing, label) = grid(columns: 2, align: horizon, inset: (3pt, 0pt, 0pt, 0pt), 
  thing, label)
  #let _color(color) = box(fill: color.lighten(90%), stroke: color + 1.5pt, width: 14pt, height: 10pt, radius: 3pt)
  #let _arrow(kind) = diagram(edge-stroke: 1pt, edge((0,0), "r", kind))
  
  #grid(
    columns: 2,
    column-gutter: 12pt,
    row-gutter: 6pt, 
    align: horizon,
    _legend(_color(orange), [*Edge*]),
    _legend(_color(purple), [*Fog*]),
  )
]
