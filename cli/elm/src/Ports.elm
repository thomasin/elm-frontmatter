port module Ports exposing (add, writeFiles, noMoreInputFiles, show, terminate, performEffect, effectsPerformed)

import Json.Decode
import Json.Encode


port add : (Json.Decode.Value -> msg) -> Sub msg


port noMoreInputFiles : (Int -> msg) -> Sub msg


port effectsPerformed : (String -> msg) -> Sub msg


port performEffect : { filePath : String, actions : List { with : String, args : Json.Encode.Value } } -> Cmd msg


port action : List { with : String, args : Json.Encode.Value } -> Cmd msg


port writeFiles : List { filePath : String, fileContents : String } -> Cmd msg
 

port terminate : String -> Cmd msg


port processAsContentFile : String -> Cmd msg


port show : List { level : String, message : String } -> Cmd msg
