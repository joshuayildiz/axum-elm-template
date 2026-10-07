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
import I18n exposing (T)


{-| Why a sign-in failed. The view turns it into a localized message, so the
model holds the cause, not the words.
-}
type Error
    = AuthFailed AuthError
    | HttpFailed Http.Error


type alias Model =
    { email : String
    , password : String
    , error : Maybe Error
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
            ( { model | submitting = False, error = Just (AuthFailed authError) }
            , Cmd.none
            , NoEvent
            )

        GotLogin (Err httpError) ->
            ( { model | submitting = False, error = Just (HttpFailed httpError) }
            , Cmd.none
            , NoEvent
            )


errorMessage : T -> Error -> String
errorMessage t error =
    case error of
        AuthFailed authError ->
            authErrorMessage t authError

        HttpFailed httpError ->
            Api.errorToString t httpError


authErrorMessage : T -> AuthError -> String
authErrorMessage t error =
    case error of
        InvalidCredentials ->
            t.authInvalid

        AccountDeactivated ->
            t.authDeactivated

        NotSignedIn ->
            t.authNotSignedIn


view : T -> Model -> Html Msg
view t model =
    Card.view
        [ form [ class "flex flex-col gap-5", onSubmit SubmitLogin ]
            [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.signIn ]
            , Input.view
                { label = t.email
                , type_ = "email"
                , placeholder = t.loginEmailPlaceholder
                , value = model.email
                , onInput = EmailChanged
                }
            , Input.view
                { label = t.password
                , type_ = "password"
                , placeholder = t.loginPasswordPlaceholder
                , value = model.password
                , onInput = PasswordChanged
                }
            , viewError t model.error
            , Button.primary [ type_ "submit", disabled model.submitting ]
                [ text
                    (if model.submitting then
                        t.signingIn

                     else
                        t.signIn
                    )
                ]
            ]
        ]


viewError : T -> Maybe Error -> Html Msg
viewError t maybeError =
    case maybeError of
        Just error ->
            p [ class "text-[13px] text-red-600" ] [ text (errorMessage t error) ]

        Nothing ->
            text ""
