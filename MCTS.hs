{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP          #-}
#ifdef ENGINE
module Main (main) where
import AEI
#else
module MCTS (
    MMTree(..),
    TreeNode(..),
    newSearch,
    improveTree,
    descendByUCB1,
    valueUCB,
    createNode,
) where
#endif

import Control.Applicative ((<$>))
import Control.Concurrent
import Bits.BitRepresentation
import Eval.BitEval
import Eval.MonteCarloEval


#ifdef ENGINE
main :: IO ()
main = runAEIInterface newSearch
#endif

-- | Mini-Max Tree representation
data MMTree = MT { board     :: !Board
                 , movePhase :: !MovePhase
                 , treeNode  :: !TreeNode
                 , step :: (Step, Step)
                 } deriving (Show, Eq)

data TreeNode = Leaf
              | Node { children   :: [MMTree] -- ^ possible steps from this
                     , value      :: !Double  -- ^ actual value of this node
                     , visitCount :: !Int
                     } deriving (Show, Eq)

stepCount :: MMTree -> Int
stepCount = snd . movePhase

player :: MMTree -> Player
player = fst . movePhase

iNFINITY' :: Num a => a
iNFINITY' = iNFINITY * iNFINITY

newSearch :: Int -> IO (Board -> MVar (DMove, Int) -> IO ())
newSearch _ = return search

search :: Board             -- ^ starting position
       -> MVar (DMove, Int) -- ^ best results to store here
       -> IO ()
search b = search' MT { board = b
                      , movePhase = (mySide b, 0)
                      , treeNode = Leaf
                      , step = (Pass, Pass)
                      }

search' :: MMTree -> MVar (DMove, Int) -> IO ()
search' !mt mvar = do
        (mt',score) <- improveTree mt
        _ <- move `seq` swapMVar mvar (move,0)
        -- putStrLn $ "info actual " ++ show (move,score)
        search' mt' mvar
    where
        move = constructMove mt 4

constructMove :: MMTree -> Int -> DMove
constructMove _ 0 = []
constructMove (MT { treeNode = Leaf }) _ = []
constructMove !mt !n = (s `seq` subTreeMove) `seq` s : subTreeMove
    where
        mt' = fst $ descendByUCB1 mt
        s = step mt'
        subTreeMove = constructMove mt' (n-1)

improveTree :: MMTree -> IO (MMTree, Double)
improveTree mt
    | treeNode mt == Leaf = do
        val <- normaliseValue . (* (mySide (board mt) <#> Gold))
               <$> getValueByMC (board mt) (movePhase mt)
        return (createNode mt val, val)

    -- immobilization
    | rest == [] && movePhase mt == movePhase node = do
        inf <- normaliseValue
               <$> evalImmobilised (board mt) (player mt)
        return ( mt { treeNode = Node
                        { value = inf
                        , visitCount = visitCount root + 1
                        , children = []
                        }
                    }
               , inf)
    -- TODO test +/-

    | otherwise = do
        (nodeNew, improvement) <- improveTree node

        return ( mt { treeNode = Node
                        { value    = value root + improvement
                        , visitCount = visitCount root + 1
                        , children = nodeNew : rest
                        }
                    }
               , improvement)
    where
        (node, rest) = descendByUCB1 mt
        root = treeNode mt

createNode :: MMTree -> Double -> MMTree
createNode mt val =
        mt { treeNode =
                Node { children = map (leafFromStep mt) steps
                     , value = val
                     , visitCount = 1
                     }
           }
    where
        steps = generateSteps (board mt) (player mt) (stepCount mt < 3)

leafFromStep :: MMTree -> (Step, Step) -> MMTree
leafFromStep mt s@(s1,s2) =
    MT { board = fst $ makeMove (board mt) [s1,s2]
       , movePhase = stepInMove (movePhase mt) s2
       , treeNode = Leaf
       , step = s
       }

-- | if immobilised returns (first_argument, [])
descendByUCB1 :: MMTree -> (MMTree, [MMTree])
descendByUCB1 mt = case chs of
                    [] -> (mt, []) -- immobilization
                    _  -> descendByUCB1' chs (visitCount $ treeNode mt)
    where
        chs = (children $ treeNode mt)

-- TODO badly ordered rest of children
--      speedup
-- | first argument have to be not empty
descendByUCB1' :: [MMTree] -> Int -> (MMTree, [MMTree])
descendByUCB1' mms nb =
        proj $ foldr (accumUCB nb) (hMms, valueUCB hMms nb, []) (tail mms)
    where
        hMms = head mms
        proj (a,_,c) = (a,c)

accumUCB :: Int -> MMTree -> (MMTree, Double, [MMTree])
         -> (MMTree, Double, [MMTree])
accumUCB count mt (best, bestValue, rest)
        | nodeVal > bestValue = (mt, nodeVal, best:rest)
        | otherwise = (best, bestValue, mt:rest)
    where
        nodeVal = valueUCB mt count

valueUCB :: MMTree -> Int -> Double
valueUCB mt count =
        case tn of
            Leaf -> iNFINITY'
            n@Node { children = [] } -> value n
            _ -> (value tn / nb) + 0.01 * sqrt (log cn / nb)
    where
        tn = treeNode mt
        [nb,cn] = map fromIntegral [visitCount tn, count]

normaliseValue :: Int -> Double
normaliseValue v = 2/(1 + exp (-0.0003 * fromIntegral v)) - 1
