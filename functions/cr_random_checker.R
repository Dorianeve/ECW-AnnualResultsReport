# function for CR Step3 SPOT CHECKS TEMPLATE / COMBINER 

cr_random_checker <- function(beneficiary, gender, education_level, gmgrn) {
  df %>%
    filter(Typeofeducation == "Formal education" &
             Typeofbeneficiary == beneficiary &
             Gender == gender &
             Levelofeducation == education_level &
             GMGRN == gmgrn) %>%
    select(GMGRN, Typeofeducation, Typeofbeneficiary, Levelofeducation, Gender, Number)
}

