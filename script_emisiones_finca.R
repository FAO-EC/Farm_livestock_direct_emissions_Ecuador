## SCRIPT FOR EMISSIONS ESTIMATION
## FARM LEVEL
## GANADERIA CLIMATICAMENTE INTELIGENTE
## 2019
fdir<-"C:/dd/Google Drive/RNN_LU/BreedingSyst/gleam_ec/Farm_livestock_direct_emissions_Ecuador-master"
setwd(fdir)
## ARMANDO RIVERA
## armando.d.rivera@outlook.com

## BASED ON
## GLEAM 2.0 (FEB. 2017)
## http://www.fao.org/gleam/resources/es/

## The script automate the formulas from
## the GLEAM model for cattle production
##
## The results show:
## production estimation in liters and kg of meat
## Direct emissions:
## CH4 (methane) emissions from enteric fermentation
## CH4 emissions from manure management
## N2O (nitrous oxide) emissions from manure management
## N2O emissions from manure in pastures
## The emissions are converted to CO2-eq

## INITIALS
## AF = ADULT FEMALES (VACAS)
## AM = ADULT MALES (TOROS)
## YF = YOUNG FEMALES (VACONAS)
## YM = YOUNG MALES (TORETES)
## MF = MEAT FEMALES (HEMBRAS DE CARNE)
## MM = MEAT MALES (MACHOS DE CARNE)
## OT = OTHER CATEGORIES ANIMALS 
## (OTRAS CATEGORIAS DE ANIMALES 
## FUERA DE LAS VACAS)

## Input data is the total number in
## one calendar year selected for the
## evaluation
## In case of weights and ages, it is
## the average in the calendar year.

########################################
## LIBRARIES
########################################

library(xlsx) ## EXCEL FILES MANAGMENT
library(leaflet) ## INTERACTIVE MAPS
library(dplyr) ## MATRIX MANAGMENT
library(raster)## RASTER MANAGMENT
library(rgdal) ## GEODATA MANAGMENT

########################################
##FUNCTIONS
########################################

## -------------------------------------
## DATA CLASSIFICATION
## -------------------------------------
## Classify a value (VALUE_REC) into 3 
## categories (CLASS1, CLASS2 Y CLASS3).
## The limits for each category are 
## MIN1 and MIN2
##
## If VALUE_REC is less than MIN1 = CLASS1
## If VALUE_REC is between MIN1 and MIN2 =
## CLASS2
## If VALUE_REC is bigger than MIN1 = CLASS3

reclass = function(value_rec,min1,min2,
                   class1,class2,class3){
  if (min1 > value_rec){
    new_class = class1
  } else if (min1 <=  value_rec & min2 >= value_rec){
    new_class = class2
  } else if (min2 < temp_resample){
    new_class = class3
  }
  return(new_class)
}

## -------------------------------------
## EMISSIONS ESTIMATION
## -------------------------------------
## Compute emissions from cattle production
## based on the GLEAM model
##
## The results show:
## production estimation in liters and kg of meat
## Direct emissions:
## CH4 (methane) emissions from enteric fermentation
## CH4 emissions from manure management
## N2O (nitrous oxide) emissions from manure management
## N2O emissions from manure in pastures
## The emissions are converted to CO2-eq

