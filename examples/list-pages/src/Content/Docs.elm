module Content.Docs exposing (CollectionItem, Content, content, gettingStarted, pages, routes)

import Markdown.Block


type alias Content =
    { title : String, sections : List CollectionItem }


type alias CollectionItem =
    { title : String, slug : String, body : List Markdown.Block.Block }


{-| Auto-generated from file docs.md
-}
content : Content
content =
    { title = "Docs", sections = [ gettingStarted, routes, pages ] }


{-| Auto-generated from file docs/[01-getting-started].md
-}
gettingStarted : CollectionItem
gettingStarted =
    { title = "Getting Started", slug = "getting-started", body = [ Markdown.Block.Heading Markdown.Block.H3 [ Markdown.Block.Text "Installation" ], Markdown.Block.Paragraph [ Markdown.Block.Text "Install using ", Markdown.Block.CodeSpan "npm install package" ], Markdown.Block.Heading Markdown.Block.H3 [ Markdown.Block.Text "Setup" ], Markdown.Block.Paragraph [ Markdown.Block.Text "Setup with ", Markdown.Block.CodeSpan "npm run setup" ] ] }


{-| Auto-generated from file docs/[03-pages].md
-}
pages : CollectionItem
pages =
    { title = "Pages", slug = "pages", body = [ Markdown.Block.Heading Markdown.Block.H3 [ Markdown.Block.Text "Pages" ], Markdown.Block.Paragraph [ Markdown.Block.Text "There are 200 different page types to choose from" ] ] }


{-| Auto-generated from file docs/[02-routes].md
-}
routes : CollectionItem
routes =
    { title = "Routes", slug = "routes", body = [ Markdown.Block.Heading Markdown.Block.H3 [ Markdown.Block.Text "Directory structure" ], Markdown.Block.Paragraph [ Markdown.Block.Text "Routes are created from files" ] ] }
