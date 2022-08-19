module Content.Path exposing (Path, format, join, parse, toList)

{-| This module is a lazy copy of some path module code.
It currently doesn't support Windows systems.
-}

import Regex


sep : String
sep =
    "/"


type alias Path =
    { root : Maybe String
    , dir : String
    , base : String
    , ext : String
    , name : String
    }


toList : Path -> List String
toList path =
    case path.dir of
        "" ->
            String.split sep path.base

        _ ->
            String.split sep path.dir ++ String.split sep path.base


parse : String -> Result String Path
parse str =
    let
        pathRegex : Regex.Regex
        pathRegex =
            Maybe.withDefault Regex.never
                (Regex.fromString "^(\\/?|)([\\s\\S]*?)((?:\\.{1,2}|[^\\/]+?|)(\\.[^.\\/]*|))(?:[\\/]*)$")
    in
    case Regex.findAtMost 1 pathRegex str of
        match :: [] ->
            case match.submatches of
                part1 :: part2 :: part3 :: part4 :: [] ->
                    Ok
                        { root = part1
                        , dir = Maybe.withDefault "" part1 ++ String.slice 0 -1 (Maybe.withDefault "" part2)
                        , base = Maybe.withDefault "" part3
                        , ext = Maybe.withDefault "" part4
                        , name = String.slice 0 (String.length (Maybe.withDefault "" part3) - String.length (Maybe.withDefault "" part4)) (Maybe.withDefault "" part3)
                        }

                _ ->
                    Err ("Unable to parse the file path `" ++ str ++ "`")

        _ ->
            Err ("Unable to parse the file path `" ++ str ++ "`")


normaliseArray : List String -> Bool -> List String
normaliseArray pieces allowAboveRoot =
    List.reverse
        (List.foldl
            (\piece normalised ->
                if piece == "." || piece == "" then
                    normalised

                else if piece == ".." then
                    if not (List.isEmpty normalised) && List.head normalised /= Just ".." then
                        List.drop 1 normalised

                    else if allowAboveRoot then
                        ".." :: normalised

                    else
                        normalised

                else
                    piece :: normalised
            )
            []
            pieces
        )


normalise : String -> String
normalise pathStr =
    let
        isAbsolute : Bool
        isAbsolute =
            String.left 1 pathStr == sep

        trailingSlash : Bool
        trailingSlash =
            String.right 1 pathStr == sep

        normalisedPath : String
        normalisedPath =
            normaliseArray (String.split sep pathStr) (not isAbsolute)
                |> String.join sep

        path : String
        path =
            if String.isEmpty normalisedPath && not isAbsolute then
                "."

            else
                normalisedPath
    in
    String.join ""
        [ if isAbsolute then
            "/"

          else
            ""
        , path
        , if not (String.isEmpty path) && trailingSlash then
            sep

          else
            ""
        ]


format : Path -> String
format path =
    case path.dir of
        "" ->
            path.base

        _ ->
            path.dir ++ sep ++ path.base


join : List String -> String
join paths =
    normalise (String.join sep paths)
