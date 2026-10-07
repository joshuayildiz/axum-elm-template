module Components.Card exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (class)


{-| A centered white panel with a soft border and shadow, in the quiet style of
the reference pages.
-}
view : List (Html msg) -> Html msg
view children =
    div [ class "w-full max-w-sm rounded-2xl border border-zinc-200/70 bg-white p-6 shadow-sm" ] children
