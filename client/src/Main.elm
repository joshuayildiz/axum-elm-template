module Main exposing (main)

import Api
import Api.Types exposing (HelloResponse, helloResponseEncoder)
import Browser
import Html exposing (Html, button, div, h1, pre, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Encode


type alias Model =
    { status : Status }


type Status
    = Idle
    | Loading
    | Loaded HelloResponse
    | Failed String


type Msg
    = FetchHello
    | GotHello (Result Http.Error HelloResponse)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = Idle }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchHello ->
            ( { model | status = Loading }, Api.getHello GotHello )

        GotHello (Ok hello) ->
            ( { model | status = Loaded hello }, Cmd.none )

        GotHello (Err err) ->
            ( { model | status = Failed (Api.errorToString err) }, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "flex min-h-screen flex-col items-center justify-center gap-6 bg-slate-900 text-slate-100" ]
        [ h1 [ class "text-2xl font-semibold" ] [ text "Axum + Elm" ]
        , button
            [ class "rounded-lg bg-sky-500 px-4 py-2 font-medium text-white hover:bg-sky-400"
            , onClick FetchHello
            ]
            [ text "Fetch hello" ]
        , viewResult model.status
        ]


viewResult : Status -> Html Msg
viewResult status =
    let
        box : String -> Html Msg
        box content =
            pre
                [ class "w-80 overflow-x-auto rounded-lg border border-slate-700 bg-slate-800 p-4 text-sm text-slate-100" ]
                [ text content ]
    in
    case status of
        Idle ->
            box "Click the button to fetch."

        Loading ->
            box "Loading..."

        Loaded hello ->
            box (Json.Encode.encode 4 (helloResponseEncoder hello))

        Failed message ->
            box message