farm_emissions = function(
  
  ## CSV FILES
  ## DIGESTIBILITY (PERCENTAGE)
  ## PROTEIN NITROGEN (gN/kg DRY MATTER)  
  ## MIN = MINIMUM (LITERATURE REVIEW)
  ## MAX = MAXIMUM (LITERATURE REVIEW)
  ## 
  ## IF LAB ANALYSIS IS USED, PUT THE
  ## SAME VALUE IN MAX AND MIN
  
  main_pasture_list, #csv main pasture
  mixture_pasture_list, #csv mixture pastures
  cut_pasture_list, #csv cut pastures
  diet_list, #csv diet supplements
  
  ## FARM DATA
  
  farm_name, #string  
  year, #string
  longitude, #float number
  latitude, #float number
  
  main_product, #string
  ## options: Leche, Carne
  ## Leche = milk, Carne = meat
  
  ## number in one year
  ## including death and sold animals
  adult_females, #integer number
  
  adult_females_milk, #integer number
  ## adult females producing milk
  
  young_females, #integer number
  female_calves, #integer number
  adult_males, #integer number
  young_males, #integer number
  male_calves, #integer number
  death_adult_females, #integer number
  death_female_calves, #integer number
  death_adult_males,  #integer number
  death_male_calves, #integer number
  slaughtered_adult_females, #integer number
  sold_adult_females, #integer number
  slaughtered_adult_males, #integer number
  sold_adult_males, #integer number
  
  total_births, #integer number
  age_first_calving_months, #float number
  
  ## average (kg)
  adult_females_weight, #float number
  female_calves_weight, #float number
  adult_males_weight, #float number
  male_calves_weight, #float number
  slaughtered_young_females_weight, #float number
  slaughtered_young_males_weight, #float number
  
  milk_fat, #float number (percentage)
  milk_protein, #float number (percentage)
  milk_yield_liters_animal_day, #float number
  lactancy_period_months, #float number
  
  pasture_area_ha, #float number (hectares)
  
  adult_females_feed_pasture_age,
  other_categories_feed_pasture_age,
  ## options: 1, 2, 3
  ## 1 = 0 - 25 days
  ## 2 = 25 - 60 days
  ## 3 = more than 60 days
  
  mixture_pasture_ha, #float number (hectares)
  
  ## daily kg of cut and carry pasture
  adult_females_feed_cut_pasture_kg, #float number (kg)
  other_categories_feed_cut_pasture_kg, #float number (kg)
  
  productive_system, #string
  ## options: MARGINAL, MERCANTIL, COMBINADO, EMPRESARIAL
  ## MARGINAL = no technology in the farm, the livestock
  ## production is for family consumption
  ## MERCANTIL = no technology in the farm, the livestock
  ## production generates incomes.
  ## COMBINADO = semi-technical farm}, the livestock 
  ## production generates income, labor is hired
  ## EMPRESARIAL = full technology in the farm, the livestock
  ## production goes to the industry or is exported
  ##
  ## MAGAP. (2008). Metodolog?a de Valoraci?n de 
  ## Tierras Rurales
  
  ## Manure managment
  ## percentage of the manure on each system
  ## Check GLEAM for a description of each system
  manure_in_pastures, #integer (percentage), no managment
  manure_daily_spread, #integer (percentage)
  manure_liquid_storage, #integer (percentage)
  manure_compost, #integer (percentage)
  manure_drylot, #integer (percentage)
  manure_solid, #integer (percentage)
  manure_anaerobic, #integer (percentage)
  manure_uncoveredlagoon, #integer (percentage)
  manure_burned #integer (percentage)
){
  
  ########################################
  ## GLEAM VARIABLES
  ########################################
  AFC = age_first_calving_months/12 # age first calving in years
  LACT_PER = lactancy_period_months*30.4 # lactancy period in days
  
  ## AFKG = adult female weight
  ## MFSKG = slaughtered young females weight
  ## -------------------------------------
  ## Restriction: If AFKG is less than MFSKG, then
  ## AFKG = slaughtered young females weight
  ## MFSKG = adult female weight
  ##
  ## It avoids that the weight of young females
  ## are bigger than adult females
  ## -------------------------------------
  AFKG<-MFSKG<-NA
  if( any(adult_females > 0 & young_females > 0 & 
      adult_females_weight < slaughtered_young_females_weight)){
    fltr<-adult_females > 0 & young_females > 0 & 
      adult_females_weight < slaughtered_young_females_weight
    AFKG[fltr] = slaughtered_young_females_weight[fltr] #live weight of slaughtered young females
    MFSKG[fltr] = adult_females_weight[fltr] #live weight of adult females
  } else{
    AFKG = adult_females_weight #live weight of adult females
    MFSKG = slaughtered_young_females_weight #live weight of slaughtered young females
  }
  
  ## AMKG = adult male weight
  ## MMSKG = slaughtered young males weight
  ## -------------------------------------
  ## Restriction: If AMKG is less than MMSKG, then
  ## AMKG = slaughtered young males weight
  ## MMSKG = adult male weight
  ##
  ## It avoids that the weight of young males
  ## are bigger than adult males
  ## -------------------------------------
  AMKG<-  MMSKG <- NA
  if ( any(adult_males > 0 & young_males > 0 & 
     adult_males_weight < slaughtered_young_males_weight) ) {
    fltr<-adult_males > 0 & young_males > 0 & 
           adult_males_weight < slaughtered_young_males_weight
    AMKG[fltr] = slaughtered_young_males_weight [fltr]
    MMSKG[fltr] = adult_males_weight[fltr]
  } else{
    AMKG = adult_males_weight
    MMSKG = slaughtered_young_males_weight
  }
  
  ## MILK FAT
  ## Default values per region in Ecuador
  ## AMAZONIA = 3.17
  ## COSTA = 3.98
  ## SIERRA = 3.72
  MILK_FAT = milk_fat
  
  ## MILK PROTEIN
  ## Default values per region in Ecuador
  ## AMAZONIA = 2.91
  ## COSTA = 3.42
  ## SIERRA = 3.01
  MILK_PROTEIN = milk_protein
  MILK_YIELD = milk_yield_liters_animal_day
  
  ##Manure managment
  MMSDRYLOT = manure_drylot
  MMSSOLID =  manure_solid
  MMSANAEROBIC = manure_anaerobic
  MMSUNCOVEREDLAGOON = manure_uncoveredlagoon
  MMSBURNED = manure_burned
  MMSCOMPOSTING = manure_compost 
  MMSDAILY = manure_daily_spread
  MMSLIQUID = manure_liquid_storage
  MMSPASTURE = manure_in_pastures
  
  ########################################
  ## HERD TRACK
  ########################################
  ## INITIALSL FROM GLEAM 2.0 (FEB. 2017)
  ## http://www.fao.org/gleam/resources/es/
  
  ## SEE PAGE 9 (GLEAM 2.0)
  AF = adult_females
  AM = adult_males
  YF = young_females
  YM = young_males
  
  ## SEE PAGE 12 (GLEAM 2.0)
  DR1F = ifelse(female_calves == 0, 0, death_female_calves/
                  (female_calves + death_female_calves)*100) # death rate female calves
  DR1M = ifelse(male_calves == 0, 0, death_male_calves/
                  (male_calves + death_male_calves)*100) # deatha rate male calves
  DR2 = ifelse(AF == 0 & AM==0, 0,(death_adult_females + death_adult_males)/
                 (AF + AM + death_adult_females + death_adult_males + 
                    slaughtered_adult_females + slaughtered_adult_males + 
                    sold_adult_females + sold_adult_males)*100) # death rate adults
  
  ## Calves weight correction
  ## SEE PAGE 12 (GLEAM 2.0)
  CKG<-NA
  if(any(female_calves_weight == 0 & male_calves_weight > 0)){
    <-any(female_calves_weight == 0 & male_calves_weight > 0)
    CKG = male_calves_weight
  }
  if(female_calves_weight > 0 & male_calves_weight == 0){
    CKG = female_calves_weight
  } 
  if(female_calves_weight > 0 & male_calves_weight > 0){
    CKG = (female_calves_weight + male_calves_weight)/2
  }
  if(female_calves_weight == 0 & male_calves_weight == 0){
    CKG = 0
  }
  
  ## Rates
  ## SEE PAGE 12 (GLEAM 2.0)
  FRRF = 95 # Rate of fertile replacement females, default value 95
  RRF = ifelse(AF == 0, 0, (YF - death_adult_females - slaughtered_adult_females)/
                 (AF + death_adult_females + slaughtered_adult_females + 
                    sold_adult_females) * 100) # Replacement rate adult females
  
  ## SEE PAGE 13 (GLEAM 2.0)
  ERF = ifelse(AF == 0, 0, (slaughtered_adult_females + sold_adult_females)/
                 (AF + death_adult_females + slaughtered_adult_females + 
                    sold_adult_females) * 100) # Exit rate adult females
  ERM = ifelse(AM == 0, 0, (slaughtered_adult_males + sold_adult_males)/
                 (AM + death_adult_males + slaughtered_adult_males + 
                    sold_adult_males) * 100) # Exit rate adult males
  
  ## Fertility rate
  ## For a dairy system, FR is associated to adult females milk
  ## For other systems, FR is associated to AF
  if(main_product == "Leche"){
    FR = ifelse(adult_females_milk == 0, 0, 
                ifelse(total_births > adult_females_milk, 100,
                       (total_births/adult_females_milk)*100))
  } else {
    FR = ifelse(AF == 0, 0, 
                ifelse(total_births > AF, 100,
                       (total_births/AF)*100))
  }
  
  ## DIET SUPPLIES TYPES
  ## -------------------------------------
  ##
  ## DIGESTIBILITY OF FOOD
  ## (PORCENTAJE)
  ##
  ## PROTEIN CONTENT
  ## (gN/kg Dry matter)  
  ## -------------------------------------
  ## SEE PAGE 52 (GLEAM 2.0)
  
  ## Digestible energy percentage
  if(productive_system=="MARGINAL"){
    DE_percentage = 45
  } else if(productive_system=="MERCANTIL"){
    DE_percentage = 50
  } else if(productive_system=="COMBINADO"){
    DE_percentage = 55
  } else if(productive_system=="EMPRESARIAL"){
    DE_percentage = 60
  }
  
  ## estimated dietary net energy
  if(productive_system=="MARGINAL"){
    grow_nema = 3.5
  } else if(productive_system=="MERCANTIL"){
    grow_nema = 4.5
  } else if(productive_system=="COMBINADO"){
    grow_nema = 5.5
  } else if(productive_system=="EMPRESARIAL"){
    grow_nema = 6.5
  }
  
  ## Estimation of dry matter intake for mature dairy cows
  if(main_product == "Leche"){
    DMI_AF = ((5.4*AFKG)/500)/((100-DE_percentage)/100)
  }
  
  ## Estimation of dry matter intake for growing and finishing cattle
  if(main_product == "Carne"){
    DMI_AF = AFKG^0.75*((0.0119*grow_nema^2+0.1938)/grow_nema)
  }
  
  ## Growing animals
  DMI_YF = MFSKG^0.75*((0.2444*grow_nema-0.0111*grow_nema^2-0.472)/grow_nema)
  DMI_YM = MMSKG^0.75*((0.2444*grow_nema-0.0111*grow_nema^2-0.472)/grow_nema)
  DMI_female_calves = female_calves_weight^0.75*((0.2444*grow_nema-0.0111*grow_nema^2-0.472)/grow_nema)
  DMI_male_calves = male_calves_weight^0.75*((0.2444*grow_nema-0.0111*grow_nema^2-0.472)/grow_nema)
  
  ## AM
  DMI_AM=AMKG^0.75*((0.0119*grow_nema^2+0.1938)/grow_nema)
  
  ## Avergae OT (OTHER CATEGORIES NO AF)
  DMI_OT = (DMI_female_calves+DMI_male_calves+DMI_YM+DMI_YF+DMI_AM)/5
  
  ## DRY MATTER DIET LIST
  diet_list$ms_AF = diet_list$adult_female_feed_kg*(diet_list$dry_matter_percentage/100)
  diet_list$ms_OT = diet_list$other_categories_feed_kg*(diet_list$dry_matter_percentage/100)
  
  ## DRY MATER PASTURES
  ## CUT AND TAKE PASTURES
  ms_cut_pasture_AF = adult_females_feed_cut_pasture_kg * 0.2316
  ms_cut_pasture_OT = other_categories_feed_cut_pasture_kg * 0.2316
  
  cut_pasture_list$cut_d = cut_pasture_list$digestibility_percentage_max
  cut_pasture_list$cut_n = cut_pasture_list$nitrogen_content_max
  
  ms_cut_pasture_d = mean(cut_pasture_list$cut_d)
  ms_cut_pasture_n = mean(cut_pasture_list$cut_n)
  
  diet_list = rbind(diet_list, c(NA,NA,ms_cut_pasture_d,ms_cut_pasture_n,0,0,0,ms_cut_pasture_AF,ms_cut_pasture_OT))
  
  ms_AF_total = sum(diet_list$ms_AF)
  ms_OT_total = sum(diet_list$ms_OT)

  DMI_AF_direct_pasture =  ifelse((DMI_AF - ms_AF_total)<=0,0,DMI_AF - ms_AF_total)
  DMI_OT_direct_pasture =  ifelse((DMI_OT - ms_OT_total)<=0,0,DMI_OT - ms_OT_total)
  
  ## MIXTURE PASTURE FEEDING
  mixture_pasture_percentage1 = ifelse(pasture_area_ha==0,0,mixture_pasture_ha/pasture_area_ha)
  mixture_pasture_percentage = ifelse(mixture_pasture_percentage1>1,1,mixture_pasture_percentage1)
  ms_mix_pasture_AF = DMI_AF_direct_pasture * mixture_pasture_percentage
  ms_mix_pasture_OT = DMI_OT_direct_pasture * mixture_pasture_percentage
  
  mixture_pasture_list$mix_d = mixture_pasture_list$digestibility_percentage_max
  mixture_pasture_list$mezcla_n = mixture_pasture_list$nitrogen_content_max
  
  ms_mix_pasture_d = mean(mixture_pasture_list$mix_d)
  ms_mix_pasture_n = mean(mixture_pasture_list$mezcla_n)
  
  diet_list = rbind(diet_list, c(NA,NA,ms_mix_pasture_d,ms_mix_pasture_n,0,0,0,ms_mix_pasture_AF,ms_mix_pasture_OT))
  
  
  ## DIRECT PASTURE FEEDING
  ms_direct_pasture_AF = ifelse((DMI_AF_direct_pasture - ms_mix_pasture_AF)<=0,0,DMI_AF_direct_pasture - ms_mix_pasture_AF)
  ms_direct_pasture_OT = ifelse((DMI_OT_direct_pasture - ms_mix_pasture_OT)<=0,0,DMI_OT_direct_pasture - ms_mix_pasture_OT)
  
  ms_direct_pasture_digestibility_percentage_max = mean(main_pasture_list$digestibility_percentage_max)
  ms_direct_pasture_digestibility_percentage_min = mean(main_pasture_list$digestibility_percentage_min)
  ms_direct_pasture_nitrogen_content_max = mean(main_pasture_list$nitrogen_content_max)
  ms_direct_pasture_nitrogen_content_min = mean(main_pasture_list$nitrogen_content_min)
  
  if(adult_females_feed_pasture_age == 1){
    ms_direct_pasture_AF_d = ms_direct_pasture_digestibility_percentage_max
    ms_direct_pasture_AF_n = ms_direct_pasture_nitrogen_content_max
  } else if(adult_females_feed_pasture_age == 2){
    ms_direct_pasture_AF_d = (ms_direct_pasture_digestibility_percentage_max + ms_direct_pasture_digestibility_percentage_min) / 2
    ms_direct_pasture_AF_n = (ms_direct_pasture_nitrogen_content_max + ms_direct_pasture_nitrogen_content_min) / 2
  } else if(adult_females_feed_pasture_age == 3){
    ms_direct_pasture_AF_d = ms_direct_pasture_digestibility_percentage_min
    ms_direct_pasture_AF_n = ms_direct_pasture_nitrogen_content_min
  }
  
  if(other_categories_feed_pasture_age == 1){
    ms_direct_pasture_OT_d = ms_direct_pasture_digestibility_percentage_max
    ms_direct_pasture_OT_n = ms_direct_pasture_nitrogen_content_max
  } else if(other_categories_feed_pasture_age == 2){
    ms_direct_pasture_OT_d = (ms_direct_pasture_digestibility_percentage_max + ms_direct_pasture_digestibility_percentage_min) / 2
    ms_direct_pasture_OT_n = (ms_direct_pasture_nitrogen_content_max + ms_direct_pasture_nitrogen_content_min) / 2
  } else if(other_categories_feed_pasture_age == 3){
    ms_direct_pasture_OT_d = ms_direct_pasture_digestibility_percentage_min
    ms_direct_pasture_OT_n = ms_direct_pasture_nitrogen_content_min
  }
  
  diet_list = rbind(diet_list, c(NA,NA,ms_direct_pasture_AF_d,ms_direct_pasture_AF_n,0,0,0,ms_direct_pasture_AF,0))
  diet_list = rbind(diet_list, c(NA,NA,ms_direct_pasture_OT_d,ms_direct_pasture_OT_n,0,0,0,0,ms_direct_pasture_OT))
  
  if(sum(diet_list$ms_AF)==0){
    diet_list$AF = 0
  } else (
    diet_list$AF = diet_list$ms_AF/sum(diet_list$ms_AF)*100
  )
  
  if(sum(diet_list$ms_OT)==0){
    diet_list$OT = 0
  } else (
    diet_list$OT = diet_list$ms_OT/sum(diet_list$ms_OT)*100
  )
  
  ## DIGESTIBILITY CALCULATION
  ## SEE PAGE 52 (GLEAM 2.0)
  diet_list$AFLCIDE = diet_list$AF*diet_list$digestibility_percentage
  diet_list$OTLCIDE = diet_list$OT*diet_list$digestibility_percentage
  diet_list$AFLCIN = diet_list$AF*diet_list$nitrogen_content
  diet_list$OTLCIN = diet_list$OT*diet_list$nitrogen_content
  
  
  ## FEED VARIABLES
  ## AVERAGE DIGESTIBILITY OF THE AF DIET
  ## (DIETDI)
  AFLCIDE = ifelse(sum(diet_list$AFLCIDE)==0,1,sum(diet_list$AFLCIDE)/100)
  
  ## AVERAGE DIGESTIBILITY OF THE OT DIET
  ## (DIETDI)
  OTLCIDE = ifelse(sum(diet_list$OTLCIDE)==0,1,sum(diet_list$OTLCIDE)/100)
  
  ## AVERAGE NITROGEN OF THE AF DIET
  ## (DIETNCONTENT)  
  AFLCIN = ifelse(sum(diet_list$AFLCIN)==0,1,sum(diet_list$AFLCIN)/100)
  
  ## AVERAGE NITROGEN OF THE OT DIET
  ##(DIETNCONTENT)  
  OTLCIN = ifelse(sum(diet_list$OTLCIN)==0,1,sum(diet_list$OTLCIN)/100)
  
  
  ## -------------------------------------
  ## HERD CALCULATIONS
  ## -------------------------------------
  ##
  ## 2.1.2.1 FEMALE SECTION
  ## SEE PAGE 13 (GLEAM 2.0)
  AFIN = (RRF/ 100) * AF
  AFX = AF * (DR2 / 100)
  AFEXIT = AF * (ERF / 100)
  CFIN = AF * ((1 - (DR2 / 100)) * (FR / 100) + (RRF / 100)) * 0.5 * (1 - (DR1F / 100))
  RFIN = (AFIN / (FRRF/100)) / ((1 - (DR2 / 100))^AFC)
  MFIN = CFIN - RFIN
  RFIN = ifelse((MFIN < 0),RFIN+MFIN,RFIN)
  MFIN = ifelse((MFIN < 0),0,MFIN)
  RFEXIT = (((RRF / 100) * AF) / (FRRF/100)) - AFIN
  RF = (RFIN + AFIN) / 2
  ASF = ifelse(AFC == 0, 0, (MFSKG - CKG) / (AFKG - CKG) * AFC)
  ASF1 = ifelse(ASF <= 0, 0, ASF) #####AUMENTAR2020
  MFEXIT = MFIN * ((1 - (DR2 / 100))^ASF1) #####AUMENTAR2020
  MF = (MFIN + MFEXIT) / 2
  
  ## 2.1.2.2 MALE SECTION
  ## SEE PAGE 14 (GLEAM 2.0)
  AMX = AM * (DR2 / 100)
  RRM = ifelse(AFC == 0, 0, 1 / AFC)
  AMEXIT = AF * (ERM / 100) ##AMEXIT = (AM * RRM) - AMX ###AGREGAR
  CMIN = AF * ((1 - (DR2 / 100)) * (FR / 100) + (RRF / 100)) * 0.5 * (1 - (DR1M / 100))
  AMIN = ifelse(AFC == 0, 0, AM / AFC)
  RMIN = AMIN / ((1 - (DR2 / 100))^AFC)
  MMIN = CMIN - RMIN
  RMIN = ifelse((MMIN < 0),RMIN+MMIN,RMIN)
  MMIN = ifelse((MMIN < 0),0,MMIN)
  RM = ((RMIN + AMIN) / 2)
  ASM = ifelse(AFC == 0, 0, (MMSKG - CKG) / (AMKG - CKG) * AFC)
  ASM1 = ifelse(ASM <= 0, 0, ASM) #####AUMENTAR2020
  MMEXIT = MMIN * ((1 - (DR2 / 100))^ASM1)#####AUMENTAR2020
  MM = (MMIN + MMEXIT) / 2
  
  MILK_YIELD_KG = MILK_YIELD*1.032
  
  ## 2.1.2.5 WEIGHT SECTION
  ## SEE PAGE 16 (GLEAM 2.0)
  MFKG = ifelse(MFSKG == 0, 0,(MFSKG - CKG) / 2 + CKG) 
  MMKG = ifelse(MMSKG == 0, 0,(MMSKG - CKG) / 2 + CKG)
  RFKG = ifelse(AFKG == 0, 0,(AFKG - CKG) / 2 + CKG) 
  RMKG = ifelse(AMKG == 0, 0,(AMKG - CKG) / 2 + CKG) 
  GROWF = ifelse(AFC == 0, 0, (AFKG - CKG) / (AFC * 365))
  GROWM = ifelse(AFC == 0, 0, (AMKG - CKG) / (AFC * 365))
  GROWF = ifelse(GROWF < 0, 0, GROWF)
  GROWM = ifelse(GROWM < 0, 0, GROWM)
  
  ## -------------------------------------
  ## HERD PROJECTION
  ## -------------------------------------
  
  ## NEGATIVE VALUES CORRECTION
  RF = ifelse(RF<0, 0, RF)
  RM = ifelse(RM<0, 0, RM)
  MF = ifelse(MF<0, 0, MF)
  MM = ifelse(MM<0, 0, MM)
  
  ## ANIMAL DISTRIBUTION ACCORDING REPORTED
  ## WEIGHT
  ## -------------------------------------
  ## THE PREVIOS CALCULATIONS MAKE A HERD
  ## PROJECTION. 
  ## FOR THE CORRECTION 
  ## IT IS ASSUMED THAT AN AFKG (AF WEIGHT)
  ## EQUAL TO ZERO, IMPLIES THAT THERE IS NO
  ## AF IN THE HERD AND NO REPLACEMENT 
  ## ANIMALS. THEN, THE VALUE OF MF 
  ## (MEAT FEMALE) AND RF (REEPLACEMENT FEMALES)
  ## ARE ASSIGNED TO MF
  ##
  ## IT IS ASSUMED THAT AN MFSKG (MEAT FEMALE
  ## WEIGHT) EQUAL TO ZERO, IMPLIES THAT
  ## THERE ARE NO MEAT ANIMALS. THEN THE VALUE
  ## OF MF (MEAT FEMALES) AND RF (REEPLACEMENT FEMALES)
  ## ARE ASSIGNED TO RF
  ## -------------------------------------
  if(AFKG == 0 & MFSKG > 0){
    MF = MF + RF
    RF = 0
  } 
  if (AFKG > 0 & MFSKG == 0){
    RF = RF + MF
    MF = 0
  }
  if(AFKG == 0 & MFSKG == 0){
    MF = 0
    RF = 0
  }
  if (AMKG == 0 & MMSKG > 0){
    MM = MM + RM
    RM = 0
  }
  if (AMKG > 0 & MMSKG == 0){
    RM = RM + MM
    MM = 0
  }
  if (AMKG == 0 & MMSKG == 0){
    RM = 0
    MM = 0
  } 
  
  ## CORRECTION WITH THE REAL NUMBER OF
  ## YOUNG ANIMALS REPORTED
  ## -------------------------------------
  ## THE INPUT DATA INCLUDE VALUES OF 
  ## YOUNG FEMALES (YF) AND YOUNG MALES
  ## (YM). THE DISTRIBUTION OF RF, RM, 
  ## MF, MM IS ASSIGNED TO THE SUM OF YF
  ## AND YM. 
  ## THIS CALCULATION DETERMINES HOW MANY
  ## ANIMALS BELONG TO EACH CATEGORY
  ## OF THE YOUNG ANIMALS IN THE FARM.
  ## -------------------------------------
  DAIRY = RF + RM + MF + MM
  if(DAIRY == 0){
    MF = YF
    MM = YM
    
    ## MEAT ANIMALS EXIT
    ## SEE PAGE 14 (GLEAM 2.0)
    MFEXIT1 = MF * ((1 - (DR2 / 100))^ASF)
    MMEXIT1 = MM * ((1 - (DR2 / 100))^ASF)
  } else {
    MF = ifelse((RF+MF)==0, 0, MF * (YF+YM) / (DAIRY))
    RF = ifelse((RF+MF)==0, 0, RF * (YF+YM) / (DAIRY))
    MM = ifelse((RM+MM) ==0, 0, MM * (YF+YM) / (DAIRY))
    RM = ifelse((RM+MM)==0, 0, RM * (YF+YM) / (DAIRY))
    
    MFEXIT1 = ifelse((RF+MF)==0, 0, MFEXIT * (YF+YM) / (RM+MM+RF+MF))
    MMEXIT1 = ifelse((RM+MM)==0, 0, MMEXIT * (YF+YM) / (RM+MM+RF+MF))
  }
  
  ## REEPLACEMENT ANIMALS EXIT FOR MEAT
  ## SEE PAGE 14 (GLEAM 2.0)
  RFEXIT1 = ifelse((RF+MF)==0, 0, RFEXIT * (YF+YM) / (RM+MM+RF+MF))
  
  ## ADULT ANIMALS EXIT FOR MEAT
  AFEXIT1 = AFEXIT
  AMEXIT1 = AMEXIT
  
  
  ## 9.1.1 MILK PRODUCTIONE
  ## LITERS
  ## SEE PAGE 99 (GLEAM 2.0)
  Milk_production = MILK_YIELD * LACT_PER * AF
  
  ## 9.1.2 MEAT PRODUCTION
  ## KG CARCASS
  ## SEE PAGE 99 (GLEAM 2.0)
  
  ## MEAT OF GROWING FEMALE ANIMALS
  AFEXITKG = ifelse(AFEXIT1 <= 0, 0, (AFEXIT1 * AFKG))
  RFEXITKG = ifelse(RFEXIT1 <= 0, 0, (RFEXIT1 * RFKG))
  Meat_production_FF = (AFEXITKG + RFEXITKG)*0.5 ##50% PESO A LA CANAL
  
  ##MEAT OF GROWING MALE ANIMALS
  Meat_production_FM = ifelse(AMEXIT1 <= 0, 0, (AMEXIT1 * AMKG)*0.5 ) ##50% PESO A LA CANAL
  
  ##MEAT OF SLAUGHTERED YOUNG ANIMALS
  MFEXITKG = ifelse(MFEXIT1 <= 0, 0, (MFEXIT1 * MFKG))
  MMEXITKG = ifelse(MMEXIT1 <= 0, 0, (MMEXIT1 * MMKG))
  Meat_production_M = (MFEXITKG + MMEXITKG)*0.5 ##50% PESO A LA CANAL
  
  
  ########################################
  ## SYSTEM TRACK
  ########################################
  
  ## INITIALS
  ## AF = ADULT FEMALES (VACAS)
  ## AFN = ADULT FEMALES NO MILK (VACAS
  ## SECAS)
  ## AFM = ADULT FEMALES MILK (VACAS 
  ## EN PRODUCCION)
  ## AM = ADULT MALES (TOROS)
  ## YF = YOUNG FEMALES (VACONAS)
  ## YM = YOUNG MALES (TORETES)
  ## MF = MEAT FEMALES (HEMBRAS DE CARNE)
  ## MM = MEAT MALES (MACHOS DE CARNE)
  ## OT = OTHER ANIMALS (OTRAS CATEGORIAS
  ## DE ANIMALES FUERA DE LAS VACAS)
  
  kg_variables = c("AF","AM","RF","RM","MM","MF")
  for(tipo in kg_variables){
    
    ##-------------------------------------
    ## ENERGY
    ##-------------------------------------
    
    ## 3.5.1.1 MAINTENANCE
    ## SEE PAGE 54 (GLEAM 2.0)
    
    # INPUT
    CfL = 0.386
    CfN = 0.322
    CfB = 0.370
    
    # CALCULATION
    if (tipo == "AF"){
      Cf = CfL
      KG = AFKG
    }
    if (tipo == "AM"){
      Cf = CfB
      KG = AMKG
    }
    if (tipo == "MM"){
      Cf = CfB
      KG = MMKG
    }
    if (tipo == "RM"){
      Cf = CfB * 0.974
      KG = RMKG
    }
    if (tipo == "MF"){
      Cf = CfN
      KG = MFKG
    }
    if (tipo == "RF"){
      Cf = CfN * 0.974
      KG = RFKG
    }
    tipo_result = (KG ^ 0.75)*Cf
    # OUTPUT
    assign(paste(tipo,"NEMAIN", sep = ""), tipo_result)
    
    
    ## 3.5.1.7 PREGNANCY
    ## SEE PAGE 57 (GLEAM 2.0)
    if (tipo == "AF" | tipo == "RF"){
      
      # INPUT
      Cp = 0.1
      
      # CALCULATION
      if (tipo == "AF"){
        outNEMAIN = AFNEMAIN
        NEPREG = outNEMAIN * Cp * FR / 100.0
      }
      if (tipo == "RF"){
        outNEMAIN = RFNEMAIN
        NEPREG = outNEMAIN * Cp* AFC / 2
      }
      # OUTPUT
      assign(paste(tipo,"NEPREG", sep = ""), NEPREG)
    }
    
    ## 3.5.1.3 GROWTH
    ## SEE PAGE 55 (GLEAM 2.0)
    if (tipo == "RF" | tipo == "RM" | tipo == "MF" | tipo == "MM"){
      
      # INPUT
      CgF = 0.8
      CgM = 1.2
      CgC = 1.0 #for castrated animals
      
      # CALCULATION
      if (tipo == "RF"){
        KG = RFKG
        NEGRO = ifelse((CgF * AFKG)==0, 0, 22.02 * ((KG / (CgF * AFKG)) ^ 0.75) * (GROWF ^ 1.097)) ###### AUMENTAR
      }
      if (tipo == "MF"){
        KG = MFKG
        NEGRO = ifelse((CgF * AFKG)==0, 0, 22.02 * ((KG / (CgF * AFKG)) ^ 0.75) * (GROWF ^ 1.097)) ###### AUMENTAR
      }
      if (tipo == "RM"){
        KG = RMKG
        NEGRO = ifelse((CgF * AMKG)==0, 0, 22.02 * ((KG / (CgM * AMKG)) ^ 0.75) * (GROWM ^ 1.097)) ###### AUMENTAR
      }
      if (tipo == "MM"){
        KG = MMKG
        NEGRO = ifelse((CgF * AMKG)==0, 0, 22.02 * ((KG / (CgC * AMKG)) ^ 0.75) * (GROWM ^ 1.097)) ###### AUMENTAR
      }
      
      # OUTPUT
      assign(paste(tipo,"NEGRO", sep = ""), NEGRO)
    }
    
    ## 3.5.1.4 MILK PRODUCTION
    ## SEE PAGE 56 (GLEAM 2.0)
    if (tipo == "AF"){
      
      # CALCULATION
      NEMILK = MILK_YIELD_KG * (MILK_FAT * 0.40 + 1.47)
      
      # OUTPUT
      assign(paste(tipo,"NEMILK", sep = ""), NEMILK)
    }
    
    ## 3.5.1.2 ACTIVITY (GRAZING) RANGE = 1; GRAZE = 2
    ## SEE PAGE 55 (GLEAM 2.0)
    
    # INPUT
    MMSpast = MMSPASTURE
    
    # CALCULATIONS
    NEACT = tipo_result * (MMSpast * 0.36 / 100.0)
    
    # OUTPUT
    assign(paste(tipo,"NEACT", sep = ""), NEACT)
    
    ## 3.5.1.10 TOTAL ENERGY
    ## SEE PAGE 58 (GLEAM 2.0)
    
    # INPUT GRID
    # MAKES THE CALCULATIONS
    if (tipo == "AF"){
      NETOT1 = AFNEMAIN + AFNEACT + AFNEPREG + AFNEMILK
      NETOT2 = AFNEMAIN + AFNEACT + AFNEPREG
      
      # OUTPUT GRID
      assign(paste(tipo,"MNETOT1", sep = ""), NETOT1)
      assign(paste(tipo,"NNETOT1", sep = ""), NETOT2)
    }
    if (tipo == "RF"){
      NETOT1 = RFNEMAIN + RFNEACT + RFNEPREG
      
      # OUTPUT GRID
      assign(paste(tipo,"NETOT1", sep = ""), NETOT1)
    }
    if (tipo == "AM"){
      NETOT1 = AMNEMAIN + AMNEACT
      
      # OUTPUT GRID
      assign(paste(tipo,"NETOT1", sep = ""), NETOT1)
    }
    if (tipo == "RM"){
      NETOT1 = RMNEMAIN + RMNEACT
      
      # OUTPUT GRID
      assign(paste(tipo,"NETOT1", sep = ""), NETOT1)
    }
    if (tipo == "MM"){
      NETOT1 = MMNEMAIN + MMNEACT
      
      # OUTPUT GRID
      assign(paste(tipo,"NETOT1", sep = ""), NETOT1)
    }
    if (tipo == "MF"){
      NETOT1 = MFNEMAIN + MFNEACT
      # OUTPUT GRID
      assign(paste(tipo,"NETOT1", sep = ""), NETOT1)
    }
  }
  
  ## 3.5.1.8 ENERGY RATIO FOR:
  ## MAINTENANCE (REM)
  ## GROWTH (REG)
  ## SEE PAGE 57 (GLEAM 2.0)
  
  # INPUT
  for (group in c("AF","OT")){
    if (group == "AF"){
      LCIDE = AFLCIDE
      n = 1
    }
    if (group == "OT"){
      LCIDE = OTLCIDE
      n = 2
    }
    
    # CALCULATIONS
    tmpREG = 1.164 - (0.00516 * LCIDE) + (0.00001308 * LCIDE * LCIDE) - (37.4 / LCIDE)
    tmpREM = 1.123 - (0.004092 * LCIDE) + (0.00001126 * LCIDE * LCIDE) - (25.4 / LCIDE)
    
    # OUTPUT
    assign(paste("REG",n, sep = ""), tmpREG)
    assign(paste("REM",n, sep = ""), tmpREM)
  }
  
  ## 3.5.1.10 TOTAL ENERGY
  ## SEE PAGE 58 (GLEAM 2.0)
  
  # INPUT
  LCIDE1 = AFLCIDE
  LCIDE2 = OTLCIDE
  
  # CALCULATIONS & OUTPUT
  AFMGE = (AFMNETOT1 / REM1) / (LCIDE1 / 100.0)
  AFNGE = (AFNNETOT1 / REM1) / (LCIDE1 / 100.0)
  RFGE = ((RFNETOT1 / REM2) + (RFNEGRO / REG2)) / (LCIDE2 / 100.0)
  AMGE = (AMNETOT1 / REM2) / (LCIDE2 / 100.0)
  RMGE = ((RMNETOT1 / REM2) + (RMNEGRO / REG2)) / (LCIDE2 / 100.0)
  MMGE = ((MMNETOT1 / REM2) + (MMNEGRO / REG2)) / (LCIDE2 / 100.0)
  MFGE = ((MFNETOT1 / REM2) + (MFNEGRO / REG2)) / (LCIDE2 / 100.0)
  
  ## FEED
  ## SEE PAGE 68 (GLEAM 2.0)
  
  LCIGE = 18.45
  AFMINTAKE = AFMGE / LCIGE
  AFNINTAKE = AFNGE / LCIGE
  RFINTAKE = RFGE / LCIGE
  AMINTAKE = AMGE / LCIGE
  RMINTAKE = RMGE / LCIGE
  MMINTAKE = MMGE / LCIGE
  MFINTAKE = MFGE / LCIGE
  
  ##-------------------------------------
  ## METHANE CH4 EMISSIONS
  ##-------------------------------------
  ## NUM = ANIMALS NUMBER
  ## 34 CONVERSION FACTOR CH4 TO CO2EQ
  ## SEE PAGE 100 (GLEAM 2.0)
  
  ## 4.2 FROM ENTERIC FERMENTATION
  ## SEE PAGE 67 (GLEAM 2.0)
  
  for (group in c("AF","OT")){
    if (group == "AF"){
      LCIDE = AFLCIDE
      n = 1
    }
    if (group == "OT"){
      LCIDE = OTLCIDE
      n = 2
    }
    
    # CALCULATION
    Ym = 9.75 - (LCIDE * 0.05)
    
    # OUTPUT
    assign(paste("YM",n, sep = ""), Ym)
  }
  
  for (tipo in c("AFN","AFM","AM","RF","RM","MM", "MF")){
    
    ## 4.3 FROM MANURE MANAGMENT
    ## SEE PAGE 67 (GLEAM 2.0)
    
    # CALCULATIONS
    if (tipo == "AFM"){
      LCIDE = AFLCIDE
      GE = AFMGE
      anim_num = AF
      Ym = YM1
    }
    if (tipo == "AFN"){
      LCIDE = AFLCIDE
      GE = AFNGE
      anim_num = AF
      Ym = YM1
    }
    if (tipo == "AM"){
      LCIDE = OTLCIDE
      GE = AMGE
      anim_num = AM
      Ym = YM2
    }
    if (tipo == "RF"){
      LCIDE = OTLCIDE
      GE = RFGE
      anim_num = RF
      Ym = YM2
    }
    if (tipo == "RM"){
      LCIDE = OTLCIDE
      GE = RMGE
      anim_num = RM
      Ym = YM2
    }
    if (tipo == "MM"){
      LCIDE = OTLCIDE
      GE = MMGE
      anim_num = MM
      Ym = YM2
    }
    if (tipo == "MF"){
      LCIDE = OTLCIDE
      GE = MFGE
      anim_num = MF
      Ym = YM2
    }
    
    # CALCULATIONS
    CH41 = (GE * Ym / 100) / 55.65
    VS = GE * (1.04 - (LCIDE / 100)) * (0.92 / LCIGE)
    
    # OUTPUT
    assign(paste(tipo, "CH41", sep = ""), CH41)
    assign(paste(tipo, "VS", sep = ""), VS)
    
    # INPUT
    temp = raster("data/temp.tif")
    temp_resample = as.numeric(extract(temp, matrix(c(longitude,latitude), ncol = 2)))
    temp_cutoff = raster("data/temp_cutoff.tif")
    temp_cutoff_resample = as.numeric(extract(temp_cutoff, matrix(c(longitude,latitude), ncol = 2)))
   
     # CALCULATIONS
    MCFSOLID = reclass(temp_resample,14,26,2,4,5)
    MCFCOMPOSTING = reclass(temp_resample,14,26,0.5,1,1.5)
    MCFANAEROBIC = 10.0
    MCFDAILY = reclass(temp_resample,14,26,0.1,0.5,1)
    MCFUNCOVEREDLAGOON = 44.953 + 2.6993 * temp_cutoff_resample - 0.0527 * temp_cutoff_resample * temp_cutoff_resample
    MCFLIQUID = 19.494 - 1.5573 * temp_cutoff_resample + 0.1351 * temp_cutoff_resample * temp_cutoff_resample
    MCFBURNED = 10.0
    MCFPASTURE = reclass(temp_resample,14,26,1,1.5,2)
    MCFDRYLOT <- reclass(temp_resample,14,26,1,1.5,2)
    
    # CREATES THE MCFMANURE RASTER
    # INPUT
    # CALCULATIONS
    MCFMANURE = MMSANAEROBIC * MCFANAEROBIC + MMSBURNED * MCFBURNED + MMSCOMPOSTING * MCFCOMPOSTING + MMSDAILY * MCFDAILY + MMSLIQUID * MCFLIQUID + MMSPASTURE * MCFPASTURE + MMSSOLID * MCFSOLID + MMSUNCOVEREDLAGOON * MCFUNCOVEREDLAGOON + manure_drylot * MCFDRYLOT
  }
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    
    # CALCULATIONS
    if (var == "AFM"){
      CH41 = AFMCH41
      VS = AFMVS
      anim_num = AF
      totCH41 = LACT_PER * CH41 * anim_num * 34
      CH42 = 0.67 * 0.0001 * 0.13 * MCFMANURE * VS
      totCH42 = LACT_PER * CH42 * anim_num * 34
    }
    else if (var == "AFN"){
      CH41 = AFNCH41
      VS = AFNVS
      anim_num = AF
      totCH41 = (365.0 - LACT_PER) * CH41 * anim_num * 34
      CH42 = 0.67 * 0.0001 * 0.13 * MCFMANURE * VS
      totCH42 = (365.0 - LACT_PER) * CH42 * anim_num * 34
    }
    else {
      if (var == "AM"){
        CH41 = AMCH41
        VS = AMVS
        anim_num = AM
      } else if (var == "RF"){
        CH41 = RFCH41
        VS = RFVS
        anim_num = RF
      } else if (var == "RM"){
        CH41 = RMCH41
        VS = RMVS
        anim_num = RM
      } else if (var == "MM"){
        CH41 = MMCH41
        VS = MMVS
        anim_num = MM
      } else if (var == "MF"){
        CH41 = MFCH41
        VS = MFVS
        anim_num = MF
      }
      totCH41 = 365.0 * CH41 * anim_num * 34
      CH42 = 0.67 * 0.0001 * 0.13 * MCFMANURE * VS
      totCH42 = 365.0 * CH42 * anim_num * 34
    }
    
    # OUTPUT
    assign(paste("CH41CO2TOT", var, sep = ""), totCH41)
    assign(paste("CH42CO2TOT", var, sep = ""), totCH42)
  }
  
  ##-------------------------------------
  ## NITROUS OXIDE N20 EMISSIONS
  ##-------------------------------------
  ## NUM = ANIMALS NUMBER
  ## 298 CONVERSION FACTOR N2O TO CO2EQ
  ## SEE PAGE 100 (GLEAM 2.0)
  
  ## 4.4 FROM MANURE MANAGMENT
  ## SEE PAGE 69 (GLEAM 2.0)
  
  ## 4.4.1 NITROGEN EXCRETION RATE
  ## SEE PAGE 69 (GLEAM 2.0)
  
  ## STEP 1 INTAKE CALCULATION
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    # INPUT
    if (var == "AFM" | var == "AFN"){
      if (var == "AFM"){
        inTAKE = AFMINTAKE
      } else if (var == "AFN"){
        inTAKE = AFNINTAKE
      }
      LCIN = AFLCIN
    }
    else {
      if (var == "AM"){
        inTAKE = AMINTAKE
      } else if (var == "RF"){
        inTAKE = RFINTAKE
      }  else if (var == "RM"){
        inTAKE = RMINTAKE
      }  else if (var == "MM"){
        inTAKE = MMINTAKE
      }  else if (var == "MF"){
        inTAKE = MFINTAKE
      }
      LCIN = OTLCIN
    }
    
    # CALCULATION
    NINTAKE = (LCIN / 1000) * inTAKE
    
    # OUTPUT
    assign(paste(var, "NINTAKE", sep = ""), NINTAKE)
  }
  
  ## STEP 2 RETENTION CALCULATION
  
  # CALCULATION
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    if (var == "AFM"){
      NRETENTION = ifelse(GROWF==0, 0, (MILK_YIELD_KG * (MILK_PROTEIN/100)/6.38)+(CKG/365 * (268-(7.03 * RFNEGRO/GROWF))*0.001/6.25)) ######ADICIONAR
    }
    else if (var == "AM" | var == "AFN"){
      NRETENTION = 0
    }
    else if (var == "RF"){
      NRETENTION = ifelse(GROWF==0, 0,(GROWF * (268 - (7.03 * RFNEGRO/GROWF)) * 0.001/6.25) + (CKG/365 * (268-(7.03 * RFNEGRO/GROWF))*0.001/6.25) / AFC) ######ADICIONAR
    }
    else if (var == "MF"){
      NRETENTION = ifelse(GROWF==0, 0,(GROWF * (268 - (7.03 * MFNEGRO/GROWF)) * 0.001/6.25)) ######ADICIONAR
    }
    else {
      NRETENTION = ifelse(GROWM==0, 0,(GROWM * (268 - (7.03 * RMNEGRO/GROWM)) * 0.001/6.25)) ######ADICIONAR
    }
    # OUTPUT
    assign(paste(var, "NRETENTION", sep = ""), NRETENTION)
  }
  
  ## STEP 3 N EXCRETION
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    
    # CALCULATIONS
    if (var == "AFN"){
      Nintake = AFNNINTAKE
      Nretention = AFNNRETENTION
      Nx = (365.0 - LACT_PER) * (Nintake - Nretention)
    }
    else if (var == "AFM"){
      Nintake = AFMNINTAKE
      Nretention = AFMNRETENTION
      Nx = (LACT_PER) * (Nintake - Nretention)
    }
    else{
      if (var == "AM"){
        Nintake = AMNINTAKE
        Nretention = AMNRETENTION
      } else if (var == "RF"){
        Nintake = RFNINTAKE
        Nretention = RFNRETENTION
      } else if (var == "RM"){
        Nintake = RMNINTAKE
        Nretention = RMNRETENTION
      } else if (var == "MM"){
        Nintake = MMNINTAKE
        Nretention = MMNRETENTION
      } else if (var == "MF"){
        Nintake = MFNINTAKE
        Nretention = MFNRETENTION
      }
      Nx = 365.0 * (Nintake - Nretention)
    }
    
    # OUTPUT
    assign(paste(var, "NX", sep = ""), Nx)
    
    ## 4.4.2 N2O DIRECT EMISSIONS FROM 
    ## MANURE MANAGMENT
    ## SEE PAGE 70 (GLEAM 2.0)
    
    # INPUT
    N2Olagoon = 0
    N2Oliquid = 0.005
    N2Osolid = 0.005
    N2Odrylot = 0.02
    N2Opasture = 0
    N2Odaily = 0
    N2Oburned = 0.02
    N2Oanaerobic = 0
    N2Ocomposting = 0.1
    
    if (var == "AFM" | var == "AFN"){
      LCIDE = AFLCIDE
    }
    else {
      LCIDE = OTLCIDE
    }
    
    # CALCULATIONS
    N2OCFmanure = MMSANAEROBIC * N2Oanaerobic + MMSBURNED * N2Oburned * (100.0 - LCIDE) / 100 + 
      MMSCOMPOSTING * N2Ocomposting + MMSDAILY *  N2Odaily + MMSLIQUID * N2Oliquid + 
      MMSPASTURE * N2Opasture + MMSSOLID * N2Osolid + MMSUNCOVEREDLAGOON * N2Olagoon + manure_drylot * N2Odrylot 
   
    # OUTPUT
    assign(paste("N2OCFMAN", var, sep = ""), N2OCFmanure)
  }
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    # INPUT
    if (var == "AFM"){
      Nx = AFMNX
      N2OCFmanure = N2OCFMANAFM
    } else if (var == "AFN"){
      Nx = AFNNX
      N2OCFmanure = N2OCFMANAFN
    } else if (var == "AM"){
      Nx = AMNX
      N2OCFmanure = N2OCFMANAM
    } else if (var == "RF"){
      Nx = RFNX
      N2OCFmanure = N2OCFMANRF
    } else if (var == "RM"){
      Nx = RMNX
      N2OCFmanure = N2OCFMANRM
    } else if (var == "MM"){
      Nx = MMNX
      N2OCFmanure = N2OCFMANMM
    } else if (var == "MF"){
      Nx = MFNX
      N2OCFmanure = N2OCFMANMF
    }
    
    # CALCULATIONS
    NOdir = N2OCFmanure * Nx * 44 / 2800
    
    # OUTPUT
    assign(paste(var, "NODIR", sep = ""), NOdir)
  }
  
  ## 4.4.4 INDIRECT N2O EMISSIONS FROM
  ## VOLATILIZATION
  ## SEE PAGE 71 (GLEAM 2.0)
  
  # INPUT
  VOLliquid = 40
  VOLsolid = 30
  VOLpasture = 0
  VOLdaily = 7
  VOLlagoon = 35
  VOLanaerobic = 0
  VOLcomposting = 40
  VOLdrylot = 20
  
  # CALCULATIONS & OUTPUT
  CFVOLMANURE = MMSLIQUID * VOLliquid + MMSSOLID * VOLsolid + MMSPASTURE * VOLpasture + MMSDAILY * VOLdaily + 
    MMSUNCOVEREDLAGOON * VOLlagoon + MMSANAEROBIC * VOLanaerobic + MMSCOMPOSTING * VOLcomposting + manure_drylot * VOLdrylot
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    
    # INPUT
    if (var == "AFM"){
      Nx = AFMNX
    } else if (var == "AFN"){
      Nx = AFNNX
    } else if (var == "AM"){
      Nx = AMNX
    } else if (var == "RF"){
      Nx = RFNX
    } else if (var == "RM"){
      Nx = RMNX
    } else if (var == "MM"){
      Nx = MMNX
    } else if (var == "MF"){
      Nx = MFNX
    }
    
    # CALCULATIONS
    MVOL = CFVOLMANURE / 10000 * Nx
    NOVOL = MVOL * 0.01 * 44 / 28
    
    # OUTPUT
    assign(paste(var, "NOVOL", sep = ""), NOVOL)
  }
  
  ## 4.4.4 INDIRECT N2O EMISSION FROM 
  ## LEACHING
  ## SEE PAGE 71 (GLEAM 2.0)
  
  # INPUT
  LEACHliquid_total = raster("data/leachliquid.tif")
  LEACHliquid = as.numeric(extract(LEACHliquid_total, matrix(c(longitude,latitude), ncol = 2)))
  LEACHsolid_total = raster("data/leachsolid.tif")
  LEACHsolid = as.numeric(extract(LEACHsolid_total, matrix(c(longitude,latitude), ncol = 2)))
  
  # CALCULATIONS
  CFLEACHMANURE = MMSLIQUID * LEACHliquid + MMSSOLID * LEACHsolid
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    
    # INPUT
    if (var == "AFM"){
      Nx = AFMNX
    } else if (var == "AFN"){
      Nx = AFNNX
    } else if (var == "AM"){
      Nx = AMNX
    } else if (var == "RF"){
      Nx = RFNX
    } else if (var == "RM"){
      Nx = RMNX
    } else if (var == "MM"){
      Nx = MMNX
    } else if (var == "MF"){
      Nx = MFNX
    }
    
    # CALCULATIONS
    MLEACH = CFLEACHMANURE / 10000 * Nx
    NOLEACH = MLEACH * 0.0075 * 44 / 28
    # OUTPUT
    assign(paste(var, "NOLEACH", sep = ""), NOLEACH)
  }
  
  ## 4.5 TOTAL N2O EMISSIONS PER ANIMAL
  ## SEE PAGE 73 (GLEAM 2.0)
  
  for (var in c("AFM","AFN","RF","AM","RM","MM","MF")){
    
    # INPUT
    if (var == "AFM"){
      NOdir = AFMNODIR
      NOvol = AFMNOVOL
      NOleach = AFMNOLEACH
      
      num = AF
      
    } else if (var == "AFN"){
      NOdir = AFNNODIR
      NOvol = AFNNOVOL
      NOleach = AFNNOLEACH
      
      num = AF
    } else if (var == "AM"){
      NOdir = AMNODIR
      NOvol = AMNOVOL
      NOleach = AMNOLEACH
      
      num = AM
    } else if (var == "RF"){
      NOdir = RFNODIR
      NOvol = RFNOVOL
      NOleach = RFNOLEACH
      
      num = RF
    } else if (var == "RM"){
      NOdir = RMNODIR
      NOvol = RMNOVOL
      NOleach = RMNOLEACH
      
      num = RM
    } else if (var == "MM"){
      NOdir = MMNODIR
      NOvol = MMNOVOL
      NOleach = MMNOLEACH
      
      num = MM
    } else if (var == "MF"){
      NOdir = MFNODIR
      NOvol = MFNOVOL
      NOleach = MFNOLEACH
      
      num = MF
    }
    
    # CALCULATIONS
    NOtot = NOdir + NOvol + NOleach
    NOtotal = num * NOtot * 298
    
    # OUTPUT
    assign(paste("NOTOTCO2", var, sep = ""), NOtotal)
  }
  
  ## 6.2.1 N2O EMISSIONS FROM MANURE DEPOSITED ON PASTURES
  ## SEE PAGE 82 (GLEAM 2.0)
  
  ## 90% pasture dry matter GLEAM2.0
  ## N retention and excretion per animal type
  AFNNx = AFNNX
  AFN_NXTOTAL = AF*AFNNx
  AFN_MANURE = AFN_NXTOTAL*MMSPASTURE/100
  AFN_N2OFEEDMAN =  AFN_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  AFMNx = AFMNX
  AFM_NXTOTAL = AF*AFMNx
  AFM_MANURE = AFM_NXTOTAL*MMSPASTURE/100
  AFM_N2OFEEDMAN =  AFM_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  RFNx = RFNX
  RF_NXTOTAL = RF*RFNx
  RF_MANURE = RF_NXTOTAL*MMSPASTURE/100
  RF_N2OFEEDMAN =  RF_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  AMNx = AMNX
  AM_NXTOTAL = AM*AMNx
  AM_MANURE = AM_NXTOTAL*MMSPASTURE/100
  AM_N2OFEEDMAN =  AM_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  RMNx = RMNX
  RM_NXTOTAL = RM*RMNx
  RM_MANURE = RM_NXTOTAL*MMSPASTURE/100
  RM_N2OFEEDMAN =  RM_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  MMNx = MMNX
  MM_NXTOTAL = MM*MMNx
  MM_MANURE = MM_NXTOTAL*MMSPASTURE/100
  MM_N2OFEEDMAN =  MM_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  MFNx = MFNX
  MF_NXTOTAL = MF*MFNx
  MF_MANURE = MF_NXTOTAL*MMSPASTURE/100
  MF_N2OFEEDMAN =  MF_MANURE*(0.02+0.2*0.01+0.3*0.0075)*(44/28)*298
  
  ########################################
  ## RESULTS GENERATION
  ########################################
  
  finallist = data.frame(
    farm_name = paste(farm_name,"-",year),
    CH4_Enteric_AFM = ifelse(CH41CO2TOTAFM<0,0,CH41CO2TOTAFM), 
    CH4_Enteric_AFN = ifelse(CH41CO2TOTAFN<0,0,CH41CO2TOTAFN), 
    CH4_Enteric_AM = ifelse(CH41CO2TOTAM<0,0,CH41CO2TOTAM),
    CH4_Enteric_RF = ifelse(CH41CO2TOTRF<0,0,CH41CO2TOTRF), 
    CH4_Enteric_RM = ifelse(CH41CO2TOTRM<0,0,CH41CO2TOTRM), 
    CH4_Enteric_MM = ifelse(CH41CO2TOTMM<0,0,CH41CO2TOTMM), 
    CH4_Enteric_MF = ifelse(CH41CO2TOTMF<0,0,CH41CO2TOTMF),
    CH4_Manure_Management_AFM = ifelse(CH42CO2TOTAFM<0,0,CH42CO2TOTAFM),
    CH4_Manure_Management_AFN = ifelse(CH42CO2TOTAFN<0,0,CH42CO2TOTAFN),
    CH4_Manure_Management_AM = ifelse(CH42CO2TOTAM<0,0,CH42CO2TOTAM),
    CH4_Manure_Management_RF = ifelse(CH42CO2TOTRF<0,0,CH42CO2TOTRF),
    CH4_Manure_Management_RM = ifelse(CH42CO2TOTRM<0,0,CH42CO2TOTRM), 
    CH4_Manure_Management_MM = ifelse(CH42CO2TOTMM<0,0,CH42CO2TOTMM), 
    CH4_Manure_Management_MF = ifelse(CH42CO2TOTMF<0,0,CH42CO2TOTMF),
    N2O_Manure_Management_AFM = ifelse(NOTOTCO2AFM<0,0,NOTOTCO2AFM),
    N2O_Manure_Management_AFN = ifelse(NOTOTCO2AFN<0,0,NOTOTCO2AFN), 
    N2O_Manure_Management_AM = ifelse(NOTOTCO2AM<0,0,NOTOTCO2AM),
    N2O_Manure_Management_RF = ifelse(NOTOTCO2RF<0,0,NOTOTCO2RF), 
    N2O_Manure_Management_RM = ifelse(NOTOTCO2RM<0,0,NOTOTCO2RM), 
    N2O_Manure_Management_MM = ifelse(NOTOTCO2MM<0,0,NOTOTCO2MM), 
    N2O_Manure_Management_MF = ifelse(NOTOTCO2MF<0,0,NOTOTCO2MF), 
    N2O_Manure_in_pasture_AFM = ifelse(AFM_N2OFEEDMAN<0,0,AFM_N2OFEEDMAN),
    N2O_Manure_in_pasture_AFN = ifelse(AFN_N2OFEEDMAN<0,0,AFN_N2OFEEDMAN),
    N2O_Manure_in_pasture_AM = ifelse(AM_N2OFEEDMAN<0,0,AM_N2OFEEDMAN),
    N2O_Manure_in_pasture_RF = ifelse(RF_N2OFEEDMAN<0,0,RF_N2OFEEDMAN),
    N2O_Manure_in_pasture_RM = ifelse(RM_N2OFEEDMAN<0,0,RM_N2OFEEDMAN), 
    N2O_Manure_in_pasture_MM = ifelse(MM_N2OFEEDMAN<0,0,MM_N2OFEEDMAN),
    N2O_Manure_in_pasture_MF = ifelse(MF_N2OFEEDMAN<0,0,MF_N2OFEEDMAN),
    milk = Milk_production, 
    meatm = Meat_production_M,
    meatfm = Meat_production_FM, 
    meatff = Meat_production_FF)
  
  finallist$TOTAL_CH4_Enteric_Fermentation_kg_CO2eq = finallist$CH4_Enteric_AFM + finallist$CH4_Enteric_AFN + finallist$CH4_Enteric_AM +
    finallist$CH4_Enteric_RF + finallist$CH4_Enteric_RM + finallist$CH4_Enteric_MM + finallist$CH4_Enteric_MF
  finallist$TOTAL_CH4_Manure_Managment_kg_CO2eq = finallist$CH4_Manure_Management_AFM + finallist$CH4_Manure_Management_AFN + finallist$CH4_Manure_Management_AM +
    finallist$CH4_Manure_Management_RF + finallist$CH4_Manure_Management_RM + finallist$CH4_Manure_Management_MM + finallist$CH4_Manure_Management_MF
  finallist$TOTAL_N2O_Manure_Managment_kg_CO2eq = finallist$N2O_Manure_Management_AFM + finallist$N2O_Manure_Management_AFN + finallist$N2O_Manure_Management_AM +
    finallist$N2O_Manure_Management_RF + finallist$N2O_Manure_Management_RM + finallist$N2O_Manure_Management_MM + finallist$N2O_Manure_Management_MF
  finallist$TOTAL_N2O_Manure_in_pastures_kg_CO2eq = finallist$N2O_Manure_in_pasture_AFM + finallist$N2O_Manure_in_pasture_AFN + finallist$N2O_Manure_in_pasture_AM +
    finallist$N2O_Manure_in_pasture_RF + finallist$N2O_Manure_in_pasture_RM + finallist$N2O_Manure_in_pasture_MM + finallist$N2O_Manure_in_pasture_MF
  finallist$TOTAL_EMISSIONS = finallist$TOTAL_CH4_Enteric_Fermentation_kg_CO2eq + finallist$TOTAL_CH4_Manure_Managment_kg_CO2eq +
    finallist$TOTAL_N2O_Manure_Managment_kg_CO2eq + finallist$TOTAL_N2O_Manure_in_pastures_kg_CO2eq
  finallist$TOTAL_MILK = finallist$milk
  finallist$TOTAL_MEAT = finallist$meatm + finallist$meatfm + finallist$meatff
  finallist$MILK_INTENSITY = finallist$TOTAL_EMISSIONS/finallist$TOTAL_MILK
  finallist$MEAT_INTENSITY = finallist$TOTAL_EMISSIONS/finallist$TOTAL_MEAT
  
  return(finallist)

}

