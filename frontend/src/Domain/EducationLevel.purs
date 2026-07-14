module Domain.EducationLevel
  ( EducationLevel(..)
  , educationLevelToApi
  ) where

data EducationLevel
  = Kindergarten
  | ElementarySchool
  | JuniorHighSchool
  | SeniorHighSchool
  | Adult

educationLevelToApi :: EducationLevel -> String
educationLevelToApi = case _ of
  Kindergarten -> "KINDERGARTEN"
  ElementarySchool -> "ELEMENTARY_SCHOOL"
  JuniorHighSchool -> "JUNIOR_HIGH_SCHOOL"
  SeniorHighSchool -> "SENIOR_HIGH_SCHOOL"
  Adult -> "ADULT"
