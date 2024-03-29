{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( renderCountries,
      renderSites,
      renderIndividuals,
      getPandoraConnection,
      Connection
    ) where

import           Eager                 (readEagerSnpCov, readEagerSexDet)

import           Data.Text             (Text, unpack)
import           Data.Word             (Word16)
import           Database.MySQL.Simple (ConnectInfo (..), Connection, Only,
                                        connect, defaultConnectInfo, query_)
import           Prelude               hiding (readFile)
import           System.Environment    (getEnv)
import           System.IO.Strict      (readFile)
import           Text.Layout.Table     (asciiRoundS, column, def, expand, rowsG,
                                        tableString, titlesH)
import Text.Printf (printf)

getPandoraConnection :: String -> Word16 -> String -> String -> IO Connection
getPandoraConnection host port user password = connect defaultConnectInfo {
    connectHost     = host,
    connectUser     = user,
    connectPassword = password,
    connectDatabase = "pandora",
    connectPort     = port
}

renderCountries :: Connection -> IO ()
renderCountries conn = do
    dat <- getCountries
    let colSpecs = replicate 2 (column def def def def)
        tableH = ["Country", "Nr_Inds"]
        tableB = map (\(s, n) -> [unpack s, show n]) dat
    putStrLn $ tableString colSpecs asciiRoundS (titlesH tableH) [rowsG tableB]
  where
    getCountries :: IO [(Text, Int)]
    getCountries = query_ conn
        "SELECT S.Country, COUNT(I.Id) \
        \FROM TAB_Site AS S \
        \LEFT JOIN TAB_Individual AS I ON I.Site = S.Id \
        \WHERE I.Projects LIKE '%MICROSCOPE%' \
        \GROUP BY S.Country"

renderSites :: Connection -> IO ()
renderSites conn = do
    dat <- getSites
    let colSpecs = replicate 3 (column def def def def)
        tableH = ["Site", "Country", "Nr_Inds"]
        tableB = map (\(s, c, n) -> [unpack s, unpack c, show n]) dat
    putStrLn $ tableString colSpecs asciiRoundS (titlesH tableH) [rowsG tableB]
  where
    getSites :: IO [(Text, Text, Int)]
    getSites = query_ conn
        "SELECT S.Full_Site_Id, S.Country, COUNT(I.Id) \
        \FROM TAB_Site AS S \
        \LEFT JOIN TAB_Individual AS I ON I.Site = S.Id \
        \WHERE I.Projects LIKE '%MICROSCOPE%' \
        \GROUP BY S.Full_Site_Id \
        \ORDER BY S.Country"

renderIndividuals :: Connection -> [FilePath] -> IO ()
renderIndividuals conn eagerDirs = do
    dat <- getSites
    eagerSnpCov <- readEagerSnpCov eagerDirs
    eagerSexDet <- readEagerSexDet eagerDirs
    let colSpecs = replicate 9 (column def def def def)
        tableH = ["Individual", "Country", "Nr_Samples", "Total SNPs", "Snps covered", "RateX", "RateY", "RateXerr", "RateYerr"]
        tableB = flip map dat $ \(s, c, n) ->
            let (cStr, tStr) = case lookup (unpack s) eagerSnpCov of
                    Just (c, t) -> (show c, show t)
                    Nothing -> ("n/a", "n/a")
                (rXstr, rYstr, rXeStr, rYeStr) = case lookup (unpack s) eagerSexDet of
                    Just (rX, rY, rXe, rYe) -> (printf "%.2f" rX , printf "%.2f" rY, printf "%.4f" rXe, printf "%.4f" rYe)
                    Nothing -> ("n/a", "n/a", "n/a", "n/a")
            in  [unpack s, unpack c, show n, tStr, cStr, rXstr, rYstr, rXeStr, rYeStr]
    putStrLn $ tableString colSpecs asciiRoundS (titlesH tableH) [rowsG tableB]
  where
    getSites :: IO [(Text, Text, Int)]
    getSites = query_ conn
        "SELECT I.Full_Individual_Id, S.Country, COUNT(Sa.Id) \
        \FROM TAB_Individual AS I \
        \LEFT JOIN TAB_Sample AS Sa ON I.Id = Sa.Individual \
        \LEFT JOIN TAB_Site AS S ON I.Site = S.Id \
        \WHERE Sa.Projects LIKE '%MICROSCOPE%' \
        \GROUP BY I.Full_Individual_Id \
        \ORDER BY I.Full_Individual_Id"