########################################
##INPUT FILES
########################################

## CSV FILES
main_pasture_list = read.csv("input_pasture_main_list.csv")
mixture_pasture_list = read.csv("input_pasture_mixture_list.csv")
cut_pasture_list = read.csv("input_pasture_cut_list.csv")
diet_list = read.csv("input_feed_supplements_list.csv")
## FARM db
farm_data = read.csv("input_farm_data.csv")
farm_data<-read.xlsx("archivopreguntas.xlsx",sheetIndex = 1)

########################################################################################################################

#Farm data
year = farm_data$anio #year = farm_data$fecha
farm_name = farm_data$finca
longitude = farm_data$longitud
latitude = farm_data$latitud
main_product = farm_data$producto
#Demog
adult_females = farm_data$vacas
adult_females_milk = farm_data$vacas_produccion
young_females= farm_data$vaconas
female_calves= farm_data$terneras
adult_males= farm_data$toros
young_males= farm_data$toretes
male_calves= farm_data$terneros
death_adult_females= farm_data$vacas_muertas
death_female_calves= farm_data$terneras_muertas
death_adult_males= farm_data$toros_muertos
death_male_calves= farm_data$terneros_muertos
slaughtered_adult_females= farm_data$vacas_faenadas
sold_adult_females= farm_data$vacas_vendidas
slaughtered_adult_males= rep(0,nrow(farm_data))#slaughtered_adult_males= farm_data$toros_faenados
sold_adult_males= rep(0,nrow(farm_data))#farm_data$toros_vendidos
total_births= farm_data$partos_totales
age_first_calving_months= farm_data$edad_primer_parto_years*12#farm_data$edad_primer_parto_meses
#Biometry & Production
adult_females_weight= farm_data$peso_vacas
female_calves_weight= farm_data$peso_terneras
adult_males_weight= farm_data$peso_toros
male_calves_weight= farm_data$peso_terneros
slaughtered_young_females_weight= farm_data$peso_sacrificio_vaconas
slaughtered_young_males_weight= farm_data$peso_sacrificio_toretes
milk_fat= farm_data$grasa_leche
milk_protein= farm_data$proteina_leche
milk_yield_liters_animal_day= farm_data$produccion_leche_litro_animal_dia
#Feed
pasture_area_ha= farm_data$superficie_pastos_ha
lactancy_period_months= farm_data$periodo_lactancia_dias/30.41#periodo_lactancia_meses
adult_females_feed_pasture_age=3 #farm_data$edad_pasto_vacas
other_categories_feed_pasture_age=3 #farm_data$edad_pasto_otros
mixture_pasture_ha= farm_data$superficie_pastos_con_silvopastoril_ha#superficie_mezclas
adult_females_feed_cut_pasture_kg = farm_data$alimento2_vacas#pasto_corte_vaca_kg
other_categories_feed_cut_pasture_kg= farm_data$alimento2_otros#pasto_corte_otros_kg
productive_system= farm_data$sistema_productivo
#Manure
manure_drylot= farm_data$excretas_corral_engorde#excretas_lote_secado
manure_in_pastures= farm_data$excretas_sin_manejo
manure_daily_spread= farm_data$excretas_dispersion_diaria
manure_liquid_storage= farm_data$excretas_liquido_fango
manure_compost= farm_data$excretas_compostaje
manure_anaerobic= farm_data$excretas_digestor_anaerobico 
manure_solid= farm_data$excretas_almacenamiento_solido 
manure_uncoveredlagoon= farm_data$excretas_laguna_anaerobica 
manure_burned= farm_data$excretas_incineracion

