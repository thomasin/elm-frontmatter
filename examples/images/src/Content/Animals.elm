module Content.Animals exposing (CollectionItem, cheetah, CollectionItem, mouse, CollectionItem, yellowEyedPenguin)

type alias CollectionItem  =
    {name : String, photo : String, attribution : String, link : String}
{-| Auto-generated from file animals/[cheetah]/content.md-}
cheetah : CollectionItem
cheetah  =
    {name = "Cheetah", photo = "public/images/animals/[cheetah]/cheetah.jpeg", attribution = "\"Cheetah\" by Ullisan is licensed under CC BY-ND 2.0.", link = "https://www.flickr.com/photos/12122501@N00/5636712193"}
{-| Auto-generated from file animals/[mouse]/content.md-}
mouse : CollectionItem
mouse  =
    {name = "Computer Mouse", photo = "public/images/animals/[mouse]/computer_mouse.jpeg", attribution = "\"Computer mouse\" by Pockafwye is licensed under CC BY-NC 2.0.", link = "https://www.flickr.com/photos/10668055@N00/239304886"}
{-| Auto-generated from file animals/[yellow-eyed-penguin]/content.md-}
yellowEyedPenguin : CollectionItem
yellowEyedPenguin  =
    {name = "Yellow Eyed Penguin", photo = "public/images/animals/[yellow-eyed-penguin]/penguin.jpeg", attribution = "\"Yellow-eyed penguin, manchot antipode à la péninsule d'Otago, sortant dîner au coucher du soleil\" by TonioSkipper is licensed under CC BY-NC-ND 2.0.", link = "https://www.flickr.com/photos/115180558@N03/16079862970"}