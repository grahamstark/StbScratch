###UBI red wall project data analysis script
# Daniel Nettle May 2022
# Uses datafile produced by data processing script

library(lavaan)
library(tidyverse)
library(psych)
library(Hmisc)
library(semPlot)
library(DiagrammeR)
library(lavaan.survey)
library(survey)
library(weights)
library(lmerTest)
library(cowplot)
load("data/processeddata.Rdata")
d=subset(d, !is.na(d$Weight))
options(theme_set(theme_classic()))

###Descriptives of sample#####
xtabs(~d$Gender)
xtabs(~d$Gendertext)
psych::describe(d$Age)
# Support for UBI
weighted.mean(x=d$SupportUBI, w=d$Weight, na.rm=T)
sqrt(Hmisc::wtd.var(d$SupportUBI, weights=d$Weight))
wpct(x=(d$SupportUBI>50), weight=d$Weight)
wpct(x=(d$SupportUBI>75), weight=d$Weight)

####Treatment (narrative) effects#####
summary(lm(SupportUBI~Treatment, data=d, weights=Weight))
anova(lm(SupportUBI~Treatment, data=d, weights=Weight))
fig1 = d %>% 
  group_by(Treatment) %>% 
  summarise(mean.support=weighted.mean(SupportUBI, w=Weight), 
            se.support=sqrt(Hmisc::wtd.var(SupportUBI, weights=Weight))/sqrt(n())) %>% 
  ggplot(aes(x=Treatment, y=mean.support)) + geom_bar(stat="identity", fill="lightblue", colour="black") + 
  geom_errorbar(aes(ymax=mean.support+se.support, ymin=mean.support-se.support), width=0.25) + 
  xlab("Narrative") + ylab("Mean support for UBI") + 
  coord_cartesian(ylim=c(0, 100))
fig1
png("figure1.png", res=300, width=3*300, height=4*300)
fig1
dev.off()

###Structural equation model######
# Set up survey weight
svy.df<-svydesign(id=~ResponseID, 
                  weights=~Weight,
                  data=d)

# Unweighted SEM
model1<-'
  # Measurement model
  fg  =~  Politics1 + Politics2 + Politics3 + Politics4 + Politics5 + Politics6
  wb  =~  PHQs + GADs + Control
  sep =~  LogIncomeEquivalised + LadderSES + Satisfactionincome + Managingfinancially
  # Regressions
  fg ~ sep
  wb ~ sep
  SupportUBI ~ sep + fg + wb + Age
  # Covariances
  fg~~wb
  wb~~Age
  fg~~Age
  sep~~Age
'
m1 = sem(model1, data=d)
summary(m1, standardized=T, fit.measures=T)

#Weighted SEM 
m2 <- lavaan.survey(m1, svy.df, estimator="ML") 
summary(m2, standardized=T, fit.measures=T)

# Alternative model with no mediation pathways
# Unweighted SEM
control.model<-'
  # Measurement model
  sep =~  LogIncomeEquivalised + LadderSES + Satisfactionincome + Managingfinancially
  # Regressions
  SupportUBI ~ sep + Age
  # Covariances
  sep~~Age
'
m3 = sem(control.model, data=d)
summary(m3, standardized=T, fit.measures=T)

#Weighted 
m4 <- lavaan.survey(m3, svy.df, estimator="ML") 
summary(m4, standardized=T, fit.measures=T)


###DiagrammeR diagram of SEM #####

