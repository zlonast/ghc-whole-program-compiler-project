module Stg.IO
    ( -- * Convenient Modpak IO
      readModpakS
    , readModpakL
    , doesModpakEntryExist
      -- * Convenient Decoding
    , decodeStgbin
    , decodeStgbin'
    , decodeStgbinInfo
    , decodeStgbinStubs
    , decodeStgbinModuleName
      -- .fullpak and .modpak content structure
    , fullpakAppInfoPath
    , modpakHaskellSourcePath
    , modpakStgbinPath
    ) where

import           Codec.Archive.Zip    (doesEntryExist, getEntry, mkEntrySelector, withArchive)

import           Control.Applicative  ((<$>))

import           Data.Binary          (decode)
import           Data.Bool            (Bool)
import qualified Data.ByteString      as BS
import qualified Data.ByteString.Lazy as BSL
import           Data.Function        (($), (.))
import           Data.Maybe           (Maybe)
import           Data.String          (String)

import           Stg.Reconstruct      (reconModule)
import           Stg.Syntax           (Module, ModuleName, Name, SForeignStubs, SModule, UnitId)

import           System.IO            (FilePath, IO)

-- from .modpak file

readModpakS :: FilePath -> String -> (BS.ByteString -> a) -> IO a
readModpakS modpakPath fname f = do
  s <- mkEntrySelector fname
  f <$> withArchive modpakPath (getEntry s)

readModpakL :: FilePath -> String -> (BSL.ByteString -> a) -> IO a
readModpakL modpakPath fname f = do
  s <- mkEntrySelector fname
  f . BSL.fromStrict <$> withArchive modpakPath (getEntry s)

doesModpakEntryExist :: FilePath -> String -> IO Bool
doesModpakEntryExist modpakPath fname = do
  s <- mkEntrySelector fname
  withArchive modpakPath $ doesEntryExist s

-- from bytestring

decodeStgbin' :: BSL.ByteString -> SModule
decodeStgbin' = decode

decodeStgbin :: BSL.ByteString -> Module
decodeStgbin = reconModule . decodeStgbin'

decodeStgbinInfo :: BSL.ByteString -> (Name, UnitId, ModuleName, Maybe Name, SForeignStubs, Bool, [(UnitId, [ModuleName])])
decodeStgbinInfo = decode

decodeStgbinStubs :: BSL.ByteString -> (Name, UnitId, ModuleName, Maybe Name, SForeignStubs)
decodeStgbinStubs = decode

decodeStgbinModuleName :: BSL.ByteString -> (Name, UnitId, ModuleName, Maybe Name)
decodeStgbinModuleName = decode

-- .modpak and .fullpak structure

modpakStgbinPath :: FilePath
modpakStgbinPath = "module.stgbin"

modpakHaskellSourcePath :: FilePath
modpakHaskellSourcePath = "module.hs"

fullpakAppInfoPath :: FilePath
fullpakAppInfoPath = "app.info"
