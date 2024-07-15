library(data.table)

setwd("Z:/Parteienwettbewerb-WählerInnen/Polarisierungsdaten")
setwd("Z:/Parteienwettbewerb-WählerInnen/")
simulation_list <- list.files(path = getwd(), pattern = "model_parties_and_voters8_voting_experiment*") 

full_simulation_data <- NULL
#simulation data
#loop through all .csv files
while(length(simulation_list) > 0)
{
  simulation_data <- fread(simulation_list[1], skip=6)
  if (exists("full_simulation_data"))
  {
    full_simulation_data <- rbind(full_simulation_data, simulation_data)
  } else
  {
    full_simulation_data <- simulation_data
  }
  simulation_list <- simulation_list[-1]
  
}

dynamischer_parteienwettbewerb_daten <- full_simulation_data
save(dynamischer_parteienwettbewerb_daten, file = "dynamischer_parteienwettbewerb_daten.RData")

library(sqldf)

#View(subset(dynamischer_parteienwettbewerb_daten, opinion_change == 0))

#sqldf("SELECT bounded_confidence, opinion_change, party_identification_effect, AVG(sticker_winning) AS sticker_winning, AVG(hunter_winning) AS hunter_winning, AVG(predator_winning) AS predator_winning, AVG(aggregator_winning) AS aggregator_winning, AVG(standard_deviation_x_humans) AS standard_deviation_x_voters, AVG(standard_deviation_y_humans) AS standard_deviation_y_voters, AVG(hunter_avg_share) AS hunter_avg_share, AVG(predator_avg_share) AS predator_avg_share, AVG(aggregator_avg_share) AS aggregator_avg_share, AVG(sticker_avg_share) AS sticker_avg_share FROM dynamischer_parteienwettbewerb_daten GROUP BY bounded_confidence, opinion_change, party_identification_effect")

#sqldf("SELECT DISTINCT party_identification_effect FROM dynamischer_parteienwettbewerb_daten")

dynamischer_parteienwettbewerb_daten$parameter_kombination <- paste(dynamischer_parteienwettbewerb_daten$number_parties_sticker, dynamischer_parteienwettbewerb_daten$number_parties_hunter, dynamischer_parteienwettbewerb_daten$number_parties_aggregator, dynamischer_parteienwettbewerb_daten$number_parties_predator, dynamischer_parteienwettbewerb_daten$opinion_change, dynamischer_parteienwettbewerb_daten$party_identification_effect, dynamischer_parteienwettbewerb_daten$bounded_confidence)
dynamischer_parteienwettbewerb_daten$total_number_parties <- dynamischer_parteienwettbewerb_daten$number_parties_sticker + dynamischer_parteienwettbewerb_daten$number_parties_hunter + dynamischer_parteienwettbewerb_daten$number_parties_predator + dynamischer_parteienwettbewerb_daten$number_parties_aggregator

dynamischer_parteienwettbewerb_daten$scenario <- "static\nvoter distribution"
dynamischer_parteienwettbewerb_daten[dynamischer_parteienwettbewerb_daten$opinion_change == 0 & dynamischer_parteienwettbewerb_daten$party_identification_effect == 0.04]$scenario <- "party identification\neffect only"
dynamischer_parteienwettbewerb_daten[dynamischer_parteienwettbewerb_daten$opinion_change == 0.04 & dynamischer_parteienwettbewerb_daten$party_identification_effect == 0]$scenario <- "social influence\nonly"
dynamischer_parteienwettbewerb_daten[dynamischer_parteienwettbewerb_daten$opinion_change == 0.04 & dynamischer_parteienwettbewerb_daten$party_identification_effect == 0.01]$scenario <- "strong\nsocial influence"
dynamischer_parteienwettbewerb_daten[dynamischer_parteienwettbewerb_daten$opinion_change == 0.01 & dynamischer_parteienwettbewerb_daten$party_identification_effect == 0.04]$scenario <- "strong party\nidentification effect"
dynamischer_parteienwettbewerb_daten$scenario <- factor(dynamischer_parteienwettbewerb_daten$scenario, levels = c("static\nvoter distribution", "social influence\nonly", "strong\nsocial influence", "party identification\neffect only", "strong party\nidentification effect"))
library(ggplot2)

