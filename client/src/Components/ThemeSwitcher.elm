module Components.ThemeSwitcher exposing (Theme(..), fromString, toString, view)

import Html exposing (Html, option, select, text)
import Html.Attributes exposing (class, selected, value)
import Html.Events exposing (on, targetValue)
import I18n exposing (T)
import Json.Decode as Decode


type Theme
    = System
    | Light
    | Dark


all : List Theme
all =
    [ System, Light, Dark ]


toString : Theme -> String
toString theme =
    case theme of
        System ->
            "system"

        Light ->
            "light"

        Dark ->
            "dark"


fromString : String -> Theme
fromString value =
    case value of
        "light" ->
            Light

        "dark" ->
            Dark

        _ ->
            System


label : T -> Theme -> String
label t theme =
    case theme of
        System ->
            t.themeSystem

        Light ->
            t.themeLight

        Dark ->
            t.themeDark


view : T -> Theme -> (Theme -> msg) -> Html msg
view t current onSelect =
    select
        [ on "change" (Decode.map (fromString >> onSelect) targetValue)
        , class "cursor-pointer rounded-lg border border-border bg-card px-2 py-1 text-[12px] font-medium text-muted-foreground transition-colors hover:border-ring focus:border-ring focus:outline-none"
        ]
        (List.map (viewOption t current) all)


viewOption : T -> Theme -> Theme -> Html msg
viewOption t current theme =
    option
        [ value (toString theme)
        , selected (theme == current)
        ]
        [ text (label t theme) ]
