module Content.Index exposing (Content, content)
import Content.Animals  
type alias Content  =
    {title : String, animals : List Content.Animals.CollectionItem}
{-| Auto-generated from file index.md-}
content : Content
content  =
    {title = "Some animals", animals = [Content.Animals.cheetah, Content.Animals.mouse, Content.Animals.yellowEyedPenguin]}