#hunter
#ggplot(data=dynamischer_parteienwettbewerb_daten) + 
#  geom_point(aes(x=hunter_winning, y=hunter_avg_share, group = parameter_kombination))


daten_aggregiert <- sqldf("SELECT number_parties_sticker, number_parties_hunter, number_parties_predator, number_parties_aggregator, bounded_confidence, opinion_change, party_identification_effect, AVG(sticker_winning) AS sticker_winning, AVG(hunter_winning) AS hunter_winning, AVG(predator_winning) AS predator_winning, AVG(aggregator_winning) AS aggregator_winning, AVG(standard_deviation_x_humans) AS standard_deviation_x_voters, AVG(standard_deviation_y_humans) AS standard_deviation_y_voters, AVG(hunter_avg_share) AS hunter_avg_share, AVG(predator_avg_share) AS predator_avg_share, AVG(aggregator_avg_share) AS aggregator_avg_share, AVG(sticker_avg_share) AS sticker_avg_share FROM dynamischer_parteienwettbewerb_daten GROUP BY bounded_confidence, opinion_change, party_identification_effect, number_parties_sticker, number_parties_hunter, number_parties_predator, number_parties_aggregator")
daten_aggregiert$total_number_parties <- daten_aggregiert$number_parties_sticker + daten_aggregiert$number_parties_hunter + daten_aggregiert$number_parties_predator + daten_aggregiert$number_parties_aggregator
#hunter
ggplot(data=subset(daten_aggregiert, number_parties_hunter < total_number_parties)) + 
  geom_point(aes(x=hunter_winning, y=hunter_avg_share, color = "hunter" ))+ 
  geom_point(aes(x=aggregator_winning, y=aggregator_avg_share, color = "aggregator" ))+ 
  geom_point(aes(x=predator_winning, y=predator_avg_share, color = "predator" ))+ 
  geom_point(aes(x=sticker_winning, y=sticker_avg_share, color = "sticker" ))



library(ggpubr)

p_winning_shares <- ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=aggregator_winning, group = interaction(bounded_confidence, "aggregator"), color = "aggregator", shape = "aggregator"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=hunter_winning, group = interaction(bounded_confidence, "hunter"), color = "hunter", shape = "hunter"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=predator_winning, group = bounded_confidence, color = "predator", shape = "predator"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=sticker_winning, group = bounded_confidence, color = "sticker", shape = "sticker")) + 
  facet_grid(.~scenario) + 
  labs(x = "Confidence bound \u03B5", y = "Runs won by", color = "Party type", shape = "Party type") + 
  scale_y_continuous(labels = scales::percent) +
  theme_bw()  + scale_color_brewer(palette="Set1") + 
  scale_shape_manual(values=c(15,16,17,18))

p_winning_shares <- p_winning_shares + ggtitle("Runs won by") +
  theme(plot.title = element_text(hjust = 0.5)) + theme(plot.title = element_text(face = "bold"))
ggsave(p_winning_shares, file="winning_share.PNG", width = 8, height = 3)



p_average_shares <- ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=aggregator_avg_share, group = interaction(bounded_confidence, "aggregator"), color = "aggregator", shape = "aggregator"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=hunter_avg_share, group = interaction(bounded_confidence, "hunter"), color = "hunter", shape = "hunter"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=predator_avg_share, group = bounded_confidence, color = "predator", shape = "predator"))+ 
  stat_summary(fun = "mean", geom= "point", size = 2,  aes(x=factor(bounded_confidence), y=sticker_avg_share, group = bounded_confidence, color = "sticker", shape = "sticker")) + 
  facet_grid(.~scenario) + 
  labs(x = "Confidence bound \u03B5", y = "Average vote share", color = "Party type", shape = "Party type") + 
  scale_y_continuous(labels = scales::percent) +
  theme_bw()  + scale_color_brewer(palette="Set1") + 
  scale_shape_manual(values=c(15,16,17,18))

