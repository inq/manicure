{-# LANGUAGE TemplateHaskell      #-}
{-# LANGUAGE QuasiQuotes          #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE OverloadedStrings    #-}
module Core.Route where

import qualified Data.ByteString.Char8            as BS
import qualified Language.Haskell.TH.Quote        as TQ
import qualified Language.Haskell.TH.Syntax       as TS
import qualified Core.Request                     as Req
import qualified Core.Response                    as Res
import qualified Data.Map.Strict                  as M
import qualified Core.Parser                      as P

data Routes = Routes [Route]
data Route = Route String {-# UNPACK #-} !Req.Method String
data RouteTree = Node (M.Map BS.ByteString RouteTree) (M.Map Req.Method Res.Handler)
    deriving Show

instance TS.Lift Route where
    lift (Route uri method action) = [|
            makeNode uriTokens method $(return $ TS.VarE $ TS.mkName action)
        |]
      where
        split _ [] "" = []
        split _ [] r = [r]
        split c (char : chars) ""
            | char == c    = split c chars ""
            | otherwise    = split c chars [char]
        split c (char : chars) r
            | char == c    = r : split c chars ""
            | otherwise    = split c chars (r ++ [char])
        uriTokens = filter (/= "") $ split '/' uri ""
instance TS.Lift Routes where
    lift (Routes a) = 
        [| foldl1 mergeNode a |]

mergeNode :: RouteTree -> RouteTree -> RouteTree
-- ^ Merge two nodes
mergeNode (Node a ha) (Node b hb) =
    Node (M.unionWith mergeNode a b) (M.union ha hb)

makeNode :: [BS.ByteString] -> Req.Method -> Res.Handler -> RouteTree
-- ^ Parsing the given ByteStrings, make a route chain
makeNode (str : strs) method action = 
    Node (M.singleton str $ makeNode strs method action) M.empty
makeNode [] method action =
    Node M.empty $ M.singleton method action

match :: BS.ByteString -> Req.Method -> RouteTree -> Maybe Res.Action
-- ^ Find a corresponding route from the given request URI
match uri method tree =
    case M.lookup method _map of
        Just res -> Just $ res $ reverse args
        Nothing  -> Nothing
  where
    (Node _ _map, args) = findNode uriTokens tree []
    uriTokens = filter (not . BS.null) $ BS.split '/' uri
    findNode (_head : _tail) (Node children _) params = 
        case M.lookup _head children of
            Just a  -> findNode _tail a params
            Nothing -> case M.lookup "#String" children of
                Just a -> findNode _tail a (_head : params)
                Nothing -> (Node M.empty M.empty, [])
    findNode [] node params = (node, params)
    
parseFile :: FilePath -> TS.Q TS.Exp
-- ^ Parse the route definition file
parseFile filePath = do
     TS.qAddDependentFile filePath
     s <- TS.qRunIO $ readFile filePath
     TQ.quoteExp parse s

parse :: TQ.QuasiQuoter
-- ^ A QuasiQuoter for parsing the route definition
parse = TQ.QuasiQuoter 
    { TQ.quoteExp = quoteExp
    , TQ.quotePat = undefined
    , TQ.quoteType = undefined
    , TQ.quoteDec = undefined
    }
  where
    quoteExp str = 
        case P.parseOnly routesNode (BS.pack str) of
            Left _ -> undefined
            Right tag -> [| tag |]

routeNode :: P.Parser Route
-- ^ The subparser
routeNode = do
    _ <- P.many $ P.char '\n'
    uri <- P.noneOf1 " "
    _ <- P.many1 $ P.char ' '
    method <- P.noneOf1 " "
    _ <- P.many $ P.char ' '
    action <- P.noneOf1 "\n"
    _ <- P.many $ P.char '\n'
    return $ Route (BS.unpack uri) (Req.strToMethod $ BS.unpack method) $ BS.unpack action

routesNode :: P.Parser Routes
-- ^ The main parser
routesNode = do
    routes <- P.many routeNode
    return $ Routes routes
