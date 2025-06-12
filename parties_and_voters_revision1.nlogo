extensions[palette csv rnd table dbscan]
breed [humans human]
breed [parties party]

humans-own
[
  old_xcor
  old_ycor
  voting_for
  movement
  weight_polarization
  opinion_group_polarization_x
  opinion_group_polarization_y
]

parties-own
[
  old_xcor
  old_ycor
  voters
  old_voters
  party_type
  eccentricity
  movement
]

globals
[
  largest_party
  hunter_winning
  predator_winning
  aggregator_winning
  sticker_winning

    hunter_winning_current
  predator_winning_current
  aggregator_winning_current
  sticker_winning_current

  hunter_winning_list
  predator_winning_list
  aggregator_winning_list
  sticker_winning_list

  hunter_avg_share
  predator_avg_share
  aggregator_avg_share
  sticker_avg_share

  hunter_avg_share_current
  predator_avg_share_current
  aggregator_avg_share_current
  sticker_avg_share_current

  hunter_avg_share_list
  predator_avg_share_list
  aggregator_avg_share_list
  sticker_avg_share_list

  standard_deviation_x_humans
  standard_deviation_y_humans
  standard_deviation_x_parties
  standard_deviation_y_parties

  voter_misery
  mean_eccentricity
  weighted_eccentricity

  polarization_parties
  polarization_voters
  number_clusters_voters
]

to setup
  ca
  set hunter_avg_share_list []
  set predator_avg_share_list []
  set aggregator_avg_share_list []
  set sticker_avg_share_list []

  set hunter_winning_list []
  set predator_winning_list []
  set aggregator_winning_list []
  set sticker_winning_list []

  create-humans number_voters
  [
    set shape "circle"
    set size 0.02
    set color grey

    if initial_distribution = "uniform"
    [
      setxy random-xcor random-ycor
      set old_xcor xcor
      set old_ycor ycor
    ]
    if initial_distribution = "normal"
    [
      setxy max (list -0.49 min(list 0.49 random-normal 0 (0.5 / 3))) max (list -0.49 min(list 0.49 random-normal 0 (0.5 / 3)))
      set old_xcor xcor
      set old_ycor ycor
    ]
  ]

  create-parties number_parties_sticker
  [
    create_party
    set party_type "sticker"
    set color violet
  ]

  create-parties number_parties_hunter
  [
    create_party
    set party_type "hunter"
    set color blue
  ]

  create-parties number_parties_predator
  [
    create_party
    set party_type "predator"
    set color green
  ]

  create-parties number_parties_aggregator
  [
    create_party
    set party_type "aggregator"
    set color red
  ]

  if print_csv
  [
    file-close-all
    if file-exists? (word file_name ".csv")
    [
      file-delete (word file_name ".csv")
      file-open (word file_name ".csv")
      file-print "agent_id,type,period,x_cor,y_cor,votes"
      file-close-all
      with-local-randomness
    [
      print_agent_positions
    ]
    ]
  ]

  reset-ticks
end

to create_party
  set shape "circle"
  set size 0.05
  ;if initial_distribution = "uniform"
  ;[
    setxy precision (random-xcor) 8 precision (random-ycor) 8
    set old_xcor xcor
    set old_ycor ycor
  ;]

end

to update_colors

end


to go
  update_party
  update_opinions
  follow_party_strategy

  update_statistics
  measure-misery
  measure-eccentricity
  if measure_polarization_yes_no
  [
    measure_polarization
    measure_number_of_clusters
  ]
  tick
    if print_csv
  [
    with-local-randomness
    [
      print_agent_positions
    ]
  ]
end

to follow_party_strategy
  ;stickers don't move

  ;aggregators look for median voter
  ask parties with [party_type = "aggregator" and voters > 0]
  [
    set xcor max (list -0.5 min (list 0.5 precision ( mean  [xcor] of humans with [voting_for = myself]) 8))
    set ycor max (list -0.5 min (list 0.5 precision (mean  [ycor] of humans with [voting_for = myself]) 8))
  ]

  ;predator hunts biggest party
  ask parties with [party_type = "predator"]
  [
    face largest_party
    if self != largest_party
    [
      ifelse distance largest_party > step_size
      [
        jump step_size
      ]
      [
        jump distance largest_party
      ]
    ]
    set xcor max (list -0.5 min (list 0.5 precision (xcor) 8))
    set ycor max (list -0.5 min (list 0.5 precision (ycor) 8))
  ]
  ;hunter tries to repeat successful moves
  ask parties with [party_type = "hunter"]
  [
    if voters <= old_voters; or voters = 0
    [
      set heading (heading + 90 + random-float 180)
    ]
    jump step_size
    set xcor max (list -0.5 min (list 0.5 precision (xcor) 8))
    set ycor max (list -0.5 min (list 0.5 precision (ycor) 8))
  ]