p_average_shares <- p_average_shares + ggtitle("Average vote share") +
  theme(plot.title = element_text(hjust = 0.5))+ theme(plot.title = element_text(face = "bold"))

ggsave(p_average_shares, file="average_vote_shares.PNG", width = 8, height = 3)


p_standard_deviation_x <-ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(fun = "mean", geom= "point", size = 3,  aes(x=factor(bounded_confidence), y=standard_deviation_x_humans, group = interaction(bounded_confidence, "aggregator"), color = "voters", shape = "voters"))+ 
  stat_summary(fun = "mean", geom= "point", size = 3, aes(x=factor(bounded_confidence), y=standard_deviation_x_parties, group = interaction(bounded_confidence, "aggregator"), color = "parties", shape = "parties"))+ 
  facet_grid(.~scenario) + 
  labs(x = "Confidence bound \u03B5", y = "Standard deviation in x", color = "Agent type", shape = "Agent type") + 
  theme_bw()  + scale_color_brewer(palette="Dark2")


p_standard_deviation_x <- p_standard_deviation_x + ggtitle("Standard deviation (x)") +
  theme(plot.title = element_text(hjust = 0.5)) + theme(plot.title = element_text(face = "bold"))
  
ggsave(p_standard_deviation_x, file="standard_deviation_in_x.PNG", width = 8, height = 3)


#subset(dynamischer_parteienwettbewerb_daten, predator_avg_share < predator_winning -0.3 & scenario == "strong party\nidentification effect")

p_standard_deviation_y <-ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(fun = "mean", geom= "point", size = 3,  aes(x=factor(bounded_confidence), y=standard_deviation_y_humans, group = interaction(bounded_confidence, "aggregator"), color = "voters", shape = "voters"))+ 
  stat_summary(fun = "mean", geom= "point", size = 3, aes(x=factor(bounded_confidence), y=standard_deviation_y_parties, group = interaction(bounded_confidence, "aggregator"), color = "parties", shape = "parties"))+ 
  facet_grid(.~scenario) + 
  labs(x = "Confidence bound \u03B5", y = "Standard deviation in y", color = "Agent type", shape = "Agent type") + 
  theme_bw()  + scale_color_brewer(palette="Dark2")



p_standard_deviation_y <- p_standard_deviation_y + ggtitle("Standard deviation (y)") +
  theme(plot.title = element_text(hjust = 0.5)) + theme(plot.title = element_text(face = "bold"))

ggsave(p_standard_deviation_y, file="standard_deviation_in_y.PNG", width = 8, height = 3)



p_polarization <-ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(fun = "mean", geom= "point", size = 3,  aes(x=factor(bounded_confidence), y= polarization_voters , group = interaction(bounded_confidence, "aggregator"), color = "voters", shape = "voters"))+ 
  stat_summary(fun = "mean", geom= "point", size = 3, aes(x=factor(bounded_confidence), y= polarization_parties, group = interaction(bounded_confidence, "aggregator"), color = "parties", shape = "parties"))+ 
  facet_grid(.~scenario) + 
  labs(x = "Confidence bound \u03B5", y = "Polarization", color = "Agent type", shape = "Agent type") + 
  theme_bw()  + scale_color_brewer(palette="Dark2")

p_polarization <- p_polarization + ggtitle("Polarization") +
  theme(plot.title = element_text(hjust = 0.5)) + theme(plot.title = element_text(face = "bold"))

ggsave(p_polarization, file="polarization.PNG", width = 8, height = 3)



aggregate_runs_gesamt <- ggarrange(p_winning_shares, p_average_shares, ncol = 1, nrow = 2, labels = c("", ""), hjust = -0.4, common.legend =  TRUE, legend = "bottom")

ggsave(aggregate_runs_gesamt, file = "aggregate_runs_gesamt.PNG", height = 5, width = 6.2)


polarisierung_fragmentierung <- ggarrange(p_standard_deviation_x, p_polarization, ncol = 1, nrow = 2, labels = c("", ""), hjust = -0.4, common.legend =  TRUE, legend = "bottom")

ggsave(polarisierung_fragmentierung, file = "polarisierung_fragmentierung.PNG", height = 5, width = 6.2)


