module Pages.Root exposing (Event(..), Msg, update, view)

import Api
import Api.Types exposing (UserResponse)
import Components.Button as Button
import Components.Card as Card
import Html exposing (Html, div, h1, span, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http


type Msg
    = ClickLogout
    | GotLogout (Result Http.Error ())


{-| Events the root page reports back to the router.
-}
type Event
    = NoEvent
    | LoggedOut


update : Msg -> ( Cmd Msg, Event )
update msg =
    case msg of
        ClickLogout ->
            ( Api.logout GotLogout, NoEvent )

        GotLogout _ ->
            -- Log out on the client even if the request failed. The cookie is
            -- short lived, so a lost logout call still ends the session soon.
            ( Cmd.none, LoggedOut )


view : UserResponse -> Html Msg
view user =
    Card.view
        [ div [ class "flex flex-col gap-6" ]
            [ h1 [ class "text-lg font-semibold tracking-tight text-zinc-900" ] [ text "Your account" ]
            , div [ class "flex flex-col gap-3" ]
                [ row "Email" user.email
                , row "Name" (Maybe.withDefault "—" user.name)
                , row "Admin"
                    (if user.isAdmin then
                        "yes"

                     else
                        "no"
                    )
                ]
            , Button.secondary [ onClick ClickLogout ] [ text "Log out" ]
            ]
        ]


row : String -> String -> Html Msg
row key val =
    div [ class "flex justify-between text-sm" ]
        [ span [ class "text-zinc-500" ] [ text key ]
        , span [ class "text-zinc-900" ] [ text val ]
        ]
