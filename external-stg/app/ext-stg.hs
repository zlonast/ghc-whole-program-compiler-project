import           Control.Applicative         (Applicative (..), (<$>))
import           Control.Monad

import           Data.Bool                   (not)
import qualified Data.ByteString.Lazy        as BSL
import           Data.Function               (($), (.))
import           Data.List                   (isSuffixOf)
import           Data.Monoid                 (Monoid (..), (<>))
import           Data.String                 (String)
import qualified Data.Text.IO                as T
import           Data.Tuple                  (fst)

import           Options.Applicative         (CommandFields, InfoMod, Mod, Parser)
import           Options.Applicative.Builder (argument, command, help, info, long, metavar, progDesc, str, subparser,
                                              switch)
import           Options.Applicative.Extra   (execParser, helper)

import           Stg.IO                      (decodeStgbin, modpakStgbinPath, readModpakL)
import           Stg.Pretty                  (Config (..), pShowWithConfig, pprModule)

import           System.IO                   (FilePath, IO)

modes :: Parser (IO ())
modes = subparser
    (  mode "show" showMode (progDesc "print Stg")
    )
  where
    mode :: String -> Parser a -> InfoMod a -> Mod CommandFields a
    mode name f opts = command name (info (helper <*> f) opts)

    modpakFile :: Parser FilePath
    modpakFile = argument str (metavar "MODPAK_OR_STGBIN" <> help "pretty prints external stg from .modpak or .stgbin file")

    showMode :: Parser (IO ())
    showMode =
        run <$> modpakFile <*> switch (long "hide-tickish" <> help "do not print STG IR Tickish annotation")
      where
        run fname hideTickish = do
            dump <- case () of
              _ | "modpak" `isSuffixOf` fname -> readModpakL fname modpakStgbinPath decodeStgbin
              _ | "stgbin" `isSuffixOf` fname -> decodeStgbin <$> BSL.readFile fname
              _                               -> fail "unknown file format"
            let cfg = Config
                  { cfgPrintTickish = not hideTickish
                  }
            T.putStrLn . fst . pShowWithConfig cfg $ pprModule dump

main :: IO ()
main = join $ execParser $ info (helper <*> modes) mempty
