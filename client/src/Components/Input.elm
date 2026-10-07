module Components.Input exposing (Config, view)

import Html exposing (Html, input, label, span, text)
import Html.Attributes as Attr exposing (class)
import Html.Events exposing (onInput)


type alias Config msg =
    { label : String
    , type_ : String
    , placeholder : String
    , value : String
    , onInput : String -> msg
    }


{-| A labelled field. The label is a tiny, wide-tracked uppercase caption and the
field is a borderless input with a single underline that darkens on focus.
-}
view : Config msg -> Html msg
view config =
    label [ class "block" ]
        [ span [ class labelClass ] [ text config.label ]
        , input
            [ Attr.type_ config.type_
            , Attr.placeholder config.placeholder
            , Attr.value config.value
            , onInput config.onInput
            , class inputClass
            ]
            []
        ]


labelClass : String
labelClass =
    "block text-[10px] font-medium uppercase tracking-[0.16em] text-zinc-400"


inputClass : String
inputClass =
    "mt-1.5 w-full border-0 border-b border-zinc-200 bg-transparent px-0 py-1.5 text-sm text-zinc-900 transition-colors placeholder:text-zinc-300 focus:border-zinc-900 focus:outline-none focus:ring-0"