end


to update_opinions

  ask humans
  [
    ;new version
    ifelse is-party? voting_for
    [
      let xcor_target  (1 - social_influence_alpha - party_attraction_beta) * old_xcor + (social_influence_alpha) * mean [old_xcor] of humans in-radius (bounded_confidence * sqrt 2) + (party_attraction_beta) * [xcor] of voting_for + random-normal 0 noise_opinions
      let ycor_target (1 - social_influence_alpha - party_attraction_beta) * old_ycor + (social_influence_alpha) * mean [old_ycor] of humans in-radius (bounded_confidence * sqrt 2) + (party_attraction_beta) * [ycor] of voting_for + random-normal 0 noise_opinions
      set xcor min (list 0.49 max (list -0.5 xcor_target))
      set ycor min (list 0.49 max (list -0.5 ycor_target))
    ]
    [
      let xcor_target  (1 - social_influence_alpha) * old_xcor + (social_influence_alpha) * mean [old_xcor] of humans in-radius (bounded_confidence * sqrt 2) + random-normal 0 noise_opinions
      let ycor_target (1 - social_influence_alpha) * old_ycor + (social_influence_alpha) * mean [old_ycor] of humans in-radius (bounded_confidence * sqrt 2) + random-normal 0 noise_opinions
      set xcor min (list 0.49 max (list -0.5 xcor_target))
      set ycor min (list 0.49 max (list -0.5 ycor_target))
    ]



  ]
end

to update_party
  ask humans
  [
    set movement distancexy old_xcor old_ycor
    set old_xcor xcor
    set old_ycor ycor

    if voting_rule = "pure proximity"
    [
      set voting_for one-of parties with-min [distance myself] with [distance myself < max_voting_distance]
    ]

    if voting_rule = "probability proximity"
    [
      let this_voter self
      let epsilon 0.001
      let eligible_parties parties with [distance this_voter < max_voting_distance]
      set voting_for rnd:weighted-one-of eligible_parties [ ln (1  + 1 / ( distance this_voter + epsilon)) / sum [ln (1 + 1 / (distance this_voter + epsilon))] of eligible_parties]
    ]
  ]

  ask parties
  [
    set old_xcor xcor
    set old_ycor ycor
    set old_voters voters
    set voters count humans with [voting_for = myself]
  ]

  set largest_party one-of parties with-max [voters]
end

