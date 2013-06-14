
{-# LANGUAGE
    TypeFamilies,
    DeriveFunctor,
    DeriveFoldable,
    DeriveDataTypeable,
    FlexibleInstances,
    FlexibleContexts,
    ConstraintKinds,
    GeneralizedNewtypeDeriving #-}

-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides tie representation and splitting.
--
-------------------------------------------------------------------------------------


module Music.Score.Ties (
        Tiable(..),
        TieT(..),
        splitTies,
        splitTiesSingle,
        splitTiesVoice,
  ) where

import Control.Monad
import Control.Monad.Plus
import Data.Default
import Data.Maybe
import Data.Ratio
import Data.Foldable hiding (concat)
import Data.Typeable
import qualified Data.List as List
import Data.VectorSpace
import Data.AffineSpace

import Music.Score.Voice
import Music.Score.Score
import Music.Score.Combinators
import Music.Score.Part
import Music.Time

-- |
-- Class of types that can be tied.
--
class Tiable a where
    -- | Split elements into beginning and end and add tie.
    --   Begin properties goes to the first tied note, and end properties to the latter.

    --   The first returned element will have the original onset.
    --
    toTied    :: a -> (a, a)

newtype TieT a = TieT { getTieT :: (Bool, a, Bool) }
    deriving (Eq, Ord, Show, Functor, Foldable, Typeable)

-- These are note really tiable..., but Tiable a => (Bool,a,Bool) would be
instance Tiable Double      where toTied x = (x,x)
instance Tiable Float       where toTied x = (x,x)
instance Tiable Int         where toTied x = (x,x)
instance Tiable Integer     where toTied x = (x,x)
instance Tiable ()          where toTied x = (x,x)
instance Tiable (Ratio a)   where toTied x = (x,x)

instance Tiable a => Tiable (Maybe a) where
    toTied Nothing  = (Nothing, Nothing)
    toTied (Just a) = (Just b, Just c) where (b,c) = toTied a

instance Tiable a => Tiable (TieT a) where
    toTied (TieT (prevTie, a, nextTie)) = (TieT (prevTie, b, True), TieT (True, c, nextTie))
         where (b,c) = toTied a

-- |
-- Split all notes that cross a barlines into a pair of tied notes.
--
splitTies :: (HasPart' a, Tiable a) => Score a -> Score a
splitTies = mapParts splitTiesSingle

-- |
-- Equivalent to `splitTies` for single-voice scores.
-- Fails if the score contains overlapping events.
--
splitTiesSingle :: Tiable a => Score a -> Score a
splitTiesSingle = voiceToScore' . splitTiesVoice . scoreToVoice

-- |
-- Split all notes that cross a barlines into a pair of tied notes.
--
splitTiesVoice :: Tiable a => Voice a -> Voice a
splitTiesVoice = Voice . concat . snd . List.mapAccumL g 0 . getVoice
    where
        g t (d, x) = (t + d, occs)
            where
                (_, barTime) = properFraction t
                remBarTime   = 1 - barTime
                occs = splitDur remBarTime 1 (d,x)

-- |
-- Split an event into one chunk of the duration @s@, followed parts shorter than duration @t@.
--
-- The returned list is always non-empty. All elements but the first and the last must have duration @t@.
--
-- > sum $ fmap fst $ splitDur s (x,a) = x
--
splitDur :: Tiable a => DurationT -> DurationT -> (DurationT, a) -> [(DurationT, a)]
splitDur s t x = case splitDur' s x of
    (a, Nothing) -> [a]
    (a, Just b)  -> a : splitDur t t b

-- |
-- Extract the the first part of a given duration. If the note is shorter than the given duration,
-- return it and @Nothing@. Otherwise return the extracted part, and the rest.
--
-- > splitDur s (d,a)
--
splitDur' :: Tiable a => DurationT -> (DurationT, a) -> ((DurationT, a), Maybe (DurationT, a))
splitDur' s (d,a) | d <= s     =  ((d,a), Nothing)
                  | otherwise  =  ((s,b), Just (d-s, c)) where (b,c) = toTied a




