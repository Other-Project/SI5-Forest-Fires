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

  // LoRa
  _node((0, 0), [Capteur\ de gaz], blue, <gaz_1_1>, width: 22mm),
  _node((2, 0), [Capteur\ de gaz], blue, <gaz_1_2>, width: 22mm),
  _node((4, 0), [Capteur\ de gaz], blue, <gaz_1_3>, width: 22mm),
  _edge(<gaz_1_1>, <lora_1_1>, blue, label: _edge_txt("LoRaWAN", blue), label-side: right),
  _edge(<gaz_1_2>, <lora_1_1>, blue, label: _edge_txt("LoRaWAN", blue), label-side: left, bend: 10deg),
  _edge(<gaz_1_2>, <lora_1_2>, blue, label: _edge_txt("LoRaWAN", blue), label-side: right),
  _edge(<gaz_1_3>, <lora_1_2>, blue, label: _edge_txt("LoRaWAN", blue), label-side: left, bend: 10deg),
  
  _node((1, 0.5), [Centrale\ météo], blue, <meteo_1_1>, width: 22mm),
  _node((3, 0.5), [Centrale\ météo], blue, <meteo_1_2>, width: 22mm),
  _edge(<meteo_1_1>, <lora_1_1>, blue, label: _edge_txt("LoRaWAN", blue), label-side: right),
  _edge(<meteo_1_1>, <lora_1_2>, blue, label: _edge_txt("LoRaWAN", blue), label-side: right),
  _edge(<meteo_1_2>, <lora_1_2>, blue, label: _edge_txt("LoRaWAN", blue), label-side: right),

  
  _node((0, 2), [Passerelle\ LoRaWAN], orange, <lora_1_1>, width: 22mm),
  _edge(<lora_1_1>, <fog_1>, orange, label: _edge_txt("Cellulaire", orange), label-side: right),
  _node((2.5, 2), [Passerelle\ LoRaWAN], orange, <lora_1_2>, width: 22mm),
  _edge(<lora_1_2>, <fog_1>, orange, label: _edge_txt("Cellulaire", orange), label-side: right),

  
  // Cam
  _node((5, 0), [Caméra\ thermique], blue, <cam_th_1_1>, width: 22mm),
  _node((6, 0), [Caméra\ optique], blue, <cam_op_1_1>, width: 22mm),
  _edge(<cam_th_1_1>, <edge_1_1>, blue, label: _edge_txt("Filaire", blue)),
  _edge(<cam_op_1_1>, <edge_1_1>, blue, label: _edge_txt("Filaire", blue), label-side: left),
  _node((5.5, 2), [Unité de\ traitement], orange, <edge_1_1>, width: 22mm),
  _edge(<edge_1_1>, <fog_1>, orange, label: _edge_txt("Cellulaire", orange), label-side: left),
  
  _node((7, 0), [Caméra\ thermique], blue, <cam_th_1_2>, width: 22mm),
  _node((8, 0), [Caméra\ optique], blue, <cam_op_1_2>, width: 22mm),
  _edge(<cam_th_1_2>, <edge_1_2>, blue, label: _edge_txt("Filaire", blue)),
  _edge(<cam_op_1_2>, <edge_1_2>, blue, label: _edge_txt("Filaire", blue), label-side: left),
  _node((7.5, 2), [Unité de\ traitement], orange, <edge_1_2>, width: 22mm),
  _edge(<edge_1_2>, <fog_1>, orange, label: _edge_txt("Cellulaire", orange), label-side: left),

  // Foret
  _node((4, 4), [Agrégateur\ foret], purple, <fog_1>, width: 22mm),
  node(enclose: ((0,0), (8.5,4.5)), stroke: gray + 2pt, fill: gray.lighten(95%), inset: 8pt, "Forêt 1"),
  node(enclose: ((9,-0.5), (10.5,4.5)), stroke: gray + 2pt, fill: gray.lighten(95%), inset: 8pt, name:<fog_2>, "Forêt 2"),
  node(enclose: ((11.5,-0.5), (13,4.5)), stroke: gray + 2pt, fill: gray.lighten(95%), inset: 8pt, name:<fog_3>, "Forêt 3"),


  _edge(<fog_1>, <cloud>, purple, label: _edge_txt("Fibre", purple), label-side: right),
  _edge(<fog_2.south>, <cloud>, purple, label: _edge_txt("Fibre", purple), label-side: right),
  _edge(<fog_3.south>, <cloud>, purple, label: _edge_txt("Fibre", purple), label-side: left),
  _node((7, 6), [Interface\ globale], red, <cloud>, width: 22mm),
  
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
    _legend(_color(red), [*Cloud*]),
  )
]