to update_statistics

  ifelse any? parties with [party_type = "hunter"]
  [
    if length hunter_avg_share_list = 10
    [
      set hunter_avg_share_list but-last hunter_avg_share_list
    ]
    set hunter_avg_share_current mean [voters / number_voters] of parties with [party_type = "hunter"]

    set hunter_avg_share_list fput hunter_avg_share_current hunter_avg_share_list
    set hunter_avg_share mean hunter_avg_share_list
  ]
  [
    set hunter_avg_share 0
  ]
  ifelse any? parties with [party_type = "predator"]
  [
    if length predator_avg_share_list = 10
    [
      set predator_avg_share_list but-last predator_avg_share_list
    ]
    set predator_avg_share_current mean [voters / number_voters] of parties with [party_type = "predator"]

    set predator_avg_share_list fput predator_avg_share_current predator_avg_share_list
    set predator_avg_share mean predator_avg_share_list
  ]
  [
    set predator_avg_share 0
  ]
  ifelse any? parties with [party_type = "aggregator"]
  [
    if length aggregator_avg_share_list = 10
    [
      set aggregator_avg_share_list but-last aggregator_avg_share_list
    ]
    set aggregator_avg_share_current mean [voters / number_voters] of parties with [party_type = "aggregator"]

    set aggregator_avg_share_list fput aggregator_avg_share_current aggregator_avg_share_list
    set aggregator_avg_share mean aggregator_avg_share_list
  ]
  [
    set aggregator_avg_share 0
  ]
  ifelse any? parties with [party_type = "sticker"]
  [

    if length sticker_avg_share_list = 10
    [
      set sticker_avg_share_list but-last sticker_avg_share_list
    ]
    set sticker_avg_share_current mean [voters / number_voters] of parties with [party_type = "sticker"]
    set sticker_avg_share_list fput sticker_avg_share_current sticker_avg_share_list
    set sticker_avg_share mean sticker_avg_share_list
  ]
  [
    set sticker_avg_share 0
  ]
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;Hunter
  if length hunter_winning_list = 10
  [
    set hunter_winning_list but-last hunter_winning_list
  ]
  ifelse any? (parties with-max [voters]) with [party_type = "hunter"]
  [

    set hunter_winning_current count ((parties with-max [voters]) with [party_type = "hunter"]) / count parties with-max [voters]
  ]
  [
    set hunter_winning_current 0
  ]
  set hunter_winning_list fput hunter_winning_current hunter_winning_list
  set hunter_winning mean hunter_winning_list


  ;Predator
  if length predator_winning_list = 10
  [
    set predator_winning_list but-last predator_winning_list
  ]
  ifelse any? (parties with-max [voters]) with [party_type = "predator"]
  [

    set predator_winning_current count ((parties with-max [voters]) with [party_type = "predator"]) / count parties with-max [voters]
  ]
  [
    set predator_winning_current 0
  ]
  set predator_winning_list fput predator_winning_current predator_winning_list
  set predator_winning mean predator_winning_list

  ;Aggregator
  if length aggregator_winning_list = 10
  [
    set aggregator_winning_list but-last aggregator_winning_list
  ]
  ifelse any? (parties with-max [voters]) with [party_type = "aggregator"]
  [

    set aggregator_winning_current count ((parties with-max [voters]) with [party_type = "aggregator"]) / count parties with-max [voters]
  ]
  [
    set aggregator_winning_current 0
  ]
  set aggregator_winning_list fput aggregator_winning_current aggregator_winning_list
  set aggregator_winning mean aggregator_winning_list

  ;Sticker
  if length sticker_winning_list = 10
  [
    set sticker_winning_list but-last sticker_winning_list
  ]
  ifelse any? (parties with-max [voters]) with [party_type = "sticker"]
  [

    set sticker_winning_current count ((parties with-max [voters]) with [party_type = "sticker"]) / count parties with-max [voters]
  ]
  [
    set sticker_winning_current 0
  ]
  set sticker_winning_list fput sticker_winning_current sticker_winning_list
  set sticker_winning mean sticker_winning_list

  ;Standard deviation
  if count parties > 1
  [
    set standard_deviation_x_parties standard-deviation [xcor] of parties
    set standard_deviation_y_parties standard-deviation [ycor] of parties
  ]
  if number_voters > 1
  [
    set standard_deviation_x_humans standard-deviation [xcor] of humans
    set standard_deviation_y_humans standard-deviation [ycor] of humans
  ]


end

to measure-misery
 if count parties > 0
  [
    set voter_misery sum [((distance voting_for ^ 2))] of humans / number_voters
]
end

to measure-eccentricity
  let mean-voterx mean [xcor] of humans
  let mean-votery mean [ycor] of humans

  if count parties > 0
  [
    ask parties [set eccentricity sqrt ((xcor - mean-voterx) ^ 2 + (ycor - mean-votery) ^ 2) / 10]
     ;;calculate each party's eccentricity, its Euclidean distance from the center of the voter distribution
  set mean_eccentricity sum [eccentricity] of parties / count parties
    set weighted_eccentricity sum [eccentricity * voters / number_voters] of parties
     ;;calculate the mean eccentricity of all parties in the system
  ]
end

to measure_polarization
  let polarization_sum 0
ask parties
  [
    let party_i self
    ask parties
    [
      let party_j self
      set polarization_sum polarization_sum + ([voters] of party_i / number_voters) ^ (1 + polarization_alpha) * [voters] of party_j / number_voters * distance party_i
    ]
  ]
  set polarization_parties polarization_sum

;  let grouped_voters_x table:group-agents humans [precision xcor 3]
;
;  let grouped_voters_x_y []
;  foreach table:values grouped_voters_x
;  [ i ->
;     set grouped_voters_x_y (sentence table:values table:group-agents i [precision ycor 3] grouped_voters_x_y)
;
;
;  ]
  ;show grouped_voters_x_y
  let grouped_voters_x_y dbscan:cluster-by-location humans minimum_number_of_members_clusters maximum_distance_agents_clusters

  let final_agent_set (turtle-set)

  foreach grouped_voters_x_y
  [
    i ->
    let turtle_set_i turtle-set map [ j -> j ] i
    let sample_agent one-of turtle_set_i
    ask sample_agent
    [
      set weight_polarization count turtle_set_i
      set opinion_group_polarization_x mean [xcor] of turtle_set_i
      set opinion_group_polarization_y mean [ycor] of turtle_set_i
    ]
    set final_agent_set (turtle-set final_agent_set sample_agent)
  ]
  let polarization_sum_voters 0
  ask final_agent_set
  [
    let voter_i self
    ask final_agent_set
    [
      let voter_j self
      set polarization_sum_voters polarization_sum_voters + ([weight_polarization] of voter_i / number_voters) ^ (1 + polarization_alpha) * [weight_polarization] of voter_j / number_voters * (sqrt ( ([opinion_group_polarization_x] of voter_i - [opinion_group_polarization_x] of voter_j) ^ 2 + ([opinion_group_polarization_y] of voter_i - [opinion_group_polarization_y] of voter_j) ^ 2))
    ]
  ]
  set polarization_voters polarization_sum_voters
