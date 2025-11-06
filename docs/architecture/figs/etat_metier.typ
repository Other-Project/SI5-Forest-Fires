#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#set text(size: 8pt, font: "New Computer Modern")

#let radius = 5em

#diagram(
	node-stroke: .1em,
 edge-stroke: .1em,
	spacing: 10em,
 
	edge((-1,3), "r", "=>"),
	node((0,3), [Réception\ des données], radius: radius, extrude: (-2.5, 0), name: <init>),
	edge("-|>", bend: 20deg),
	edge("<|-", bend: -20deg),
	node((1,4), [Calcul du\ risque incendie], radius: radius),
	edge("-|>", [Conditions propices\ à un départ de feu]),
	node((2,4), [Alerte zone à risque d'incendie], radius: radius),
	edge(<stop>, "-|>", [Retour à des conditions normale], label-side: right),

 node((1,2), [Alerte potentiel\ départ de feu], radius: radius, name: <alert>),
	edge(<init>, "<|-", [Anomalie détecté]),
	edge("-|>", [Pas de feu], label-side: right),
 node((2,2.5), [Fausse alerte], radius: radius),
	edge(<stop>, "-|>"),
 
 node((2,1.5), [Incendie], radius: radius),
	edge(<alert>, "<|-", [Départ de feu]),
	edge("-|>"),
 node((3,1.5), [Prédiction de la propagation du feu], radius: radius),
	edge("-|>"),
 node((3,2.25), [Envoie des\ informations\ de propagation], radius: radius),
	edge(<stop>, "-|>", [Fin de l'incendie], label-side: left),
 

 node((3,3), [Arrêter l'alerte], radius: radius, name: <stop>),
	edge(<init>, "-|>", [Retour à la surveillance]),
 
)