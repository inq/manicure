{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}
{-# LANGUAGE OverloadedStrings #-}
module Core.HtmlSpec where

import qualified Data.ByteString.Char8            as BS
import qualified Data.ByteString.UTF8             as UTF8
import Core.Html
import SpecHelper

spec :: Spec
spec =
  describe "Core.HtmlSpec" $ do
    context "Token parser" $ do
      it "parses simple string" $
        [parse|html
          div { class: 'hello', id: "hihi" }
            | hi
          |] `shouldBe` UTF8.fromString "<html><div class=\"hello\" id=\"hihi\">hi</div></html>"
    context "UTF-8 Text" $ do
      it "parses simple utf-8" $
        [parse|html
          div
            | 안녕
          |] `shouldBe` UTF8.fromString "<html><div>안녕</div></html>"
    context "Simple Text" $ do
      it "parses simple tag" $
        [parse|html
          div
            | Hello
          |] `shouldBe` "<html><div>Hello</div></html>"
      it "parses simple variable" $
        [parse|html
          div
            = theValue
          |] `shouldBe` "<html><div>VALUE</div></html>"
      it "parses simple tag" $
        [parse|html
          div
            | Hello
          |] `shouldBe` "<html><div>Hello</div></html>"
      it "processes simple foreach statement" $
        [parse|html
          - foreach people -> name, title
            div
              p
                = name
              p
                = title
          |] `shouldBe` "<html><div><p>A</p><p>B</p></div></html>"
    context "External File" $ do
      it "parses simple partial" $
        [parse|html
          p
            - render simple.qh
          |] `shouldBe` "<html><p><div>Hello</div><span class=\"hihi\">ho?</span></p></html>"
      it "parses simple variable" $
        [parse|html
          ul
            - foreach people -> name, title
              - render variable.qh
          |] `shouldBe` "<html><ul><li><span>A</span><pan>B</pan></li></ul></html>"
    context "If statement" $ do
      it "parses true statement" $
        [parse|html
          div
            - if trueStatement
              p
                | Hello
          |] `shouldBe` "<html><div><p>Hello</p></div></html>"
      it "parses false statement" $
        [parse|html
          div
            - if falseStatement
              p
                | Hello
          |] `shouldBe` "<html><div></div></html>"
      it "applies true function" $
        [parse|html
          div
            - if greaterThan four three
              p
                | Hello
          |] `shouldBe` "<html><div><p>Hello</p></div></html>"
      it "applies false function" $
        [parse|html
          div
            - if greaterThan three four
              p
                | Hello
          |] `shouldBe` "<html><div></div></html>"
 where
  theValue = "VALUE" :: BS.ByteString
  people = [["A", "B"] :: [BS.ByteString]]
  trueStatement = True
  falseStatement = False
  greaterThan = (>) :: Integer -> Integer -> Bool
  three = 3 :: Integer
  four = 4 :: Integer

main :: IO ()
main = hspec spec