grViz("
digraph SEM {

graph [layout = neato,
       overlap = true,
       outputorder = edgesfirst]

node [shape = rectangle]

a [pos = '-4.5,-1!', label = 'Mng. Fin.']
b [pos = '-4.5,1!', label = 'Sat. Inc.']
c [pos = '-3,0!', label = 'Soc. Pos.', shape=ellipse]
d [pos = '0,-1!', label = 'Cyn. Gov.', shape=ellipse]
e [pos = '0,1!', label = 'Distress', shape=ellipse]
f [pos = '3,0!', label = 'Support UBI']
g [pos = '-1.5,2!', label = 'PHQ']
h [pos = '0,2!', label = 'GAD']
i [pos = '1.5,2!', label = 'Con.']
j [pos = '-2.5,-2!', label = 'g1']
k [pos = '-1.5,-2!', label = 'g2']
l [pos = '-0.5,-2!', label = 'g3']
m [pos = '0.5,-2!', label = 'g4']
n [pos = '1.5,-2!', label = 'g5']
o [pos = '2.5,-2!', label = 'g6']
p [pos = '-4.5,2!', label = 'Inc.']
q [pos = '-4.5,-2!', label = 'SES']
r [pos = '3, 2!', label='Age']

c->b [label='0.60*']
c->a [label='-0.81*']
c->p [label='0.36*']
c->q [label='0.74*']
e->g [label='0.90*']
e->h [label='0.87*']
e->i [label='-0.72*']

d->j [label='0.68*']
d->k [label='-0.71*']
d->l [label='0.59*']
d->m [label='0.76*']
d->n [label='-0.72*']
d->o [label='0.30*']

c->d [label='-0.31*']
c->e [label='-0.56*']
e->f [label='0.10*']
d->f [label='-0.09*']

c->f [label='-0.12*']

r->f [label ='-0.10*']

#d->e [label = '0.11*', dir = 'both']
}
")


### Overestimate of SES #####
ggplot(subset(d, !is.na(d$LadderSES)), aes(x=as.factor(IncomeQuintile), y=LadderSES)) + 
  geom_violin(fill="grey") + 
  geom_boxplot(width=0.2) + 
  theme_classic()

png("incomequintiles.png", res=300, width=4*300, height=4*300)
ggplot(subset(d, !is.na(d$LadderSES)), aes(y=LadderSES, x=as.factor(IncomeQuintile))) + 
  geom_violin(fill="grey") + 
  geom_boxplot(width=0.2) + 
  theme_classic() + 
  xlab("Quintile of income") + 
  ylab("Self-placement on ladder") + 
  scale_y_continuous(breaks=1:10)
dev.off()

###Support for different schemes#####
# Descriptives
weighted.mean(x=d$Scheme1support, w=d$Weight, na.rm=T)
sqrt(Hmisc::wtd.var(d$Scheme1support, weights=d$Weight))
weighted.mean(x=d$Scheme2support, w=d$Weight, na.rm=T)
sqrt(Hmisc::wtd.var(d$Scheme2support, weights=d$Weight))
weighted.mean(x=d$Scheme3support, w=d$Weight, na.rm=T)
sqrt(Hmisc::wtd.var(d$Scheme3support, weights=d$Weight))

# Make a socioeconomic position variable
pca.dat=select(d, LogIncomeEquivalised, LadderSES, Managingfinancially, Satisfactionincome)
KMO(pca.dat)
fa.parallel(pca.dat)
pca1=principal(r=pca.dat, nfactors=1, scores=TRUE)
d$socpos=pca1$scores

# Modelling support for schemes
support.data=select(d, Scheme1support, Scheme2support, Scheme3support, ResponseID, socpos, Weight, Age)
support.data = support.data %>% pivot_longer(cols=c(Scheme1support, Scheme2support, Scheme3support))
support.data$Scheme=recode(support.data$name, "Scheme1support" = "1", 
                           "Scheme2support" = "2", 
                           "Scheme3support" = "3")
m1=lmer(value~Scheme*socpos + Scheme*Age + (1|ResponseID), data=support.data, weights=Weight)
summary(m1)
anova(m1)


# Figure
figure3a = ggplot(support.data, aes(x=socpos, y=value)) + 
  geom_smooth(method="lm") + 
  facet_wrap(~Scheme) + 
  ylab("Support for scheme") + 
  xlab("Socioeconomic position") + 
  coord_cartesian(ylim=c(0, 100))
figure3a

figure3b = ggplot(support.data, aes(x=Age, y=value)) + 
  geom_smooth(method="lm", linetype="dotted") + 
  facet_wrap(~Scheme) + 
  ylab("Support for scheme") + 
  xlab("Age") + 
  coord_cartesian(ylim=c(0, 100))
figure3b

png("figure3.png", res=300, width=5*300, height=7*300)
plot_grid(figure3a, figure3b, labels=c("A", "B"), ncol=1)
dev.off()


###Bit about people overestimating their socioeconomic position#####
fig4 = ggplot(d, aes(x=as.factor(IncomeQuintile), y=LadderSES)) + 
  geom_violin(fill="lightgreen") + 
  geom_boxplot(width=0.25) + 
  xlab("Income quintile") + 
  ylab("MacArthur ladder position") + 
  scale_y_continuous(breaks=c(0, 2, 4, 6, 8, 10))
png("figure4.png", res=300, width=4*300, height=4*300)
fig4
dev.off()

fig4 = ggplot(d, aes(x=as.factor(IncomeQuintile), y=LadderSES)) + 
  geom_violin(fill="lightgreen") + 
  geom_boxplot(width=0.25) + 
  xlab("Income quintile") + 
  ylab("MacArthur ladder position") + 
  scale_y_continuous(breaks=c(0, 2, 4, 6, 8, 10))
png("figure4.png", res=300, width=4*300, height=4*300)
fig4
dev.off()



###
d$difference = d$Managingfinancially-d$Wouldmanagefinancially
hist(d$difference)

ggplot(d, aes(x=LogIncomeEquivalised, y=difference)) + 
  geom_smooth(method="lm")


difference.figure=ggplot(d, aes(x=as.factor(IncomeQuintile), y=difference)) + 
  geom_violin(fill="lightgrey") + 
  geom_boxplot(width=0.25) + 
  xlab("Income quintile") + 
  ylab("Difference made by UBI") + 
  geom_hline(yintercept=0, linetype="dotted")
png("differencefigure.png", res=300, width=4*300, height=4*300)
difference.figure
dev.off()
colnames(d)
xtabs(~d$IncomeQuintile + d$UBIgovernmentpolicy2 )


ggplot(d, aes(x=as.factor(UBIgovernmentpolicy2), y=SupportUBI)) + 
  geom_violin(fill="lightgrey") + 
  geom_boxplot(width=0.25) + 
#  xlab("Income quintile") + 
#  ylab("Difference made by UBI") + 
  geom_hline(yintercept=0, linetype="dotted")