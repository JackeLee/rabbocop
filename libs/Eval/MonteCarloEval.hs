module Eval.MonteCarloEval (getValueByMC) where

import Bits.BitRepresentation
import Eval.BitEval
import System.Random
import Control.Applicative ((<$>))


depth, simulations :: Int
depth       =  16 -- ^ simulation depth
simulations =  50 -- ^ number of simulations

getValueByMC :: Board -> MovePhase -> IO Int
getValueByMC b mp = do
    s <- mapM (randomSimulation mp depth) $ replicate simulations b
    return $ sum s `div` simulations
-- TODO 1/1+e^{-\lambda x} -> change ints to doubles
-- near optimal: Plot[1/(1+e^(-0.0003x)), {y, 0,1}, {x, -10000, 10000}]

-- TODO +/- 1 discussion on empty steps
randomSimulation :: MovePhase -> Int -> Board -> IO Int
randomSimulation (pl,_) 0 b = eval b pl
randomSimulation mp@(pl,sc) d b =
    case generateSteps b pl (sc < 2) of
        [] -> evalImmobilised b pl
        xs -> do
            (s1,s2) <- chooseRandomly xs
            randomSimulation (stepInMove mp s2) (d-1) (fst $ makeMove b [s1,s2])

chooseRandomly :: [a] -> IO a
chooseRandomly xs = (xs !!) <$> randomRIO (0, length xs - 1)

-- TODO makeMove could be rewriten by makeStep
-- TODO measuring length is ineficient
