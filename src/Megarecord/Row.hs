{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeInType #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Megarecord.Row (
        Row, Empty,
        RowCons, RowLacks, RowNub, RowUnion,
        RowAppend, RowPrepend,
        RowDelete
    ) where

import Fcf (Eval, Exp, type (++))
import GHC.TypeLits (Symbol, CmpSymbol, KnownNat, Nat, type (+), type (-))

import Megarecord.Internal (Map(..), Empty, RemoveWith, InsertWith, Lookup, Transform, Row)
import Megarecord.Row.Internal (RowIndex, RowLength, RowIndices, KnownNats)

class (KnownNat (RowIndex label row)) => RowCons (label :: Symbol) (ty :: k) (tail :: Row k) (row :: Row k)
        | label row -> ty tail, label ty tail -> row
instance (RowDelete s r ~ tail, RowPrepend s ty tail ~ r, KnownNat (RowIndex s r)) => RowCons s ty tail r

class RowLacks (label :: Symbol) (row :: Row k)
instance (Lookup label row ~ 'Nothing) => RowLacks label row

class RowNub (original :: Row k) (nubbed :: Row k) | original -> nubbed
instance (RowNub_ original ~ nubbed) => RowNub original nubbed

class (
        KnownNat (RowLength union),
        KnownNats (RowIndices left union),
        KnownNats (RowIndices right union)
    ) => RowUnion (left :: Row k1) (right :: Row k1) (union :: Row k1)
        | left right -> union, union left -> right, right union -> left
instance (
        Union left right ~ union,
        Extract 'RightSide left union ~ right,
        Extract 'LeftSide right union ~ left,
        KnownNat (RowLength union),
        KnownNats (RowIndices left union),
        KnownNats (RowIndices right union)
    ) => RowUnion left right union

-- Implementations
type RowNub_ (r :: Row k1) = Eval (Transform RowNubInternal r)
data RowNubInternal :: Symbol -> [k1] -> Exp [k1]
type instance Eval (RowNubInternal _ (x ': xs)) = '[x]

type RowDelete (s :: Symbol) (r :: Row k1) = Eval (RemoveWith RowDeleteInternal s r)
data RowDeleteInternal :: [k] -> Exp (Maybe [k2])
type instance Eval (RowDeleteInternal '[x]) = 'Nothing
type instance Eval (RowDeleteInternal (x ': (x' ': xs))) = 'Just (x' ': xs)


type RowAppend (k :: Symbol) (v :: k2) (m :: Row k2) = Eval (InsertWith RowAdd k '[v] m)
data RowAdd :: Maybe [v] -> [v] -> Exp [v]
type instance Eval (RowAdd 'Nothing v) = v
type instance Eval (RowAdd ('Just xs) '[v]) = Eval (xs ++ '[v])


type RowPrepend (k :: Symbol) (v :: k2) (m :: Row k2) = Eval (InsertWith RowPrep k '[v] m)
data RowPrep :: Maybe [v] -> [v] -> Exp [v]
type instance Eval (RowPrep 'Nothing v) = v
type instance Eval (RowPrep ('Just xs) '[v]) = v ': xs

type family Union (r1 :: Row k) (r2 :: Row k) :: Row k where
    Union r1 'Nil = r1
    Union 'Nil r2 = r2
    Union ('Cons l1 v1 m1) ('Cons l2 v2 m2) = UnionInternal (CmpSymbol l1 l2) ('Cons l1 v1 m1) ('Cons l2 v2 m2)

type family UnionInternal (o :: Ordering) (r1 :: Row k) (r2 :: Row k) :: Row k where
    UnionInternal 'EQ ('Cons l1 v1 m1) ('Cons l2 v2 m2) = Union m1 ('Cons l2 (Eval (v1 ++ v2)) m2)
    UnionInternal 'LT ('Cons l v m) r2 = Union m ('Cons l v r2)
    UnionInternal 'GT r1 ('Cons l v m) = 'Cons l v (Union r1 m)

data Side = LeftSide | RightSide

type family Extract (s :: Side) (side :: Row k) (union :: Row k) :: Row k where
    Extract _ 'Nil r = r
    Extract s ('Cons k v m) ('Cons k v' m') = ExtractInternal k (Drop s v v') (Extract s m m')
    Extract s r1 ('Cons k v m) = 'Cons k v (Extract s r1 m)

type family Drop (s :: Side) (v :: [k]) (v' :: [k]) :: [k] where
    Drop 'RightSide '[] xs = xs
    Drop 'RightSide (x ': xs) (x ': ys) = Drop 'RightSide xs ys
    Drop 'LeftSide xs ys = Take (Length ys - Length xs) ys
    Drop _ '[] '[] = '[]

type family Take (n :: Nat) (l :: [k]) :: [k] where
    Take 0 _ = '[]
    Take n (x ': xs) = x ': Take (n - 1) xs

type family Length (xs :: [k]) :: Nat where
    Length '[] = 0
    Length (x ': xs) = 1 + Length xs

type family ExtractInternal (l :: Symbol) (v :: [k]) (r :: Row k) :: Row k where
    ExtractInternal _ '[] r = r
    ExtractInternal l v r = 'Cons l v r
