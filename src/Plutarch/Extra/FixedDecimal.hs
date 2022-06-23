{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}

module Plutarch.Extra.FixedDecimal (
    PFixedDecimal (..),
    DivideSemigroup (..),
    DivideMonoid (..),
    decimalToAdaValue,
    fromPInteger,
    fromPInteger',
    toPInteger',
    toPInteger,
) where

import Data.Bifunctor (first)
import Data.Proxy (Proxy (Proxy))
import GHC.TypeLits (KnownNat, Nat, natVal)
import Generics.SOP (I (I))
import Generics.SOP.TH (deriveGeneric)
import Plutarch.Api.V1 (AmountGuarantees, KeyGuarantees, PValue)
import Plutarch.Api.V1.Value (psingletonValue)
import Plutarch.Bool (PEq, POrd)
import Plutarch.Integer (PInteger, PIntegral (pdiv))
import qualified Plutarch.Numeric.Additive as A (
    AdditiveMonoid (..),
    AdditiveSemigroup (..),
 )
import Plutarch.Prelude (
    DerivePNewtype (..),
    PAsData,
    PCon (pcon),
    PData,
    PIsData,
    PTryFrom,
    PlutusType,
    S,
    Term,
    pconstant,
    phoistAcyclic,
    plam,
    pto,
    (#),
    (#$),
    type (:-->),
 )
import Plutarch.Show (PShow)
import Plutarch.TryFrom (PTryFrom (PTryFromExcess, ptryFrom'))
import Plutarch.Unsafe (punsafeCoerce)

{- | Fixed width decimal. Decimal point will be given through typelit.
 This would be used for representing Ada value with some Lovelace changes.

 @since 1.0.0
-}
newtype PFixedDecimal (unit :: Nat) (s :: S)
    = PFixedDecimal (Term s PInteger)

deriveGeneric ''PFixedDecimal

deriving anyclass instance PShow (PFixedDecimal unit)

-- | @since 1.0.0
deriving via
    (DerivePNewtype (PFixedDecimal u) PInteger)
    instance
        (PlutusType (PFixedDecimal u))

-- | @since 1.0.0
deriving via
    (DerivePNewtype (PFixedDecimal u) PInteger)
    instance
        PIsData (PFixedDecimal u)

-- | @since 1.0.0
deriving via
    (DerivePNewtype (PFixedDecimal u) PInteger)
    instance
        PEq (PFixedDecimal u)

-- | @since 1.0.0
deriving via
    (DerivePNewtype (PFixedDecimal u) PInteger)
    instance
        POrd (PFixedDecimal u)

-- | @since 1.0.0
instance KnownNat u => Num (Term s (PFixedDecimal u)) where
    (+) = (+)
    (-) = (-)
    (pto -> x) * (pto -> y) =
        pcon . PFixedDecimal $ pdiv # (x * y) # pconstant (natVal (Proxy @u))
    abs = abs
    signum = signum
    fromInteger = pcon . PFixedDecimal . (* pconstant (natVal (Proxy @u))) . pconstant

-- | @since 1.0.0
instance PTryFrom PData (PAsData (PFixedDecimal unit)) where
    type PTryFromExcess PData (PAsData (PFixedDecimal unit)) = PTryFromExcess PData (PAsData PInteger)
    ptryFrom' d k = ptryFrom' @_ @(PAsData PInteger) d $ k . first punsafeCoerce

-- TODO: This should be moved to either to plutarch-numeric or other module
class DivideSemigroup a where
    divide :: a -> a -> a

class DivideSemigroup a => DivideMonoid a where
    one :: a

-- | @since 1.0.0
instance KnownNat u => DivideSemigroup (Term s (PFixedDecimal u)) where
    divide (pto -> x) (pto -> y) =
        pcon . PFixedDecimal $ pdiv # (x * (pconstant $ natVal (Proxy @u))) # y

-- | @since 1.0.0
instance KnownNat u => DivideMonoid (Term s (PFixedDecimal u)) where
    one = fromInteger 1

-- | @since 1.0.0
instance KnownNat u => A.AdditiveSemigroup (Term s (PFixedDecimal u)) where
    (+) = (+)

-- | @since 1.0.0
instance KnownNat u => A.AdditiveMonoid (Term s (PFixedDecimal u)) where
    zero = pcon . PFixedDecimal $ pconstant 0

{- | Convert given decimal into Ada value. Input should be Ada value with decimals; outputs
 will be lovelace values in integer.

 @since 1.0.0
-}
decimalToAdaValue ::
    forall (s :: S) (keys :: KeyGuarantees) (amounts :: AmountGuarantees) (unit :: Nat).
    KnownNat unit =>
    Term s (PFixedDecimal unit :--> PValue keys amounts)
decimalToAdaValue =
    phoistAcyclic $
        plam $ \(pto -> dec) ->
            let adaValue = (pdiv # dec # (pconstant (natVal (Proxy @unit)))) * pconstant 1000000
             in psingletonValue # pconstant "" # pconstant "" #$ adaValue

{- | Convert @PInteger@ to @PFixedDecimal@.

 @since 1.0.0
-}
fromPInteger ::
    forall (unit :: Nat) (s :: S).
    KnownNat unit =>
    Term s (PInteger :--> PFixedDecimal unit)
fromPInteger =
    phoistAcyclic $ plam $ \z -> fromPInteger' z

{- | Convert @PInteger@ to @PFixedDecimal@ in Haskell level.

 @since 1.0.0
-}
fromPInteger' ::
    forall (unit :: Nat) (s :: S).
    KnownNat unit =>
    Term s PInteger ->
    Term s (PFixedDecimal unit)
fromPInteger' z = pcon . PFixedDecimal $ pconstant (natVal (Proxy @unit)) * z

{- | Convert @PFixedDecimal@ to @Integer@. Values that are smaller than 1 will be lost.

 @since 1.0.0
-}
toPInteger ::
    forall (unit :: Nat) (s :: S).
    KnownNat unit =>
    Term s (PFixedDecimal unit :--> PInteger)
toPInteger =
    phoistAcyclic $ plam $ \d -> toPInteger' d

{- | Identical to @toPInteger@ but Haskell level.

 @since 1.0.0
-}
toPInteger' ::
    forall (unit :: Nat) (s :: S).
    KnownNat unit =>
    Term s (PFixedDecimal unit) ->
    Term s PInteger
toPInteger' d = pdiv # pto d # (pconstant (natVal (Proxy @unit)))
