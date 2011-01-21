module Main where

import Data.Bits
import Control.Concurrent
import Prelude

import AlphaBeta
import BitEval
import BitRepresenation
import MTDf
import MCTS
import MyBits
import Hash
import MonteCarloEval


showHeader :: String -> IO ()
showHeader h = do
        putStrLn $ '\n' : h
        putStrLn $ map (\_ -> '-') h  -- underline

testMyBits :: Bool
testMyBits = and [bitIndex (bit i) == i | i <- [0..63]] -- && bitIndex 222 == -1

testTiming :: IO ()
testTiming = do
        showHeader "testTiming"
        {-
        mvar <- newMVar ([],0)
        thread <- forkOS $ MTDf.search testBoard mvar
        threadDelay 30000000
        (pv, val) <- takeMVar mvar
        print (pv, val)
        killThread thread
        -- -}
        -- {-
        best <- alphaBeta testBoard' [] (-iNFINITY, iNFINITY) 5 0 Gold
        print best
        -- -}
    where
        testBoard' = parseFlatBoard Gold "[r r  r r drc rdrrh  c mh   eE      H     D    HRRR C RR R RC  DR]"

{- -------------------------------------------------------
 - Testing MCTS
 - ------------------------------------------------------- -}
data Show a => CTree a = CT a [CTree a]

instance Show a => Show (CTree a) where
    show = ("CalculTree\n" ++) . s 0 where
        s :: Show a => Int -> CTree a -> String
        s i (CT a subtrs) = replicate (4*i) ' ' ++ show a
                          ++ "\n" ++ (concat $ map (s (i+1)) subtrs)

mm2c :: MMTree -> CTree (MovePhase, Int, Int)
mm2c mt = CT (movePhase mt, val,num) subtrees
    where
        (val,num,subtrees) = case treeNode mt of
                                Leaf -> (0,0,[])
                                tn -> (value tn, number tn, map mm2c $ children tn)

simpleMMTree :: Board -> MMTree
simpleMMTree b =
    MT { board = b
       , movePhase = (mySide b, 0)
       , treeNode = Leaf
       , step = (Pass, Pass)
       }

testMCTS :: IO ()
testMCTS = do
        showHeader "starting MonteCarlo test:"
        getValueByMC testBoard3 (Gold, 0) >>= putStrLn.("MC: "++).show

        showHeader "starting MCTS test:"
        (mt1,_) <- improveTree $ simpleMMTree testBoard
        print $ mm2c mt1
        (mt2,_) <- improveTree mt1
        print $ mm2c mt2
        (mt3,_) <- improveTree mt2
        print $ mm2c mt3
        (mt4,_) <- improveTree mt3
        print $ mm2c mt4
        print $ descendByUCB1 mt4

{- ------------------------------------------------------- -}

showMove :: Show b => ([(Step,Step)], b) -> String
showMove ([],a) = show ("Empty Move",a)
showMove (ss,a) = "( " ++ foldr (\c b -> show c ++ " " ++ b) "" ss' ++ ", " ++ show a ++ ")"
    where
        ss' = foldr (\(s1,s2) b -> if s2 /= Pass then s1:s2:b else s1:b) [] ss

main :: IO ()
main = do
    putStrLn $ "- testMyBits: " ++ show testMyBits
    putStrLn $ "- testMakeMove: " ++ show (testBoard3 == testBoard4)

    -- putStrLn $ displayBoard testBoard2 True
    -- putStrLn.show $ generateSteps testBoard2 Gold

    -- putStrLn.show $ alphaBeta testBoard2 ([], 0) (-iNFINITY, iNFINITY) 1 0 Gold True

    resetHash 500
    -- testTiming
    testMCTS

    {-
    putStrLn $ displayBoard testBoard2 True
    res <- MTDf.search testBoard2 20
    putStrLn $ showMove res

    putStrLn $ displayBoard testBoard5 True
    putStrLn $ show $ eval testBoard5 Gold

    putStrLn $ displayBoard testBoard2 True
    res <- alphaBeta testBoard2 [] (-iNFINITY, iNFINITY) 10 0 Gold True
    putStrLn $ showMove res
    -}

    infoHash

startSilver, startGold :: String
startSilver = "ra8 rb8 rc8 rd8 re8 rf8 rg8 rh8 ha7 db7 cc7 ed7 me7 cf7 dg7 hh7 "
startGold   = "Ra1 Rb1 Rc1 Rd1 Re1 Rf1 Rg1 Rh1 Ha2 Db2 Cc2 Md2 Ee2 Cf2 Dg2 Hh2 "

testBoard, testBoard2, testBoard3, testBoard4, testBoard5
    :: Board
testBoard  = parseBoard Gold $ startSilver ++ startGold
testBoard2 = parseBoard Gold "Rb3 Ra3 Mf4 dg4 db2 re8"
testBoard3 = fst $ makeMove testBoard2
                             [ Step Rabbit Gold (bit 22) (bit 21)
                             , Step Dog Silver (bit 14) (bit 22)]
testBoard4 = parseBoard Gold "Ra3 Mf4 dg4 db3 re8"
testBoard5 = parseBoard Gold "Rc1 Rf1 rf8"
