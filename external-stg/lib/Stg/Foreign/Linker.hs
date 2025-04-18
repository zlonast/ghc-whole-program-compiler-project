module Stg.Foreign.Linker where

import           Control.Applicative (Applicative (..))
import           Control.Monad       (Monad (..))

import           Data.Bool           (Bool (..))
import           Data.Eq             (Eq (..))
import           Data.Function       (($), (.))
import Data.Functor (Functor(..))
import           Data.List           (concat, concatMap, filter, intercalate, unlines, unwords, (++))

import           Stg.Foreign.Stubs   (genStubs)
import           Stg.Program         (StgAppLinkerInfo (..), StgLibLinkerInfo (..), getAppLinkerInfo)

import           System.Directory    (createDirectoryIfMissing, makeAbsolute)
import           System.FilePath     (FilePath, takeBaseName, takeDirectory, (</>))
import           System.IO           (IO, writeFile)
import           System.Process      (callCommand)

import           Text.Printf         (printf)
import           Text.Show           (Show (..))

getExtStgWorkDirectory :: FilePath -> IO FilePath
getExtStgWorkDirectory ghcstgappFname = do
  absFname <- makeAbsolute ghcstgappFname
  pure $ takeDirectory absFname </> ".ext-stg-work" </> takeBaseName ghcstgappFname

linkForeignCbitsSharedLib :: FilePath -> IO ()
linkForeignCbitsSharedLib ghcstgappFname = do

  workDir <- getExtStgWorkDirectory ghcstgappFname
  createDirectoryIfMissing True workDir

  let stubFname = workDir </> "stub.c"
  genStubs ghcstgappFname >>= writeFile stubFname

  (StgAppLinkerInfo{..}, linkerInfoList') <- getAppLinkerInfo ghcstgappFname
  let linkerInfoList = filter (\StgLibLinkerInfo{..} -> stglibName /= "rts") linkerInfoList'

      cbitsOpts =
          [ unwords $ concat
            [ [ "-L" ++ dir | dir <- stglibExtraLibDirs]
            , stglibLdOptions
            , [ "-l" ++ lib | lib <- stglibExtraLibs]
            ]
          | StgLibLinkerInfo{..} <- linkerInfoList
          ]

      cbitsArs = concatMap stglibCbitsPaths linkerInfoList

      stubArs = concatMap stglibCapiStubsPaths linkerInfoList

      arList = cbitsArs ++ stubArs
      {-
      arList = case cbitsArs ++ stubArs of
          []  -> []
          l   -> case stgappPlatformOS of
                  "darwin"  -> ["-Wl,-all_load"] ++ l
                  _         -> ["-Wl,--whole-archive"] ++ l ++ ["-Wl,--no-whole-archive"]
      -}

      stubOpts =
          [ "-fPIC"
          , "stub.c"
          ]

      appOpts = unwords $ concat
        [ [ "-L" ++ dir | dir <- stgappExtraLibDirs]
        , stgappLdOptions
        , [ "-l" ++ lib | lib <- stgappExtraLibs]
        ]

      linkScript =
        unlines
          [ "#!/usr/bin/env bash"
          , "set -e"
          , case stgappPlatformOS of
              "darwin" -> "gcc -o cbits.so -shared \\"
              _        -> "gcc -o cbits.so -shared -Wl,--no-as-needed \\"
          ] ++
        intercalate " \\\n" (fmap ("  " ++) . filter (/= "") $ arList ++ cbitsOpts ++ stgappCObjects ++ [appOpts] ++ stubOpts) ++ "\n"

  let scriptFname = workDir </> "cbits.so.sh"
  writeFile scriptFname linkScript
  callCommand $ printf "(cd %s; bash cbits.so.sh)" (show workDir)
