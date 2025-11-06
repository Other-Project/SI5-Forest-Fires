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
  
  // ==== Things Layer ====
  _node((0, 0), [Humidité\ de l'air], blue, <humidite_air>, width: 22mm),
  _node((1, 0), [Humidité\ du sol], blue, <humidite_sol>, width: 22mm),
  _node((2, 0), [Anémomètre], blue, <vent>, width: 22mm),
  _node((3, 0), [Température], blue, <temp>, width: 22mm),
  _node((4, 0), [Pression], blue, <pression>, width: 22mm),
  _node((5, 0), [Pluviométrie], blue, <pluie>, width: 22mm),
  
  _node((2, 1), [*Centrale\ météo*], blue, <meteo>, width: 22mm),
  _node((1, 1), [*Capteur\ de gaz*], blue, <gaz>, width: 22mm),
  _node((3, 1), [*Caméra\ thermique*], blue, <thermique>, width: 22mm),
  _node((4, 1), [*Caméra\ optique*], blue, <visuelle>, width: 22mm),

  _edge(<humidite_air>, <meteo>, blue, bend: 5deg),
  _edge(<humidite_sol>, <meteo>, blue, bend: 10deg),
  _edge(<vent>, <meteo>, blue),
  _edge(<temp>, <meteo>, blue, bend: -15deg),
  _edge(<pression>, <meteo>, blue, bend: -10deg),
  _edge(<pluie>, <meteo>, blue, bend: -5deg),

  
  // ==== Edge Layer ====
  _node((2.5, 2), [*Passerelle*], orange, <gateway>, width: 30mm),
  //_node((3.25, 2.75), [*Cache*], orange, <edge_store>, width: 30mm, shape: fletcher.shapes.cylinder),

  _edge(<gaz>, <gateway>, blue, label: _edge_txt([LoRaWAN], blue), label-side: right, bend: -10deg),
  _edge(<meteo>, <gateway>, blue, label: _edge_txt([LoRaWAN], blue), label-side: right, bend: 10deg),
  _edge(<thermique>, <gateway>, blue, label: _edge_txt([Filaire], blue), label-side: left, bend: -10deg),
  _edge(<visuelle>, <gateway>, blue, label: _edge_txt([Filaire], blue), label-side: left, bend: 10deg),
  //_edge(<gateway>, <edge_store>, orange, mark: "<|-|>", bend: -25deg),

  
  // ==== Fog Layer ====
  _node((2.5, 3.5), [*Agrégateur forêt*], purple, <agregateur>, width: 30mm),
  _node((3.25, 4.35), [*Stockage forêt*], purple, <fog_store>, width: 30mm, shape: fletcher.shapes.cylinder),
  
  _edge(<gateway>, <agregateur>, orange, label: _edge_txt([Réseau cellulaire\ (TCP/IP)], orange), label-side: right),
  _edge(<agregateur>, <fog_store>, purple, mark: "<|-|>", bend: -25deg),

  
  // ==== External Layer ====
  _node((0, 2.5), [*Image Satellite*\ (NASA FIRMS,\ EUMETSAT)], green, <sat>, width: 30mm),
  _node((0, 3.5), [*Prédiction\ Météo*\ (Météo France)], green, <meteoFR>, width: 30mm),
  _node((0, 4.5), [*Foudre*\ (Keranos,\ Blitzortung)], green, <foudre>, width: 30mm),
  _node((5, 2.5), [*Cartographie*\ (OpenStreetMap,\ IGN BD TOPO)], green, <osm>, width: 30mm),
  _node((5, 3.5), [*Altimétrie*\ (IGN RGE ALTI)], green, <topo>, width: 30mm),
  _node((5, 4.5), [*Données forêts*\ (IGN BD Forêt)], green, <foret>, width: 30mm),
  
  _edge(<sat>, <agregateur>, green, mark: "=>", bend: -5deg),
  _edge(<meteoFR>, <agregateur>, green, mark: "=>"),
  _edge(<foudre>, <agregateur>, green, mark: "=>", bend: 5deg),
  _edge(<osm>, <agregateur>, green, mark: "=>", bend: 5deg),
  _edge(<topo>, <agregateur>, green, mark: "=>"),
  _edge(<foret>, <agregateur>, green, mark: "=>", bend: -5deg),

  
  // ==== Cloud Layer ====
  _node((2.5, 6), [*Interface globale*], red, <ui>, width: 30mm),
  _node((4.5, 6), [*Stockage global*], red, <cloud_store>, width: 30mm, shape: fletcher.shapes.cylinder),
  
  _edge(<agregateur>, <ui>, purple, label: _edge_txt([Réseau câblé\ (TCP/IP)], purple), label-side: left),
  _edge(<ui>, <cloud_store>, red, mark: "<|-|>"),
  
  
  // ==== Users Layer ====
  _node((2, 5), [👤 *Garde forestier*], gray, <garde>, shape: fletcher.shapes.pill, width: 35mm),
  _node((3.5, 5), [👤 *CODIS*], gray, <codis>, shape: fletcher.shapes.pill, width: 35mm),
  _node((1.25, 5.5), [👤 *Maintenance*], gray, <maintenance>, shape: fletcher.shapes.pill, width: 35mm),
  _node((1.5, 7), [👤 *Police scientifique*], gray, <police>, shape: fletcher.shapes.pill, width: 35mm),
  _node((3.5, 7), [👤 *Scientifique*], gray, <scientifique>, shape: fletcher.shapes.pill, width: 35mm),
  
  _edge(<agregateur>, <garde.north-east>, purple, label: _edge_txt([Notification], purple), label-side: right, "dashed"),
  _edge(<ui>, <garde>, red, label: _edge_txt([Visualisation], red), label-side: left, "dashed"),
  _edge(<ui>, <codis>, red, label: _edge_txt([Visualisation], red), label-side: right, "dashed"),
  _edge(<agregateur>, <maintenance.north>, purple, label: _edge_txt([Notification], purple), label-side: right, "dashed"),
  _edge(<maintenance>, <ui>, red, label: _edge_txt([Configuration], red), label-side: right, "dashed", label-pos: 40%),
  _edge(<ui>, <police>, red, label: _edge_txt([Visualisation], red), label-side: right, "dashed"),
  _edge(<ui>, <scientifique>, red, label: _edge_txt([Visualisation], red), label-side: left, "dashed"),
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
  #grid(
    columns: 4,
    column-gutter: 12pt, 
    align: horizon,
    _legend(_arrow("-|>"), [*Temps réel*]),
    _legend(_arrow("=>"), [*Programmé*]),
    _legend(_arrow("--|>"), [*Non-programmé*])
  )
]
