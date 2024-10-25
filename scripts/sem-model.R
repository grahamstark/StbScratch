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

# rename variables so they display better

abbrevs <- c( 
        Pols_All_Same = "i_Politicians_All_The_Same",
        Pol_For_Good = "i_Politics_Force_For_Good",
        Gov_Not_Matter = "i_Party_In_Government_Doesnt_Matter",
        Pol_Not_Care = "i_Politicians_Dont_Care",
        Pol_Want_Improve = "i_Politicians_Want_To_Make_Things_Better",
        Pol_Not_rely = "i_Shouldnt_Rely_On_Government",
        Satisf_Income  = "i_Satisfied_With_Income" ,
        Mang_Financial = "i_Managing_Financially",
        In_Control = "In_Control_Of_Life",
        BI = "basic_income_pre",
        Green_ND_Support="green_nd_pre", 
        Utilities="utilities_pre", 
        Health="health_pre", 
        Childcare="childcare_pre", 
        Education="education_pre", 
        Housing="housing_pre", 
        Transport="transport_pre", 
        Democract="democracy_pre", 
        Tax="tax_pre" )

dall4 <- dall4 |> rename(all_of(abbrevs))

# MUST BE in this order. Doesn't actually need to be
# a dict - only values needed,


daniels_model_1_graph_renames = list(
        "Pols_All_Same" = "Pols All Same",
        "Pol_For_Good" = "Pols Force For Good",
        "Gov_Not_Matter" = "Party In Govt Irrel.",
        "Pol_Not_Care" = "Pols Don't Care",
        "Pol_Want_Improve" = "Pols Improve Things",
        "Pol_Not_rely" = "Shouldn't Rely On Govt",
        "log_income" = "Log(Income)",
        "Ladder" = "Ladder",
        "Satisf_Income" = "Satisf W. Income" ,
        "Mang_Financial" = "Manag Financial",
        "BI_Support" = "Support UBI",
        "Age" = "Age",
        "sqrt_gad_7" = "sqrt(GAD-7)",
        "sqrt_phq_8" = "sqrt(PHQ-8)",
        "In_Control" = "Control of Life",
        "faith_gov" = "Faith In Govt",        
        "soc_pos" = "Social Pos",
        "distress" = "Distress")

daniels_model_1_graph_renames = c(
        "Pols All Same",
        "Pols Force For Good",
        "Party In Govt Irrel.",
        "Pols Don't Care",
        "Pols Improve Things",
        "Shouldn't Rely On Govt",
        "Log(Income)",
        "Ladder",
        "Satisf W. Income",
        "Manag Financial",
        "Support UBI",
        "Age",
        "sqrt(GAD-7)",
        "sqrt(PHQ-8)",
        "Control of Life",
        "Faith In Govt",
        "Social Pos",
        "Distress")

daniels_model_template <- '
    # latent
    
    faith_gov =~
        Pols_All_Same + Pol_For_Good + 
        Gov_Not_Matter +
        Pol_Not_Care + Pol_Want_Improve +
        Pol_Not_rely
    soc_pos =~ log_income + Ladder + Satisf_Income + Mang_Financial
    distress =~ sqrt_gad_7 + sqrt_phq_8 + In_Control

    # latent regressions
    faith_gov ~ soc_pos
    distress ~ soc_pos
    {policy} ~ soc_pos + faith_gov + distress + Age

    # variances
    # faith_gov ~~ faith_gov 
    # distress ~~ distress 
    # soc_pos ~~ soc_pos

    # covariances
    faith_gov ~~ distress
    distress ~~ Age
    faith_gov ~~ Age
    soc_pos ~~ Age
'

simple_model <- '
    soc_pos =~ log_income + Ladder + Satisf_Income + Mang_Financial
    BI_Support ~ soc_pos + Age
    soc_pos ~~ Age   
'

policy = 'BI_Support'
policy_label = "BI Support"

daniels_model_1 = glue( daniels_model_template )

daniels_model_1_fit <- sem( daniels_model_1, data=dall4 ) #, se='boot', bootstrap=1000 )
summary( daniels_model_1_fit, standardized=T )
parameterEstimates(daniels_model_1_fit)
simple_model_fit <- sem( simple_model, data=dall4 )
summary( simple_model_fit )

# ss <- semPlotModel( daniels_model, standardized=T, fit.measures=T )
# pdf( "daniels_model.pdf", width=15, height=5)
# semSyntax(ss, syntax = "lavaan", allFixed = FALSE, "ss.pdf")
# dev.off()

semPaths( simple_model_fit )

semPaths( 
    daniels_model_1_fit, 
    "std", 
    filetype="pdf",
    filename="tmp/img/daniels_model_1",
    layout="tree", 
    rotation=4,
    nodeLabels = daniels_model_1_graph_renames )


semPaths( 
    daniels_model_1_fit, 
    "std", 
    # filetype="pdf",
    # filename="tmp/img/daniels_model_1",
    layout="tree", 
    rotation=4,
    nodeLabels = daniels_model_1_graph_renames )



semPaths( 
    daniels_model_1_fit, 
    what="std",
    # whatLabels="std",
    # edge.label.cex=1.3, 
    filetype="pdf",
    filename="tmp/img/daniels_model_1",
    # layout="tree", 
    # rotation=4,
    nodeLabels = daniels_model_1_graph_renames, 
    residuals=FALSE )

model_template <- '
    # latent
    
    faith_gov =~
        Pols_All_Same + Pol_For_Good + 
        Gov_Not_Matter +
        Pol_Not_Care + Pol_Want_Improve +
        Pol_Not_rely
    soc_pos =~ log_income + Ladder + Satisf_Income + Mang_Financial
    distress =~ sqrt_gad_7 + sqrt_phq_8 + In_Control

    # latent regressions
    faith_gov ~ soc_pos
    distress ~ soc_pos
    {policy} ~ soc_pos + faith_gov + distress + Age

    # variances
    # faith_gov ~~ faith_gov 
    # distress ~~ distress 
    # soc_pos ~~ soc_pos

    # covariances
    faith_gov ~~ distress
    distress ~~ Age
    faith_gov ~~ Age
    soc_pos ~~ Age
'
    semPaths( 
        daniels_model_1_fit, 
        "std", 
        filetype="pdf",
        filename="tmp/img/daniels_model_1",
        layout="tree", 
        rotation=4,
        nodeLabels = daniels_model_1_graph_renames )


POLICY_LABELS = list(
    BI="Basic Income",
    Green_ND="Green New Deal",
    Utilities="Utilities",
    Health="health" ="Health",
    Childcare= "Childcare",
    Education = "Education",
    Housing = "Housing",
    Transport ="Transport",
    Democracy ="Democracy",
    Tax = "Taxation" )


# `dall` - dataset 
# `policy` - label of the policy in the dataset
# `pollabel` - same as a text string, for the graph
#
do_one_policy <- function( dall, policy, pollabel ){
    fname = glue::glue("tmp/sem-model-{policy}.txt")
    gfname = glue::glue("tmp/img/sem-model-{policy}")
    sink( fname ) 
    model_str = glue::glue( model_template )
    # these dump model as a string to the sink
    "Estimated Model Is"
    model_str
    model_fit <- sem( model_str, data=dall ) #, se='boot', bootstrap=1000 )
    summary( model_fit, standardized=T )
    daniels_model_1_graph_renames[11] = pollabel 
    semPaths( 
        model_fit, 
        "std", 
        filetype="pdf",
        filename=gfname,
        layout="tree", 
        rotation=4,
        nodeLabels = daniels_model_1_graph_renames )
    sink()
}

