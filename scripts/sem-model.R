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

ABBREVS <- c( 
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
        Green_ND="green_nd_pre", 
        Utilities="utilities_pre", 
        Health="health_pre", 
        Childcare="childcare_pre", 
        Education="education_pre", 
        Housing="housing_pre", 
        Transport="transport_pre", 
        Democracy="democracy_pre", 
        Tax="tax_pre",
        Overall="Support_All_Policies" )

# rename the boxes in the graphs to these
# MUST BE in this order. 
MODEL_GRAPH_RENAMES = c(
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
        "CHANGEME",
        "Age",
        "sqrt(GAD-7)",
        "sqrt(PHQ-8)",
        "Control of Life",
        "Faith In Govt",
        "Social Pos",
        "Distress")

MODEL_TEMPLATE <- '
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
 
POLICY_LABELS = list(
    BI="Basic Income",
    Green_ND="Green New Deal",
    Utilities="Utilities",
    Health ="Health",
    Childcare= "Childcare",
    Education = "Education",
    Housing = "Housing",
    Transport ="Transport",
    Democracy ="Democracy",
    Tax = "Taxation",
    Overall = "All Policies" )


# `dall` - dataset 
# `policy` - label of the policy in the dataset
# `pollabel` - same as a text string, for the graph
#
do_one_policy <- function( dall, policy, pollabel ){
    fname = glue::glue("tmp/sem-model-{policy}.txt")
    gfname = glue::glue("tmp/img/sem-model-{policy}")
    sink( fname ) 
    model_str = glue::glue( MODEL_TEMPLATE )
    # these dump model as a string to the sink
    "Estimated Model Is"
    model_str
    model_fit <- sem( model_str, data=dall ) #, se='boot', bootstrap=1000 )
    summary( model_fit, standardized=T )
    MODEL_GRAPH_RENAMES[11] = pollabel 
    semPaths( 
        model_fit, 
        "std", 
        filetype="pdf",
        filename=gfname,
        layout="tree", 
        rotation=4,
        nodeLabels = MODEL_GRAPH_RENAMES )
    sink()
}


dall4 <- read.delim("data/national-w-created-vars.tab") |> tibble()
# shorten names for SEM printouts
dall4 <- dall4 |> rename(all_of(ABBREVS))
glimpse(dall4)


for (l in names(POLICY_LABELS)){
    do_one_policy( dall4, l, POLICY_LABELS[l] )
}
