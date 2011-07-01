-- Required for Show (MutTerm v t) instance
{-# LANGUAGE FlexibleContexts, UndecidableInstances #-}
-- Required more generally
{-# LANGUAGE Rank2Types, MultiParamTypeClasses, FunctionalDependencies #-}

{-# OPTIONS_GHC -Wall -fwarn-tabs #-}

----------------------------------------------------------------
--                                                  ~ 2011.06.30
-- |
-- Module      :  Control.Unification.Classes
-- Copyright   :  Copyright (c) 2007--2011 wren ng thornton
-- License     :  BSD
-- Maintainer  :  wren@community.haskell.org
-- Stability   :  experimental
-- Portability :  semi-portable (Rank2Types, MPTCs, fundeps,...)
--
-- This module defines the classes used by unification and related
-- functions.
----------------------------------------------------------------
module Control.Unification.Classes
    ( MutTerm(..)
    , freeze
    , unfreeze
    , Rank(..)
    , BindingMonad(..)
    , Unifiable(..)
    , Variable(..)
    ) where

import Prelude hiding (mapM, sequence, foldr, foldr1, foldl, foldl1)

import Data.Functor.Fixedpoint
import Data.Traversable    (Traversable(..))
import Control.Applicative (Applicative(..), (<$>))
----------------------------------------------------------------
----------------------------------------------------------------

-- | The type of terms generated by structures @t@ over variables @v@.
data MutTerm v t
    = MutVar  !(v (MutTerm v t))
    | MutTerm !(t (MutTerm v t))

instance (Show (v (MutTerm v t)), Show (t (MutTerm v t))) =>
    Show (MutTerm v t)
    where
    show (MutVar  v) = show v
    show (MutTerm t) = show t


-- | /O(n)/. Embed a pure term as a mutable term.
unfreeze :: (Functor t) => Fix t -> MutTerm v t
unfreeze = MutTerm . fmap unfreeze . unFix


-- | /O(n)/. Extract a pure term from a mutable term, or return
-- @Nothing@ if the mutable term actually contains variables. N.B.,
-- this function is pure, so you should manually apply bindings
-- before calling it; cf., 'freezeM'.
freeze :: (Traversable t) => MutTerm v t -> Maybe (Fix t)
freeze (MutVar  _) = Nothing
freeze (MutTerm t) = Fix <$> mapM freeze t


----------------------------------------------------------------

-- | The target of all variables, for weighted path compression.
-- Each variable has a (mutable) ``rank'' associated with it, as
-- well as possibly being bounded to some term.
data Rank v t = Rank {-# UNPACK #-} !Int !(Maybe (MutTerm v t))


-- | A class for generating, reading, and writing to bindings stored
-- in a monad. These three functionalities could be split apart,
-- but are combined in order to simplify contexts.
class (Unifiable t, Variable v, Applicative m, Monad m) =>
    BindingMonad v t m | m -> v t
    where
    -- | Given a variable pointing to @t@, return its rank and the
    -- @t@ it's bound to (or @Nothing@ if the variable is unbound).
    lookupRankVar :: v (MutTerm v t) -> m (Rank v t)
    
    -- | Given a variable pointing to @t@, return the @t@ it's bound to (or @Nothing@ if the variable is unbound).
    lookupVar :: v (MutTerm v t) -> m (Maybe (MutTerm v t))
    lookupVar v = do { Rank _ mb <- lookupRankVar v ; return mb }

    -- | Generate a new free variable guaranteed to be fresh in
    -- @m@.
    freeVar :: m (v (MutTerm v t))
    
    -- | Generate a new variable (fresh in @m@) bound to the given
    -- term.
    newVar :: MutTerm v t -> m (v (MutTerm v t))
    newVar t = do { v <- freeVar ; bindVar v t ; return v }
    
    -- | Bind a variable to a term, overriding any previous binding.
    bindVar :: v (MutTerm v t) -> MutTerm v t -> m ()
    
    -- | Increase the rank of a variable by one.
    incrementRank :: v (MutTerm v t) -> m ()
    
    -- | Bind a variable to a term and increment the rank at the same time.
    incrementBindVar :: v (MutTerm v t) -> MutTerm v t -> m ()
    incrementBindVar v t = do { incrementRank v ; bindVar v t }


----------------------------------------------------------------
-- | An implementation of unifiable structure.
class (Traversable t) => Unifiable t where
    -- | Perform one level of equality testing for terms. If the
    -- term constructors are unequal then return @Nothing@; if they
    -- are equal, then return the one-level spine filled with pairs
    -- of subterms to be recursively checked.
    zipMatch :: t a -> t b -> Maybe (t (a,b))



-- | An implementation of unification variables.
class Variable v where
    -- | Determine whether two variables are equal /as variables/,
    -- without considering what they are bound to.
    eqVar :: v a -> v a -> Bool
    
    -- | Return a unique identifier for this variable, in order to
    -- support the use of visited-sets instead of occurs checks.
    getVarID :: v a -> Int

----------------------------------------------------------------
----------------------------------------------------------- fin.