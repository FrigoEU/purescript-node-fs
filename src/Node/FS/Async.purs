module Node.FS.Async
  ( Callback (..)
  , rename
  , readFile
  , readTextFile
  , writeFile
  , writeTextFile
  , stat
  ) where

import Control.Monad.Eff
import Data.Either
import Data.Foreign
import Data.Function
import Data.Maybe
import Node.Buffer (Buffer(..))
import Node.Encoding
import Node.FS
import Node.FS.Stats
import Node.Path (FilePath())
import Global (Error(..))

type JSCallback = Fn2 Foreign

foreign import runCallbackEff
  "function runCallbackEff (f) {\
  \  return f(); \
  \}" :: forall eff a. Eff eff a -> a

handleCallback :: forall eff a b. (Callback eff a) -> JSCallback a Unit
handleCallback f = mkFn2 $ \err x -> runCallbackEff $ f case parseForeign read err of
  Left err -> Left $ "handleCallback failed: " ++ err
  Right (Just err') -> Left $ show (err' :: Error)
  Right Nothing -> Right x

foreign import fs "var fs = require('fs');" :: 
  { rename :: forall a. Fn3 FilePath FilePath (JSCallback Unit a) Unit
  , readFile :: forall a b opts. Fn3 FilePath { | opts } (JSCallback a b) Unit
  , writeFile :: forall a opts. Fn4 FilePath a { | opts } (JSCallback Unit Unit) Unit
  , stat :: forall a. Fn2 FilePath (JSCallback StatsObj a) Unit
  }

-- |
-- Type synonym for callback functions.
--
type Callback eff a = Either String a -> Eff eff Unit

-- |
-- Renames a file.
-- 
rename :: forall eff. FilePath 
                   -> FilePath
                   -> Callback eff Unit
                   -> Eff (fs :: FS | eff) Unit

rename oldFile newFile cb = return $ runFn3
  fs.rename oldFile newFile (handleCallback cb)

-- |
-- Reads the entire contents of a file returning the result as a raw buffer.
-- 
readFile :: forall eff. FilePath 
                     -> Callback eff Buffer
                     -> Eff (fs :: FS | eff) Unit

readFile file cb = return $ runFn3
  fs.readFile file {} (handleCallback cb)

-- |
-- Reads the entire contents of a text file with the specified encoding.
-- 
readTextFile :: forall eff. Encoding 
                         -> FilePath 
                         -> Callback eff String 
                         -> Eff (fs :: FS | eff) Unit

readTextFile encoding file cb = return $ runFn3
  fs.readFile file { encoding: show encoding } (handleCallback cb)

-- |
-- Writes a buffer to a file.
-- 
writeFile :: forall eff. FilePath 
                      -> Buffer 
                      -> Callback eff Unit 
                      -> Eff (fs :: FS | eff) Unit

writeFile file buff cb = return $ runFn4 
  fs.writeFile file buff {} (handleCallback cb)

-- |
-- Writes text to a file using the specified encoding.
-- 
writeTextFile :: forall eff. Encoding 
                          -> FilePath 
                          -> String 
                          -> Callback eff Unit 
                          -> Eff (fs :: FS | eff) Unit

writeTextFile encoding file buff cb = return $ runFn4 
  fs.writeFile file buff { encoding: show encoding } (handleCallback cb)

-- |
-- Gets file statistics.
-- 
stat :: forall eff. FilePath 
                 -> Callback eff Stats
                 -> Eff (fs :: FS | eff) Unit

stat file cb = return $ runFn2
  fs.stat file (handleCallback $ cb <<< (<$>) Stats)