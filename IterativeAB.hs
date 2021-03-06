{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP          #-}
#ifdef ENGINE
module Main (main) where
import AEI
#else
module IterativeAB (newSearch) where
#endif

import AlphaBeta
import Bits.BitRepresentation (Board(..), DMove)
import Computation
import Eval.BitEval (iNFINITY)

import Control.Applicative ((<$>))
#ifdef VERBOSE
import System.IO (hFlush, stdout)
#endif
#if CORES <= 1
import Control.Concurrent (MVar, swapMVar)
#endif


newSearch :: Int  -- ^ table size
          -> IO (Board -> MVar (DMove, String) -> IO ComputationToken)
#if CORES > 1
newSearch tableSize = iterativeP <$> newHTables tableSize
#else
newSearch tableSize = iterative <$> newHTables tableSize
#endif

#if CORES > 1
{- | Divide and conquer parallel alphaBeta with iterative deepening.
 - We create a worker thread which manages work for cores. If any thread ends
 - () is pushed into lock (MVar). This action wakes up worker which
 - starts new deeper searching.
 -}
iterativeP :: ABTables -> Board -> MVar (DMove, String) -> IO ComputationToken
iterativeP tt board mvar = do
        -- pool for threads ids
        threads <- newMVar []

        -- if work is done, this lock gets value
        lock <- newMVar ()

        -- place to store initial final result
        mvarInt <- newMVar ([],0)

        -- everything is ready so let the worker begins
        _ <- forkIO $ worker threads lock 1 mvarInt

        -- the Compucation module needs to know all threads Ids
        return threads
    where
        worker threads lock depth mvarInt = do
            -- sleep until work is fulfilled
            _ <- takeMVar lock

            -- it is necessary to save the value before deeper computation
            -- starts
            modifyMVar_ mvar $ \_ -> do
                (pv,sc) <- readMVar mvarInt
                return (pv, show sc ++ " depth:" ++ show depth)

            -- kill old working threads and start new search
            mapM_ killThread =<< readMVar threads
            alphaBetaParallel board tt (-iNFINITY, iNFINITY)
                              depth (mySide board, 0)
                              mvarInt threads lock

            -- everyone is working, I can go to sleep!
            worker threads lock (depth+1) mvarInt

-- CORES == 1:
#else

-- | iterative deepening
iterative :: ABTables -> Board -> MVar (DMove, String) -> IO ()
iterative tt board mvar = search' 1 ([], 0)
    where
        search' :: Int -> (DMove, Int) -> IO ()
        search' !depth best = do
#ifdef VERBOSE
            putStrLn $ "info actual " ++ show best
            hFlush stdout
#endif
#ifdef WINDOW
            let val = snd best
            let win = (val-WINDOW, val+WINDOW)
            n@(_,val') <- alphaBeta board tt win depth (mySide board,0)

            m@(pv,sc) <-
                if val' < fst win || snd win < val'
                    then alphaBeta board tt (-iNFINITY, iNFINITY)
                                   depth (mySide board, 0)
                    else return n
#else
            m@(pv,sc) <- alphaBeta board tt (-iNFINITY, iNFINITY)
                                   depth (mySide board, 0)
#endif
            _ <- m `seq` swapMVar mvar (pv, show sc ++ " depth:" ++ show depth)
            search' (depth+1) m

#endif

#ifdef ENGINE
main :: IO ()
main = runAEIInterface newSearch
#endif
