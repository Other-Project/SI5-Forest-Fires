#import "@preview/ilm:1.4.1": *

#set text(lang: "fr")

#show: ilm.with(
  title: [Prévention et détection des incendies en forêt],
  author: "Anthony Vasta, Evan Galli, Sacha Castillejos",
  date: datetime(year: 2025, month: 11, day: 04),
  date-format: "[year repr:full]-[month padding:zero]-[day padding:zero]",
  abstract: [
    #text(size:14pt,style: "italic")[\- Partie gestion des données \-]
    #linebreak()#linebreak()
    Ce projet propose un système IoT pour la prévention et la détection précoce des incendies de forêt, combinant capteurs connectés, caméras intelligentes et analyse prédictive. L’architecture conçue permet une surveillance en temps réel, une transmission rapide des alertes et un meilleur usage des forces d'intervention tout en limitant l’impact environnemental.
  ],
  preface: include("avant_propos.typ"),
  figure-index: (enabled: false),
  table-index: (enabled: false),
  listing-index: (enabled: false),
  bibliography: bibliography("refs.yml", style: "ieee"),
)


#include "capteurs.typ"

#include "incertitudes.typ"

#include "traitement.typ"

#include "pipeline.typ"
