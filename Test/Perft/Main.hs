module Main (main) where

import Control.Monad
import Data.List (nub)
import Data.Maybe
import Options.Applicative
import System.Exit

import Test.HUnit

import Chess.Move
import Chess.Board


------------------------------------------------------------------------------
legalMoves :: Board -> [ Move ]
legalMoves b = 
  let leg  = mkLegality b
  in mapMaybe (snd . legalCheck leg) $ nub $ moves b


------------------------------------------------------------------------------
perft :: Int -> Board -> Integer
perft 0 _ = 0
perft d b = let ms   = legalMoves b
            in if d == 1
               then fromIntegral $ length ms
               else sum [ perft (d - 1) (makeMove m b) | m <- ms ]


------------------------------------------------------------------------------
-- from http://chessprogramming.wikispaces.com/Perft+Results
initialPerftResult :: Int -> Integer
initialPerftResult 1  = 20
initialPerftResult 2  = 400
initialPerftResult 3  = 8902
initialPerftResult 4  = 197281
initialPerftResult 5  = 4865609
initialPerftResult 6  = 119060324
initialPerftResult 7  = 3195901860
initialPerftResult 8  = 84998978956
initialPerftResult 9  = 2439530234167
initialPerftResult 10 = 69352859712417
initialPerftResult 11 = 2097651003696806
initialPerftResult 12 = 62854969236701747
initialPerftResult 13 = 1981066775000396239
initialPerftResult _  = undefined


------------------------------------------------------------------------------
testInitialPos :: Int -> Test
testInitialPos n = perft n initialBoard ~?= initialPerftResult n


------------------------------------------------------------------------------
initialTests :: Test
initialTests  =
  TestList [ TestLabel ("Initial Perft " ++ show n) $ testInitialPos n
           | n <- [1 .. 4]
           ]


------------------------------------------------------------------------------
ruyLopezPosition :: Board
ruyLopezPosition = fromJust $ fromFEN
  "r1bqkbnr/1pp2ppp/p1p5/4N3/4P3/8/PPPP1PPP/RNBQK2R b KQkq -"


------------------------------------------------------------------------------
ruyLopezPerftResult :: Int -> Integer
ruyLopezPerftResult 1 =           36
ruyLopezPerftResult 2 =         1147
ruyLopezPerftResult 3 =        41558
ruyLopezPerftResult 4 =      1322527
ruyLopezPerftResult 5 =     48184273
ruyLopezPerftResult 6 =   1552389766
ruyLopezPerftResult _ = undefined


------------------------------------------------------------------------------
testRuyLopez :: Int -> Test
testRuyLopez n = perft n ruyLopezPosition ~?= ruyLopezPerftResult n


------------------------------------------------------------------------------
ruyLopezTests :: Test
ruyLopezTests =
  TestList [ TestLabel ("Ruy Lopez Perft " ++ show n) $ testRuyLopez n
           | n <- [1 .. 4]
           ]


------------------------------------------------------------------------------
allTests :: Test
allTests = TestList [initialTests, ruyLopezTests]


------------------------------------------------------------------------------
data Config = Perft Board Int | Siblings Board


------------------------------------------------------------------------------
fenArgument :: Parser Board
fenArgument = argument (eitherReader f) (metavar "FEN")
  where f s = case fromFEN s of
          Just b  -> Right b
          Nothing -> Left "Cannot parse FEN option"


------------------------------------------------------------------------------
intArgument :: Parser Int
intArgument = argument (eitherReader f) (metavar "DEPTH")
  where f s = case reads s of                                        
          (i,_):_ -> Right i
          []      -> Left "Cannot parse integer option"

------------------------------------------------------------------------------
fenCommandParser :: Parser Config
fenCommandParser = Perft <$> fenArgument <*> intArgument


------------------------------------------------------------------------------
siblingCommandParser :: Parser Config
siblingCommandParser = Siblings <$> fenArgument


------------------------------------------------------------------------------
commandParser :: Parser (Maybe Config)
commandParser = optional (subparser (
     command "perft"
     ( info fenCommandParser
       $ progDesc "Allows the user to specify a FEN & depth")
     <> command "siblings"
     ( info siblingCommandParser
       $ progDesc "Prints the siblings of the specified FEN")))


------------------------------------------------------------------------------
main :: IO ()
main = do
  conf <- execParser ((info $ commandParser <**> helper) idm)
  case conf of
    Just (Perft b d)  -> print $ perft d b
    Just (Siblings b) -> void $ mapM putStrLn
                         [ fen $ makeMove m b | m <- legalMoves b ]
    Nothing           -> do
      c <- runTestTT allTests
      if cases c == tried c && failures c == 0 && errors c == 0
        then exitSuccess
        else exitFailure