stat_summary(aes(x=factor(bounded_confidence), y=standard_deviation_y_humans, group = interaction(bounded_confidence, "aggregator"), color = "y"), geom="errorbar", width=0.2)+ 
  

ggplot(data=dynamischer_parteienwettbewerb_daten) + 
  stat_summary(aes(x=factor(bounded_confidence), y=voter_misery, group = interaction(bounded_confidence, "voter misery"), color = "voter misery"), geom="errorbar", width=0.2)+ 
  stat_summary(aes(x=factor(bounded_confidence), y=mean_eccentricity, group = interaction(bounded_confidence, "mean_eccentricity"), color = "mean eccentricity"), geom="errorbar", width=0.2)+ 
  facet_wrap(opinion_change~party_identification_effect, labeller = label_both)



##einzelne Positionen 

install.packages("ggpubr")

subset(dynamischer_parteienwettbewerb_daten, predator_avg_share < predator_winning -0.3 & scenario == "strong party\nidentification effect")

party_and_voter_positions_individual <- fread("party_and_voter_positions_predator.csv")

predator_vs_aggregator_x <- ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=x_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "grey")) + 
  labs(x="Period", y = "x coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)

#ggsave(predator_vs_aggregator_x, file="predator_vs_aggregator_x.PNG", width = 3, height = 3)


predator_vs_aggregator_y <- ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=y_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "grey")) + 
  labs(x="Period", y = "y coordinate", colour = "") +
  theme_bw()+ 
  guides(colour=FALSE)

#ggsave(predator_vs_aggregator_y, file="predator_vs_aggregator_y.PNG", width = 4, height = 3)

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=y_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = subset(party_and_voter_positions_individual, type != "voter")) + 
  geom_line(aes(x=period, y=votes / 10, group=agent_id, color=type))  + scale_color_manual(values = c( "red", "blue", "green", "violet"))

RColorBrewer::brewer.pal(8, "Set1")

predator_vs_aggregator <- ggplot(data = subset(party_and_voter_positions_individual, type != "voter" & period == 499)) + 
  geom_histogram(position = "stack", aes(x=votes, fill = type), colour="black") + 
    scale_fill_brewer(palette="Set1") + theme_bw() + scale_y_continuous(breaks = seq(0, 9, by = 1)) +
  labs(fill="", x = "Number of votes", y = "Number of parties")

#ggsave(predator_vs_aggregator, file="predator_vs_aggregator.PNG", width = 5, height = 3)

library(ggpubr)

predator_vs_aggregator_gesamt <- ggarrange(ggarrange(predator_vs_aggregator_x, predator_vs_aggregator_y, ncol = 2, labels = c("A", "B")),
          predator_vs_aggregator +            theme(plot.margin = margin(0, 0, 0, 0.73, unit = "cm")),                                                 # First row with scatter plot
          nrow = 2, 
          labels = c("", "C")                                        # Labels of the scatter plot
) 

ggsave(predator_vs_aggregator_gesamt, file="predator_vs_aggregator_gesamt.PNG", width = 5, height = 4)

##einzelne Positionen

library(data.table)
party_and_voter_positions_static <- fread("party_and_voter_positions_static.csv")

party_and_voter_positions_static_x <- ggplot() + 
  geom_line(data = subset(party_and_voter_positions_static, type == "voter"  & period <= 250), aes(x=period, y=x_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_static, type != "voter"  & period <= 250), linewidth = 1.5, aes(x=period, y=x_cor, group=agent_id, color=type)) + 
  
 scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "x coordinate", colour = "") +
  theme_bw() 

#ggsave(predator_vs_aggregator_x, file="predator_vs_aggregator_x.PNG", width = 3, height = 3)


