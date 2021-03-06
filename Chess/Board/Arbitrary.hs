{-# OPTIONS_GHC -fno-warn-orphans #-}
module Chess.Board.Arbitrary () where

import           Control.Monad
import           Data.Maybe

import           Control.Lens
import           Test.QuickCheck (arbitrary, suchThat)
import qualified Test.QuickCheck as Q

import           Chess.Board.Attacks
import           Chess.Board.Board
import           Data.BitBoard
import           Data.ChessTypes hiding (opponent)
import           Data.Square

------------------------------------------------------------------------------
instance Q.Arbitrary Board where
  -- TODO   enpassant
  --        casltes
  arbitrary = flip suchThat kingAttacksOk $ do
    wkPos <- arbitrary                     -- white king
    bkPos <- suchThat arbitrary (/= wkPos) -- black king
    let ks = fromSquare wkPos .|. fromSquare bkPos
    rs <- removing   ks                          -- rooks
    ns <- removing $ ks .|. rs                   -- knights
    bs <- removing $ ks .|. rs .|. ns            -- bishops
    qs <- removing $ ks .|. rs .|. ns .|. bs     -- queens
    ps <- removing $ ks .|. rs .|. ns .|. bs .|. qs
          .|. rankBB firstRank .|. rankBB eighthRank
    
    let occ = rs .|. ns .|. bs .|. qs .|. ps
    wpcs <- liftM (.&. occ) arbitrary
    let bpcs = occ .&. complement wpcs
    n <- Q.elements [ Black, White ]
    let b = flipPiece White King (Left wkPos)
            $ flipPiece Black King (Left bkPos)
            $ foldr1 (.) [ flipPiece c pt (Right bb)
                         | (c, cbb) <- [ (Black, bpcs), (White, wpcs) ]
                         , (pt, bb) <- [ (Rook, rs .&. cbb)
                                       , (Knight, ns .&. cbb)
                                       , (Bishop, bs .&. cbb)
                                       , (Queen, qs .&. cbb)
                                       , (Pawn, ps .&. cbb)
                                       ]
                         ]
            $ (next .~ n) emptyBoard

    return $ (hash .~ calcHash b) b

    where removing f = liftM (.&. complement f) arbitrary

  -- remove 1 piece (except the king)
  shrink b = filter kingAttacksOk
             $ map (`removePiece` b) $ filter goodSquare squares
    where goodSquare sq = let p = pieceAt b sq in isJust p && p /= Just King


------------------------------------------------------------------------------
-- | The king that's not next to move cannot be in check, and the other king
-- can only be in check by at most 2 pieces
kingAttacksOk :: Board -> Bool
kingAttacksOk b =
  let nKingPos = head $ toList $ piecesOf b (b^.next) King
      oKingPos = head $ toList $ piecesOf b (b^.opponent) King
      nAttackers = attackedFromBB b (occupancy b) (b^.opponent) nKingPos
      oAttackers = attackedFromBB b (occupancy b) (b^.next)     oKingPos
      numNAttackers = popCount nAttackers
      numOAttackers = popCount oAttackers
  in numOAttackers == 0 && numNAttackers <= 2
