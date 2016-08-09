{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE EmptyCase         #-}
{-# LANGUAGE FlexibleContexts  #-}
module Core.Html
  ( parse
  ) where

import qualified Data.ByteString.Char8            as BS
import qualified Language.Haskell.TH.Quote        as TQ
import qualified Language.Haskell.TH.Syntax       as TS
import qualified Data.ByteString.UTF8             as UTF8
import qualified Core.Parser                      as P
import Core.Html.Node (Node(..), parseLine)

-- * Data types
data Html
  = Html ![Node]
data Status
  = Child | Sibling | Parent
  deriving Show

-- * Instances
instance TS.Lift Html where
    lift (Html nodes) = [| return $ concat nodes |]

instance TS.Lift Node where
    lift (Tag string attrs nodes) =
     [|  [($(TS.lift $ concat ["<", string]) :: BS.ByteString)]
         ++ $(TS.lift attrs)
         ++ [">"]
         ++ concat $(TS.lift $ nodes)
         ++ [$(TS.lift $ concat ["</", string, ">"])]
      |]
    lift (Foreach vals vs nodes) =
     [| concat $ concatMap
          (\($(return $ (TS.ListP $ map (TS.VarP . TS.mkName) vs))) -> $(TS.lift nodes))
          $(return $ TS.VarE $ TS.mkName vals)
     |]
    lift (If attrs nodes) =
     [| case $(return $
                (foldl (\a b -> TS.AppE a b)
                ((TS.VarE . TS.mkName . head) attrs)
                (map (TS.VarE . TS.mkName) (tail attrs)))) of
          True -> concat nodes
          _ -> [] :: [BS.ByteString]
      |]
    lift (Text a) = [| [a] |]

instance TS.Lift Status where
    lift Child   = [| Child |]
    lift Sibling = [| Sibling |]
    lift Parent  = [| Parent |]

-- * TH

parseNode :: P.Parser Html
-- ^ The main parser
parseNode = do
    (_, res, _) <- buildTree <$> P.many parseLine
    return (Html res)

parse :: TQ.QuasiQuoter
-- ^ Parser for QuasiQUoter
parse = TQ.QuasiQuoter {
        TQ.quoteExp = quoteExp,
        TQ.quotePat = undefined,
        TQ.quoteType = undefined,
        TQ.quoteDec = undefined
    }
  where
    quoteExp str = do
        case P.parseOnly parseNode (UTF8.fromString str) of
            Right tag -> [| tag |]
            Left _    -> undefined

-- * Node

buildTree :: [(Int, Node)] -> (Int, [Node], [(Int, Node)])
-- ^ Using the indent size and node information, build the Node tree.
buildTree ((indent, node) : rest)
    | indent < next = buildTree $ (indent, replace node res) : remaining
    | indent > next = (indent, [node], rest)
    | otherwise  = (indent, (node) : res, remaining)
  where
    (next, res, remaining) = buildTree rest
    replace (Foreach vals val _) = Foreach vals val
    replace (Tag name attr _) = Tag name attr
    replace (If args _) = If args
    replace (Text _) = error "indentation error"
buildTree []  =
    (0, [], [])