results = farm_emissions(
  main_pasture_list,
  mixture_pasture_list, 
  cut_pasture_list, 
  diet_list, 
  farm_name, 
  year, 
  longitude, 
  latitude, 
  main_product,
  adult_females, 
  adult_females_milk, 
  young_females, 
  female_calves, 
  adult_males, 
  young_males, 
  male_calves, 
  death_adult_females, 
  death_female_calves, 
  death_adult_males,  
  death_male_calves, 
  slaughtered_adult_females, 
  sold_adult_females, 
  slaughtered_adult_males, 
  sold_adult_males, 
  total_births, 
  age_first_calving_months, 
  adult_females_weight, 
  female_calves_weight, 
  adult_males_weight, 
  male_calves_weight, 
  slaughtered_young_females_weight, 
  slaughtered_young_males_weight, 
  milk_fat,  
  milk_protein,  
  milk_yield_liters_animal_day, 
  lactancy_period_months, 
  pasture_area_ha,
  adult_females_feed_pasture_age,
  other_categories_feed_pasture_age,
  mixture_pasture_ha, 
  adult_females_feed_cut_pasture_kg,  
  other_categories_feed_cut_pasture_kg, 
  productive_system,
  manure_in_pastures, 
  manure_daily_spread,  
  manure_liquid_storage,  
  manure_compost,  
  manure_drylot,  
  manure_solid,  
  manure_anaerobic,  
  manure_uncoveredlagoon,  
  manure_burned
  )

########################################
## RESULTS CSV FILE
########################################
write.csv(results,file = "results.csv")