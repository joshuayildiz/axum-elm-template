module Pages.Login exposing (Event(..), Model, Msg, init, update, view)

import Api
import Api.Types exposing (AuthError(..), UserResponse)
import Components.Button as Button
import Components.Card as Card
import Components.Input as Input
import Html exposing (Html, form, h1, p, text)
import Html.Attributes exposing (class, disabled, type_)
import Html.Events exposing (onSubmit)
import Http


type alias Model =
    { email : String
    , password : String
    , error : Maybe String
    , submitting : Bool
    }


type Msg
    = EmailChanged String
    | PasswordChanged String
    | SubmitLogin
    | GotLogin (Result Http.Error (Result AuthError UserResponse))


{-| Events the login page reports back to the router.
-}
type Event
    = NoEvent
    | LoggedIn UserResponse


init : Model
init =
    { email = "", password = "", error = Nothing, submitting = False }


update : Msg -> Model -> ( Model, Cmd Msg, Event )
update msg model =
    case msg of
        EmailChanged email ->
            ( { model | email = email }, Cmd.none, NoEvent )

        PasswordChanged password ->
            ( { model | password = password }, Cmd.none, NoEvent )

        SubmitLogin ->
            ( { model | submitting = True, error = Nothing }
            , Api.login { email = model.email, password = model.password } GotLogin
            , NoEvent
            )

        GotLogin (Ok (Ok user)) ->
            ( { model | submitting = False, password = "", error = Nothing }
            , Cmd.none
            , LoggedIn user
            )

        GotLogin (Ok (Err authError)) ->
            ( { model | submitting = False, error = Just (authErrorMessage authError) }
            , Cmd.none
            , NoEvent
            )

        GotLogin (Err httpError) ->
            ( { model | submitting = False, error = Just (Api.errorToString httpError) }
            , Cmd.none
            , NoEvent
            )


authErrorMessage : AuthError -> String
authErrorMessage error =
    case error of
        InvalidCredentials ->
            "Incorrect email or password."

        AccountDeactivated ->
            "This account is deactivated."

        NotSignedIn ->
            "You are not signed in."


view : Model -> Html Msg
view model =
    Card.view
        [ form [ class "flex flex-col gap-5", onSubmit SubmitLogin ]
            [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text "Sign in" ]
            , Input.view
                { label = "Email"
                , type_ = "email"
                , placeholder = "you@example.com"
                , value = model.email
                , onInput = EmailChanged
                }
            , Input.view
                { label = "Password"
                , type_ = "password"
                , placeholder = "Your password"
                , value = model.password
                , onInput = PasswordChanged
                }
            , viewError model.error
            , Button.primary [ type_ "submit", disabled model.submitting ]
                [ text
                    (if model.submitting then
                        "Signing in..."

                     else
                        "Sign in"
                    )
                ]
            ]
        ]


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Just message ->
            p [ class "text-[13px] text-red-600" ] [ text message ]

        Nothing ->
            text ""
