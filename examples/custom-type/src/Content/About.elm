module Content.About exposing (Content, content)

import Content


type alias Content =
    { title : String, currentPage : Content.Page, body : String }


{-| Auto-generated from file about.md
-}
content : Content
content =
    { title = "About page", currentPage = Content.AboutPage, body = """All about me
""" }
