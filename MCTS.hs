{-# LANGUAGE BangPatterns #-}
module MCTS (
    MMTree(..),
    TreeNode(..),
    search,
    improveTree,
    descendByUCB1,
    createNode,
) where

import Control.Concurrent
import BitRepresentation
import BitEval
import MonteCarloEval


-- | Mini-Max Tree representation
data MMTree = MT { board     :: !Board
                 , movePhase :: !MovePhase
                 , treeNode  :: !TreeNode
                 , step :: (Step, Step)
                 } deriving (Show, Eq)

data TreeNode = Leaf
              | Node { children :: [MMTree] -- ^ possible steps from this
                     , value    :: !Int     -- ^ actual value of this node
                     , number   :: !Int     -- ^ visits count
                     } deriving (Show, Eq)

stepCount :: MMTree -> Int
stepCount = snd . movePhase

player :: MMTree -> Player
player = fst . movePhase

iNFINITY' :: Num a => a
iNFINITY' = iNFINITY * iNFINITY

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
        _ <- move `seq` swapMVar mvar (move,score)
        putStrLn $ "info actual " ++ show (move,score)
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

improveTree :: MMTree -> IO (MMTree, Int)
improveTree mt
    | treeNode mt == Leaf = do
        val <- getValueByMC (board mt) (movePhase mt)
        return (createNode mt (val * (player mt <#> Gold)), val)

    -- immobilization
    | rest == [] && movePhase mt == movePhase node = do
        e <- eval (board mt) (player mt)
        let inf' = inf e
        return ( mt { treeNode = Node
                        { value = inf'
                        , number = number root + 1
                        , children = []
                        }
                    }
               , inf')

    | otherwise = do
        (nodeNew, improvement) <- improveTree node
        let improvement' = player mt <#> Gold * improvement

        return ( mt { treeNode = Node
                        { value    = value root + improvement'
                        , number   = number root + 1
                        , children = nodeNew : rest
                        }
                    }
               , improvement)
    where
        (node, rest) = descendByUCB1 mt
        root = treeNode mt
        inf ev | ev >= iNFINITY || ev <= -iNFINITY = ev
               | otherwise = player mt <#> Silver * iNFINITY


createNode :: MMTree -> Int -> MMTree
createNode mt val =
        mt { treeNode =
                Node { children = map (leafFromStep mt) steps
                     , value = val
                     , number = 1
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
                    _  -> descendByUCB1' chs (number $ treeNode mt)
    where
        chs = (children $ treeNode mt)

-- TODO badly ordered rest of children
--      speedup
descendByUCB1' :: [MMTree] -> Int -> (MMTree, [MMTree])
descendByUCB1' (m:mts) nb =
        proj $ foldr (accumUCB nb) (m, valueUCB m nb, []) mts
	where
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
            _ -> - (vl / nb) + sqrt (2 * log cn / nb)
    where
        tn = treeNode mt
        [vl,nb,cn] = map fromIntegral [value tn, number tn, count]