end

to measure_number_of_clusters
  let clusters_voters dbscan:cluster-by-location humans minimum_number_of_members_clusters maximum_distance_agents_clusters

  ; Show number of clusters
  set number_clusters_voters length clusters_voters
end

to print_agent_positions

  file-open (word file_name ".csv")
  ask humans
  [
    file-print (word who ", voter ," ticks "," xcor "," ycor "," 0)
  ]
  ask parties
  [
    file-print (word who ", " party_type " ," ticks "," xcor "," ycor "," voters)
  ]
  file-close-all
end
@#$#@#$#@
GRAPHICS-WINDOW
463
10
771
319
-1
-1
300.0
1
10
1
1
1
0
0
0
1
0
0
0
0
0
0
1
ticks
30.0

INPUTBOX
22
67
129
127
number_voters
1000.0
1
0
Number

BUTTON
23
11
127
44
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
220
80
391
125
initial_distribution
initial_distribution
"uniform" "normal"
1

BUTTON
147
11
210
44
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
219
134
391
167
bounded_confidence
bounded_confidence
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
220
175
392
208
social_influence_alpha
social_influence_alpha
0
1
0.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
50
309
144
359
Parties
20
0.0
1

TEXTBOX
27
51
177
69
Voters
11
0.0
1

INPUTBOX
148
338
306
398
number_parties_sticker
1.0
1
0
Number

SLIDER
219
213
391
246
max_voting_distance
max_voting_distance
0
2
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
18
134
206
167
party_attraction_beta
party_attraction_beta
0
1
0.1
0.01
1
NIL
HORIZONTAL

INPUTBOX
150
409
303
469
number_parties_hunter
1.0
1
0
Number

INPUTBOX
151
480
306
540
number_parties_aggregator
1.0
1
0
Number

INPUTBOX
149
552
304
612
number_parties_predator
1.0
1
0
Number

SLIDER
220
290
392
323
step_size
step_size
0
1
0.02
0.001
1
NIL
HORIZONTAL

TEXTBOX
24
362
90
387
Sticker
20
115.0
1

TEXTBOX
22
430
84
455
Hunter 
20
105.0
1

TEXTBOX
23
506
128
531
Aggregator 
20
15.0
1

TEXTBOX
23
574
107
599
Predator
20
55.0
1

SWITCH
726
579
832
612
print_csv
print_csv
0
1
-1000

INPUTBOX
725
513
1069
573
file_name
party_and_voter_positions_noise_party_attraction_normal
1
0
String

INPUTBOX
558
551
713
611
fixed_rs
1.0
1
0
Number

BUTTON
562
514
713
547
setup with fixed rs
random-seed fixed_rs\nsetup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
20
176
207
221
voting_rule
voting_rule
"pure proximity" "probability proximity"
0

PLOT
325
345
563
495
Eccentricity and Misery
NIL
NIL
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"eccentricity" 1.0 0 -2674135 true "" "plot mean_eccentricity"
"misery" 1.0 0 -13345367 true "" "plot voter_misery"

INPUTBOX
329
550
548
610
polarization_alpha
1.6
1
0
Number

PLOT
787
10
1067
160
Winning (avg last 10 periods)
NIL
NIL
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Hunter" 1.0 0 -13345367 true "" "plot hunter_winning"
"Aggregator" 1.0 0 -2674135 true "" "plot aggregator_winning"
"Predator" 1.0 0 -13840069 true "" "plot predator_winning"
"Sticker" 1.0 0 -8630108 true "" "plot sticker_winning"

SWITCH
328
513
548
546
measure_polarization_yes_no
measure_polarization_yes_no
0
1
-1000

BUTTON
218
11
316
44
go until 150
go\nif ticks = 150\n[\nstop\n]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
219
251
391
284
noise_opinions
noise_opinions
0
0.1
0.01
0.005
1
NIL
HORIZONTAL

PLOT
572
345
810
495
Distribution voters: xcor
NIL
NIL
-0.5
0.5
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 0 -16777216 true "" "histogram [xcor] of humans"

