module Domain.VolunteerList
  ( VolunteerList(..)
  , add
  , empty
  , fromArray
  , removeById
  , showTable
  , sortByGrade
  , sortBySeat
  , toArray
  , toTableRows
  ) where

import Prelude (class Show, compare, map, show, (/=))
import Data.Array as Array
import Data.Foldable (intercalate)
import Data.Maybe (Maybe(..))
import Data.Ordering (Ordering(..))
import Domain.Volunteer (Volunteer, getGrade, showSeat)

newtype VolunteerList
  = VolunteerList (Array Volunteer)

instance showVolunteerList :: Show VolunteerList where
  show = showTable

empty :: VolunteerList
empty = VolunteerList []

fromArray :: Array Volunteer -> VolunteerList
fromArray = VolunteerList

toArray :: VolunteerList -> Array Volunteer
toArray (VolunteerList volunteers) = volunteers

add :: Volunteer -> VolunteerList -> VolunteerList
add volunteer (VolunteerList volunteers) = VolunteerList (Array.snoc volunteers volunteer)

removeById :: Int -> VolunteerList -> VolunteerList
removeById id (VolunteerList volunteers) = VolunteerList (Array.filter (\volunteer -> volunteer.id /= id) volunteers)

sortBySeat :: VolunteerList -> VolunteerList
sortBySeat (VolunteerList volunteers) = VolunteerList (Array.sortBy compareVolunteerSeat volunteers)

sortByGrade :: VolunteerList -> VolunteerList
sortByGrade (VolunteerList volunteers) = VolunteerList (Array.sortBy compareVolunteerGrade volunteers)

toTableRows :: VolunteerList -> Array (Array String)
toTableRows (VolunteerList volunteers) = map volunteerToRow volunteers

showTable :: VolunteerList -> String
showTable list = intercalate "\n" (map (intercalate " | ") (toTableRows list))

volunteerToRow :: Volunteer -> Array String
volunteerToRow volunteer =
  [ show volunteer.id
  , volunteer.name
  , show volunteer.age
  , show (getGrade volunteer)
  , showSeat volunteer.seat
  ]

compareVolunteerGrade :: Volunteer -> Volunteer -> Ordering
compareVolunteerGrade left right = case compare (getGrade left) (getGrade right) of
  EQ -> compare left.name right.name
  ordering -> ordering

compareVolunteerSeat :: Volunteer -> Volunteer -> Ordering
compareVolunteerSeat left right = case compareMaybeSeat left.seat right.seat of
  EQ -> compare left.name right.name
  ordering -> ordering

compareMaybeSeat :: Maybe { row :: Int, col :: Int } -> Maybe { row :: Int, col :: Int } -> Ordering
compareMaybeSeat left right = case left, right of
  Nothing, Nothing -> EQ
  Nothing, Just _ -> GT
  Just _, Nothing -> LT
  Just leftSeat, Just rightSeat -> compareSeat leftSeat rightSeat

compareSeat :: { row :: Int, col :: Int } -> { row :: Int, col :: Int } -> Ordering
compareSeat left right = case compare left.row right.row of
  EQ -> compare left.col right.col
  ordering -> ordering
