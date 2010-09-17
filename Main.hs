module Main where

import Data.Array ((!))
import System.IO
import BitRepresenation
import Hash (resetHash)
import MTDf

ltrim :: String -> String
ltrim = dropWhile (== ' ')

firstWord :: String -> (String, String)
firstWord str = f [] $ ltrim str
    where
        f word [] = (word, [])
        f word (s:ss) | s == ' '  = (word, ss)
                      | otherwise = f (word ++ [s]) ss

getValue :: Read a => String -> a
getValue str = case firstWord str of
                    ("value", rest) -> read rest
                    _ -> read str

data Game = Game { timePerMove :: Int, startingReserve :: Int
                 , percentUnusedToReserve :: Int, maxReserve :: Int
                 , maxLenghtOfGame :: Int, maxTurns :: Int, maxTurnTime :: Int
                 , quit :: Bool, board :: Board, playerColor :: Player
                 , hashSize :: Int}
                 deriving (Show)


aei_setposition :: Game -> String -> Game
aei_setposition game flatBoard = game { playerColor = playerFromChar $ head col
                                      , board = newBoard }
    where
        (col, flatBoard') = firstWord flatBoard
        -- tail to skip '['
        newBoard = createBoard.fst $ foldr f ([],-1) $ tail $ ltrim flatBoard'

        f char (steps, count) = if char == ']' then ([],-1) else
            ((playerFromChar char, pieceFromChar char, count+1):steps, count+1)

aei_makemove :: Game -> String -> Game
aei_makemove game move
        | (hash.board) game == 0 = game { board = parseBoard move }
        | (whole (board game)) ! Silver == 0 = game { board = fst board2 }
        | otherwise =  game { board = fst board1 }
    where
        board1 = makeMove (board game) $ filter notTrapping $ map parseStep $ words move
        board2 = makeMove (board game) $ map (positionToStep.parsePosition) $ words move

        notTrapping (Step _ _ _ to) = to /= 0
        notTrapping _ = True

startSilver, startGold :: String
startSilver = "ra8 rb8 rc8 rd8 re8 rf8 rg8 rh8 ha7 db7 cc7 ed7 me7 cf7 dg7 hh7 "
startGold   = "Ra1 Rb1 Rc1 Rd1 Re1 Rf1 Rg1 Rh1 Ha2 Db2 Cc2 Md2 Ee2 Cf2 Dg2 Hh2 "

aei_go :: Game -> IO Game
aei_go game | hash (board game) == 0 = do
                putStrLn ("bestmove " ++ startGold)
                return game
            | (whole (board game)) ! Silver == 0 = do
                putStrLn ("bestmove " ++ startSilver)
                return game { playerColor = Silver }
            | otherwise = do
                (pv, val) <- search (board game) (playerColor game) time
                putStrLn $ "info bestscore " ++ show val
                putStrLn $ "bestmove " ++ (unwords $ map show $ justOneMove pv 0)
                return game
    where
        -- TODO osetrit hodne specialni pripady, kdy engine neodehraje 4 kroky
        justOneMove :: Move -> Int -> Move
        justOneMove []       _ = []
        justOneMove (Pass:_) _ = []
        justOneMove (s@(Step _ _ _ to):xs) count
                | to == 0   = s:(justOneMove xs count)
                | count < 4 = s:(justOneMove xs (count+1))
                | otherwise = []

        time | (timePerMove game) < 20 = (timePerMove game) `div` 2
             | otherwise               = 3*(timePerMove game) `div` 4

action :: String -> String -> Game -> IO Game
action str line game = case str of
    "aei" -> putStrLn "protocol-version 1\nid name Rabbocop\nid author JackeLee\naeiok"
             >> return game
    "isready" -> putStrLn "readyok" -- TODO init
                 >> return game
    "setoption" ->
        case firstWord line of
            ("name", line') ->
                case firstWord line' of
                    ("tcmove", time)    -> return game { timePerMove = getValue time }
                    ("tcreserve", time) -> return game { startingReserve = getValue time}
                    ("tcpercent", time) -> return game { percentUnusedToReserve = getValue time }
                    ("tcmax", time)     -> return game { maxReserve = getValue time }
                    ("tctotal", time)   -> return game { maxLenghtOfGame = getValue time }
                    ("tcturns", turns)  -> return game { maxTurns = getValue turns }
                    ("tcturntime", time)-> return game { maxTurnTime = getValue time }

                    ("hash",size) -> do
                            let size' = getValue size
                            resetHash size'
                            return game { hashSize = size' }
                    {-
                    ("greserve",_) -> return game
                    ("sreserve",_) -> return game
                    ("gused",_) -> return game
                    ("sused",_) -> return game
                    ("lastmoveused",_) -> return game
                    ("moveused",_) -> return game
                    ("opponent",_) -> return game
                    ("opponent_rating",_) -> return game
                    ("rating",_) -> return game
                    ("rated",_) -> return game
                    ("event",_) -> return game
                    ("depth",_) -> return game
                    -}
                    _ -> putStrLn "log Warning: unsupported setoption" >> return game
            _ -> putStrLn "log Error: corrupted 'setoption name <id> [value <x>]' command"
                 >> return game
    "newgame"     -> return game { board = parseBoard "", playerColor = Gold }
    "setposition" -> return $ aei_setposition game line
    "makemove"    -> return $ aei_makemove game line
    "go" -> if (fst.firstWord) line == "ponder"
                then return game
                else aei_go game
    -- "stop" -> -- jak?
    "quit" -> return $ game { quit = True }
    _ -> putStrLn "log Error: unknown command" >> return game

communicate :: Game -> IO ()
communicate game = game `seq` do
    hFlush stdout
    l <- getLine
    (str, line) <- return $ firstWord l
    game' <- action str line game
    if quit game'
        then return ()
        else communicate game'

main :: IO ()
main = do
    resetHash 0
    communicate game
    where
        game = Game { timePerMove = 20, startingReserve = 20
                    , percentUnusedToReserve = 100, maxReserve = 10
                    , maxLenghtOfGame = -1, maxTurns = -1, maxTurnTime = -1
                    , quit = False, board = parseBoard "", playerColor = Gold
                    , hashSize = 100 }
