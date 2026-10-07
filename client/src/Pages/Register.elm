module Pages.Register exposing (Event(..), Model, Msg, init, update, view)

import Api
import Api.Types exposing (RegistrationError(..), UserResponse)
import Components.Button as Button
import Components.Card as Card
import Components.Input as Input
import Html exposing (Html, a, div, form, h1, p, span, text)
import Html.Attributes exposing (class, disabled, href, type_)
import Html.Events exposing (onSubmit)
import Http
import I18n exposing (T)


type Error
    = RegisterFailed RegistrationError
    | HttpFailed Http.Error


type alias Model =
    { email : String
    , password : String
    , name : String
    , error : Maybe Error
    , submitting : Bool
    }


type Msg
    = EmailChanged String
    | PasswordChanged String
    | NameChanged String
    | SubmitRegister
    | GotRegister (Result Http.Error (Result RegistrationError UserResponse))


type Event
    = NoEvent
    | Registered UserResponse


init : Model
init =
    { email = "", password = "", name = "", error = Nothing, submitting = False }


update : Msg -> Model -> ( Model, Cmd Msg, Event )
update msg model =
    case msg of
        EmailChanged email ->
            ( { model | email = email }, Cmd.none, NoEvent )

        PasswordChanged password ->
            ( { model | password = password }, Cmd.none, NoEvent )

        NameChanged name ->
            ( { model | name = name }, Cmd.none, NoEvent )

        SubmitRegister ->
            let
                name =
                    if String.trim model.name == "" then
                        Nothing

                    else
                        Just (String.trim model.name)
            in
            ( { model | submitting = True, error = Nothing }
            , Api.register { email = model.email, password = model.password, name = name } GotRegister
            , NoEvent
            )

        GotRegister (Ok (Ok user)) ->
            ( { model | submitting = False, password = "", error = Nothing }
            , Cmd.none
            , Registered user
            )

        GotRegister (Ok (Err registerError)) ->
            ( { model | submitting = False, error = Just (RegisterFailed registerError) }
            , Cmd.none
            , NoEvent
            )

        GotRegister (Err httpError) ->
            ( { model | submitting = False, error = Just (HttpFailed httpError) }
            , Cmd.none
            , NoEvent
            )


errorMessage : T -> Error -> String
errorMessage t error =
    case error of
        RegisterFailed registerError ->
            registerErrorMessage t registerError

        HttpFailed httpError ->
            Api.errorToString t httpError


registerErrorMessage : T -> RegistrationError -> String
registerErrorMessage t error =
    case error of
        RegistrationDisabled ->
            t.registrationDisabled

        EmailTaken ->
            t.errEmailInUse

        InvalidEmail ->
            t.errUserInvalid

        WeakPassword ->
            t.errUserInvalid


view : T -> String -> Model -> Html Msg
view t companyName model =
    div [ class "flex w-full max-w-sm flex-col items-center gap-6" ]
        [ viewBrand companyName
        , Card.view
            [ form [ class "flex flex-col gap-5", onSubmit SubmitRegister ]
                [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.createAccount ]
                , Input.view
                    { label = t.email
                    , type_ = "email"
                    , placeholder = t.loginEmailPlaceholder
                    , value = model.email
                    , onInput = EmailChanged
                    }
                , Input.view
                    { label = t.name
                    , type_ = "text"
                    , placeholder = t.optionalField
                    , value = model.name
                    , onInput = NameChanged
                    }
                , Input.view
                    { label = t.password
                    , type_ = "password"
                    , placeholder = t.atLeast8
                    , value = model.password
                    , onInput = PasswordChanged
                    }
                , viewError t model.error
                , Button.primary [ type_ "submit", disabled model.submitting ]
                    [ text
                        (if model.submitting then
                            t.creating

                         else
                            t.createAccount
                        )
                    ]
                , p [ class "text-center text-[13px] text-zinc-500" ]
                    [ text (t.haveAccount ++ " ")
                    , a
                        [ href "/login"
                        , class "font-medium text-zinc-900 underline underline-offset-4 hover:text-zinc-600"
                        ]
                        [ text t.signIn ]
                    ]
                ]
            ]
        ]


viewBrand : String -> Html Msg
viewBrand name =
    div [ class "flex items-center gap-2.5" ]
        [ div [ class "flex h-8 w-8 items-center justify-center rounded-lg bg-zinc-900 text-sm font-bold text-white" ]
            [ text (String.toUpper (String.left 1 name)) ]
        , span [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text name ]
        ]


viewError : T -> Maybe Error -> Html Msg
viewError t maybeError =
    case maybeError of
        Just error ->
            p [ class "text-[13px] text-red-600" ] [ text (errorMessage t error) ]

        Nothing ->
            text ""