PLOT
823
345
1066
495
Distribution voters: ycor
NIL
NIL
-0.5
0.5
0.0
10.0
true
false
"" ""
PENS
"default" 0.01 0 -16777216 true "" "histogram [ycor] of humans"

PLOT
788
168
1067
318
Vote share (avg last 10 periods)
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Hunter" 1.0 0 -13345367 true "" "plot hunter_avg_share"
"Aggregator" 1.0 0 -2674135 true "" "plot aggregator_avg_share"
"Predator" 1.0 0 -13840069 true "" "plot predator_avg_share"
"Sticker" 1.0 0 -8630108 true "" "plot sticker_avg_share"

INPUTBOX
364
623
568
683
minimum_number_of_members_clusters
3.0
1
0
Number

INPUTBOX
582
624
737
684
maximum_distance_agents_clusters
0.1
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="voting_experiment_without_noise_1" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_2" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_3" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_4" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_6" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_7" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_8" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_9" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_10" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_11" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_12" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_13" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_14" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_15" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_16" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_17" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_18" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_19" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_20" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_21" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_22" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_23" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_24" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_26" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_27" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_28" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_29" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_30" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_31" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_32" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_33" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_34" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_35" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_36" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_37" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_38" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_39" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_40" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_41" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_42" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_43" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_44" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_45" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_46" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_47" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_48" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_49" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_without_noise_50" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_1" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_2" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_3" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_4" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_6" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_7" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_8" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_9" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_10" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.05"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_11" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_12" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_13" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_14" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_15" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_16" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_17" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_18" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_19" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_20" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.1"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_21" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_22" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_23" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_24" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_26" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_27" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_28" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_29" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_30" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0.05"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_31" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_32" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_33" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_34" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_35" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_36" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_37" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_38" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_39" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_40" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0.1"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_41" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_42" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_43" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_44" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_45" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_46" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_47" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_48" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_49" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_with_noise_50" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.15"/>
      <value value="0.1"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <subExperiment>
      <enumeratedValueSet variable="social_influence_alpha">
        <value value="0"/>
      </enumeratedValueSet>
      <enumeratedValueSet variable="party_attraction_beta">
        <value value="0"/>
      </enumeratedValueSet>
    </subExperiment>
  </experiment>
  <experiment name="voting_experiment_sens_analysis1" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis2" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis3" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis4" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis6" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis7" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis8" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis9" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis10" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis11" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis12" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis13" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis14" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis15" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis16" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis17" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis18" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis19" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis20" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0" step="0.025" last="0.1"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis21" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis22" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis23" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis24" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis26" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis27" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis28" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis29" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis30" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0.125" step="0.025" last="0.2"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis31" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="1" step="1" last="10"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis32" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="11" step="1" last="20"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis33" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="21" step="1" last="30"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis34" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="31" step="1" last="40"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis35" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="41" step="1" last="50"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis36" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis37" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="61" step="1" last="70"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis38" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="71" step="1" last="80"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis39" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="81" step="1" last="90"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
  <experiment name="voting_experiment_sens_analysis40" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup
set measure_polarization_yes_no false</setup>
    <go>go
if ticks = 498
[
set measure_polarization_yes_no true
]</go>
    <timeLimit steps="500"/>
    <metric>hunter_winning</metric>
    <metric>predator_winning</metric>
    <metric>aggregator_winning</metric>
    <metric>sticker_winning</metric>
    <metric>hunter_avg_share</metric>
    <metric>predator_avg_share</metric>
    <metric>aggregator_avg_share</metric>
    <metric>sticker_avg_share</metric>
    <metric>voter_misery</metric>
    <metric>mean_eccentricity</metric>
    <metric>weighted_eccentricity</metric>
    <metric>polarization_parties</metric>
    <metric>polarization_voters</metric>
    <metric>number_clusters_voters</metric>
    <steppedValueSet variable="random-seed" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="bounded_confidence">
      <value value="1"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_distribution">
      <value value="&quot;uniform&quot;"/>
      <value value="&quot;normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_voters">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max_voting_distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step_size">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise_opinions">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum_number_of_members_clusters">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum_distance_agents_clusters">
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number_parties_sticker" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_hunter" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_predator" first="0" step="1" last="4"/>
    <steppedValueSet variable="number_parties_aggregator" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="print_csv">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting_rule">
      <value value="&quot;pure proximity&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="social_influence_alpha" first="0.125" step="0.025" last="0.2"/>
    <steppedValueSet variable="party_attraction_beta" first="0" step="0.025" last="0.1"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
