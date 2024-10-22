# install.packages("lavaan", dependencies = TRUE)
# install.packages("tidyverse", dependencies = TRUE)

install.packages( "psych", dependencies=TRUE)
install.packages( "Hmisc", dependencies=TRUE)
install.packages( "semPlot", dependencies=TRUE)
install.packages( "DiagrammeR", dependencies=TRUE)
install.packages( "lavaan.survey", dependencies=TRUE)
install.packages( "survey", dependencies=TRUE)
install.packages( "weights", dependencies=TRUE)
install.packages( "lmerTest", dependencies=TRUE)
install.packages( "cowplot", dependencies=TRUE)


library(lavaan)
library(tidyverse)
library(semPlot)
library(qgraph)

dall4 <- read.delim("data/national-w-created-vars.tab") |> tibble()
glimpse(dall4)
dall3 <- read.delim("data/national-w-created-vars-v3.tab") |> tibble()
glimpse(dall3)
#
# https//www.lavaan.ugent.be/tutorial/syntax1.html
# =~ is measured by
# latent: f1 =~ y1 + y2 + y3
# ~ regression
# y ~ x1 + x2 + x3
#
# y ~~ y variance
# y1 ~~ y2 covariance 

# variance covariance 

# latent variable x =~ .. 
# regression x ~ ...
# variance y ~~ y
# covariance y1 ~~ y2 
#
# enclosed in single quotes

# model1 <- '
# regressions
# y1 ~ f1 + f2 + f3 
# ....
# latent
# l1 =~ y1 + y2 + y3
# l2 =~ y4 + y5 ....
#
# correlations/covariances
# y1 ~~ y2
# y1 ~~ y1 
# '

# also in parts syntax

# fit <- cfa( model=mymodel, data=dall4 )

daniels_model <- '
    # latent
    
    faith_in_government =~     
        i_Politicians_All_The_Same + i_Politics_Force_For_Good + 
        i_Party_In_Government_Doesnt_Matter +
        i_Politicians_Dont_Care + i_Politicians_Want_To_Make_Things_Better +
        i_Shouldnt_Rely_On_Government
    social_position =~ log_income + Ladder + i_Satisfied_With_Income + i_Managing_Financially
    distress =~ sqrt_gad_7 + sqrt_phq_8 + In_Control_Of_Life

    # latent regressions
    faith_in_government ~ social_position
    distress ~ social_position
    basic_income_post ~ social_position + faith_in_government + distress + Age

    # variances
    # faith_in_government ~~ faith_in_government 
    # distress ~~ distress 
    # social_position ~~ social_position

    # covariances
    faith_in_government ~~ distress
    distress ~~ Age
    faith_in_government ~~ Age
    social_position ~~ Age

'

dans_fit <- sem( daniels_model, data=dall4 )
summary( dans_fit )
ss <- semPlotModel( daniels_model, standardized=T, fit.measures=T )
# pdf( "daniels_model.pdf", width=15, height=5)
semSyntax(ss, syntax = "lavaan", allFixed = FALSE, "ss.pdf")
# dev.off()