party_and_voter_positions_static_y <-  ggplot() + 
  geom_line(data = subset(party_and_voter_positions_static, type == "voter" & period <= 250), aes(x=period, y=y_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_static, type != "voter"  & period <= 250), linewidth = 1.5, aes(x=period, y=y_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "y coordinate", colour = "") +
  theme_bw() + 
  annotation_custom(grid::linesGrob(x = c(-0.12, 1.19), y = c(-.07, -.07)))

party_and_voter_positions_party_identification_effect_only <- fread("party_and_voter_positions_party_identification_effect_only.csv")
party_and_voter_positions_party_identification_effect_only <- subset(party_and_voter_positions_party_identification_effect_only, period <= 500)

party_and_voter_positions_party_identification_effect_only_x <- ggplot() + 
  geom_line(data = subset(party_and_voter_positions_party_identification_effect_only, type == "voter" & period <= 250), aes(x=period, y=x_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_party_identification_effect_only, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=x_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "x coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)

party_and_voter_positions_party_identification_effect_only_y <-  ggplot() + 
  geom_line(data = subset(party_and_voter_positions_party_identification_effect_only, type == "voter" & period <= 250), aes(x=period, y=y_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_party_identification_effect_only, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=y_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "y coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)



party_and_voter_positions_social_influence_only_bc1 <- fread("party_and_voter_positions_social_influence_only.csv")

party_and_voter_positions_social_influence_only_bc1_x <- ggplot() + 
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc1, type == "voter" & period <= 250), aes(x=period, y=x_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc1, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=x_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "x coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)

party_and_voter_positions_social_influence_only_bc1_y <-  ggplot() + 
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc1, type == "voter" & period <= 250), aes(x=period, y=y_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc1, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=y_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "y coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)


party_and_voter_positions_social_influence_only_bc0.15 <- fread("party_and_voter_positions_social_influence_only_bc0.15.csv")

party_and_voter_positions_social_influence_only_bc0.15_x <- ggplot() + 
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc0.15, type == "voter" & period <= 250), aes(x=period, y=x_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc0.15, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=x_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "x coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)

party_and_voter_positions_social_influence_only_bc0.15_y <-  ggplot() + 
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc0.15, type == "voter" & period <= 250), aes(x=period, y=y_cor, group=agent_id, color=type)) +
  geom_line(data = subset(party_and_voter_positions_social_influence_only_bc0.15, type != "voter" & period <= 250), linewidth = 1.5, aes(x=period, y=y_cor, group=agent_id, color=type)) + 
  
  scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "lightgrey")) + 
  labs(x="Period", y = "y coordinate", colour = "") +
  theme_bw() + 
  guides(colour=FALSE)

individual_runs_gesamt <- ggarrange(party_and_voter_positions_static_x +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_static_y+            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_party_identification_effect_only_x  +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_party_identification_effect_only_y  +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_social_influence_only_bc1_x +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_social_influence_only_bc1_y +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_social_influence_only_bc0.15_x +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), party_and_voter_positions_social_influence_only_bc0.15_y +            theme(plot.margin = margin(1, 0, 0, 0, unit = "cm")), ncol = 2, nrow = 4, labels = c("", "Static voter distribution", "", "Party identification effect only", "", "Social influence only (\u03B5=1)", "", "Social influence only (\u03B5=0.15)"), hjust = 0.4, common.legend =  TRUE, legend = "bottom")
                            
ggsave(individual_runs_gesamt, file = "individual_runs_gesamt.PNG", height = 8, width = 5)


party_and_voter_positions_individual <- fread("party_and_voter_positions.csv")

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=x_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "grey"))

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=y_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = subset(party_and_voter_positions_individual, type != "voter")) + 
  geom_line(aes(x=period, y=votes / 10, group=agent_id, color=type)) + scale_color_manual(values = c( "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"))


##ohne party identification effect

party_and_voter_positions_individual <- fread("party_and_voter_positions2.csv")

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=x_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=y_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = subset(party_and_voter_positions_individual, type != "voter")) + 
  geom_line(aes(x=period, y=votes / 10, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet"))


##statische politische landschaft

party_and_voter_positions_individual <- fread("party_and_voter_positions1.csv")

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=x_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = party_and_voter_positions_individual) + 
  geom_line(aes(x=period, y=y_cor, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet", "grey"))

ggplot(data = subset(party_and_voter_positions_individual, type != "voter")) + 
  geom_line(aes(x=period, y=votes / 10, group=agent_id, color=type)) + scale_color_manual(values = c( "red", "blue", "green", "violet"))
