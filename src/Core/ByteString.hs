{-# LANGUAGE FlexibleInstances #-}
module Core.ByteString where

import qualified Data.ByteString.Char8            as BS
import qualified Data.Map                         as M
import qualified Core.Parser                      as P
import qualified Network.HTTP.Types.URI           as URI
import qualified Data.ByteString.UTF8             as UTF8

class StringFamily a where
    convert :: a -> BS.ByteString
instance StringFamily BS.ByteString where
    convert bs = bs
instance StringFamily String where
    convert = UTF8.fromString

type QueryString = M.Map BS.ByteString BS.ByteString

parse :: Char -> P.Parser [(BS.ByteString, BS.ByteString)]
-- ^ Parser for pair
parse splitter = P.sepBy parsePair (P.char splitter)
  where
    spaces = P.skipWhile P.isHorizontalSpace
    parsePair = do
        key <- decode <$> (spaces *> P.noneOf1 " =" <* spaces <* P.char '=')
        value <- decode <$> (spaces *> P.noneOf1 (splitter : " ") <* spaces)
        return (key, value)
    decode = URI.urlDecode True

splitAndDecode :: Char -> BS.ByteString -> QueryString
-- ^ Split the given string and construct the Map
splitAndDecode mark bs = case P.parseOnly (parse mark) bs of
    Right val -> M.fromList val
    Left _ -> M.empty
