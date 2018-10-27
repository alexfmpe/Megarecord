module Megarecord.Internal (
        Compare, Map, Empty,
        Lookup, InsertWith,
        RemoveWith, Traverse,
        Contains, Insert
    ) where

import Data.Kind (Type)
import GHC.TypeLits (Symbol, Nat, CmpSymbol, CmpNat)
import Fcf (Eval, Exp, Flip, ConstFn, FromMaybe, type (=<<))
import qualified Fcf as F

-- Used for providing a total order over types
type family Compare (a :: k) (b :: k) :: Ordering

type instance Compare (a :: Symbol) (b :: Symbol) = CmpSymbol a b
type instance Compare (a :: Nat) (b :: Nat) = CmpNat a b


-- The core type level Map datatype
data Map (k :: Type) (v :: Type) = Cons k v (Map k v) | Nil
type Empty = 'Nil

-- Core operations on the type
type Lookup (k :: k1) (m :: Map k1 k2) = Eval (Lookup_ k m)


data Lookup_ :: k1 -> Map k1 k2 -> Exp (Maybe k2)
type instance Eval (Lookup_ k 'Nil) = 'Nothing
type instance Eval (Lookup_ k ('Cons k' v m)) = Eval (LookupInternal (Compare k k') k ('Cons k' v m))

data LookupInternal :: Ordering -> k1 -> Map k1 k2 -> Exp (Maybe k2)
type instance Eval (LookupInternal 'LT _ _) = 'Nothing
type instance Eval (LookupInternal 'EQ k ('Cons _ v _)) = 'Just v
type instance Eval (LookupInternal 'GT k ('Cons _ _ m)) = Lookup k m



data InsertWith :: (Maybe k2 -> k2 -> Exp k2) -> k1 -> k2 -> Map k1 k2 -> Exp (Map k1 k2)


type instance Eval (InsertWith f k v 'Nil) = 'Cons k (Eval (f 'Nothing v)) 'Nil
type instance Eval (InsertWith f k v ('Cons k' v' m)) =
    Eval (InsertInternal (Compare k k') f k v ('Cons k' v' m))

data InsertInternal :: Ordering -> (Maybe k2 -> k2 -> Exp k2) -> k1 -> k2 -> Map k1 k2 -> Exp (Map k1 k2)
type instance Eval (InsertInternal 'LT f k v m) = 'Cons k (Eval (f 'Nothing v)) m
type instance Eval (InsertInternal 'EQ f k v ('Cons k' v' m)) = 'Cons k (Eval (f ('Just v') v)) m
type instance Eval (InsertInternal 'GT f k v ('Cons k' v' m)) = 'Cons k' v' (Eval (InsertWith f k v m))



data RemoveWith :: (k2 -> Exp (Maybe k2)) -> k1 -> Map k1 k2 -> Exp (Map k1 k2)


type instance Eval (RemoveWith f k 'Nil) = 'Nil
type instance Eval (RemoveWith f k ('Cons k' v m)) =
    Eval (RemoveWithInternal (Compare k k') f k ('Cons k' v m))

data RemoveWithInternal :: Ordering -> (k2 -> Exp (Maybe k2)) -> k1 -> Map k1 k2 -> Exp (Map k1 k2)
type instance Eval (RemoveWithInternal 'LT _ _ m) = m
type instance Eval (RemoveWithInternal 'EQ f k ('Cons _ v m)) =
    RemoveNode (Eval (f v)) ('Cons k v m)
type instance Eval (RemoveWithInternal 'GT f k ('Cons k' v m)) =
    'Cons k' v (Eval (RemoveWith f k m))

type family RemoveNode (v :: Maybe k2) (m :: Map k1 k2) :: Map k1 k2 where
    RemoveNode 'Nothing ('Cons _ _ m) = m
    RemoveNode ('Just x) ('Cons k _ m) = 'Cons k x m



type family Traverse (f :: k1 -> k2 -> Exp k3) (con :: k3 -> k3 -> Exp k3) (m :: Map k1 k2) (id :: k3) :: k3 where
    Traverse _ _ 'Nil id = id
    Traverse f _ ('Cons k v 'Nil) _ = Eval (f k v)
    Traverse f con ('Cons k v m) id = Eval (con (Eval (f k v)) (Traverse f con m id))


-- Combinators
type Insert (k :: k1) (v :: k2) (m :: Map k1 k2) = Eval (InsertWith (Flip ConstFn) k v m)

type Contains (mapping :: k2 -> Exp Bool) (k :: k1) (m :: Map k1 k2) =
    Eval (FromMaybe 'False =<< F.Map mapping =<< Lookup_ k m)
