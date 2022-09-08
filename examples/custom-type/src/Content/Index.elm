module Content.Index exposing (Content, content)

import Content


type alias Content =
    { title : String, currentPage : Content.Page, body : String }


{-| Auto-generated from file index.md
-}
content : Content
content =
    { title = "Home page", currentPage = Content.HomePage, body = """Welcome to my web page
""" }
