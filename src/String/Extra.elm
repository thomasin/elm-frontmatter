module String.Extra exposing (camelize, decapitalize, classify)

import List.Extra as List


{-| Change the case of the first letter of a string to either uppercase or
lowercase, depending of the value of `wantedCase`. This is an internal
function for use in `toSentenceCase` and `decapitalize`.
-}
changeCase : (Char -> Char) -> String -> String
changeCase mutator word =
    String.uncons word
        |> Maybe.map (\( head, tail ) -> String.cons (mutator head) tail)
        |> Maybe.withDefault ""


decapitalize : String -> String
decapitalize =
    changeCase Char.toLower


{-
    classify "-moz-transform" == "MozTransform"
    classify "01-intro\\" == "Intro"
    classify "intro1\\" == "Intro1"
-}
classify : String -> String
classify str =
    let
        removeSymbols : Char -> String -> String
        removeSymbols char word =
            if Char.isAlpha char then
                word ++ String.fromChar char

            else if Char.isDigit char && not (String.isEmpty (String.trim word)) then
                word ++ String.fromChar char

            else
                word ++ " "

    in
    String.toList str
        |> List.foldl removeSymbols ""
        |> String.words
        |> List.map (changeCase Char.toUpper)
        |> String.join ""


{-
    camelize "-moz-transform" == "mozTransform"
    camelize "01-intro\\" == "intro"
-}
camelize : String -> String
camelize str =
    classify str
        |> changeCase Char.toLower







