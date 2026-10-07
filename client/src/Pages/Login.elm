module Pages.Login exposing (Event(..), Model, Msg, init, update, view)

import Api
import Api.Types exposing (AuthError(..), LoginResponse(..), UserResponse)
import Browser.Dom as Dom
import Components.Button as Button
import Components.Card as Card
import Components.Input as Input
import Html exposing (Html, div, form, h1, input, p, span, text)
import Html.Attributes exposing (attribute, autofocus, class, disabled, id, type_, value)
import Html.Events exposing (on, onInput, onSubmit)
import Http
import I18n exposing (T)
import Icons
import Json.Decode as Decode
import Task


{-| Why a sign-in failed. The view turns it into a localized message, so the
model holds the cause, not the words.
-}
type Error
    = AuthFailed AuthError
    | HttpFailed Http.Error


type Step
    = Credentials
    | AwaitingCode


type alias Model =
    { email : String
    , password : String
    , code : String
    , step : Step
    , error : Maybe Error
    , submitting : Bool
    }


type Msg
    = EmailChanged String
    | PasswordChanged String
    | DigitChanged Int String
    | DigitKeyDown Int String
    | SubmitLogin
    | SubmitCode
    | GotLogin (Result Http.Error (Result AuthError LoginResponse))
    | NoOp


{-| Events the login page reports back to the router.
-}
type Event
    = NoEvent
    | LoggedIn UserResponse


codeLength : Int
codeLength =
    6


init : Model
init =
    { email = "", password = "", code = "", step = Credentials, error = Nothing, submitting = False }


update : Msg -> Model -> ( Model, Cmd Msg, Event )
update msg model =
    case msg of
        EmailChanged email ->
            ( { model | email = email }, Cmd.none, NoEvent )

        PasswordChanged password ->
            ( { model | password = password }, Cmd.none, NoEvent )

        DigitChanged index raw ->
            let
                digits =
                    String.filter Char.isDigit raw
            in
            if String.isEmpty digits then
                ( { model | code = removeAt index model.code, error = Nothing }
                , focusBox (index - 1)
                , NoEvent
                )

            else if String.length digits > 2 then
                let
                    code =
                        String.left codeLength (String.left index model.code ++ digits)
                in
                ( { model | code = code, error = Nothing }
                , focusBox (String.length code)
                , NoEvent
                )

            else
                let
                    code =
                        String.left codeLength (setAt index (String.right 1 digits) model.code)
                in
                ( { model | code = code, error = Nothing }
                , focusBox (index + 1)
                , NoEvent
                )

        DigitKeyDown index key ->
            if key == "Backspace" && String.isEmpty (digitAt index model.code) && index > 0 then
                ( { model | code = removeAt (index - 1) model.code, error = Nothing }
                , focusBox (index - 1)
                , NoEvent
                )

            else
                ( model, Cmd.none, NoEvent )

        SubmitLogin ->
            ( { model | submitting = True, error = Nothing }
            , Api.login { email = model.email, password = model.password } GotLogin
            , NoEvent
            )

        SubmitCode ->
            ( { model | submitting = True, error = Nothing }
            , Api.loginTotp model.code GotLogin
            , NoEvent
            )

        GotLogin (Ok (Ok (Authenticated { user }))) ->
            ( { model | submitting = False, password = "", code = "", error = Nothing }
            , Cmd.none
            , LoggedIn user
            )

        GotLogin (Ok (Ok TotpRequired)) ->
            ( { model | submitting = False, step = AwaitingCode, password = "", error = Nothing }
            , focusBox 0
            , NoEvent
            )

        GotLogin (Ok (Err authError)) ->
            ( { model | submitting = False, code = "", error = Just (AuthFailed authError) }
            , focusBoxIf (model.step == AwaitingCode) 0
            , NoEvent
            )

        GotLogin (Err httpError) ->
            ( { model | submitting = False, error = Just (HttpFailed httpError) }
            , Cmd.none
            , NoEvent
            )

        NoOp ->
            ( model, Cmd.none, NoEvent )


digitAt : Int -> String -> String
digitAt index code =
    String.slice index (index + 1) code


setAt : Int -> String -> String -> String
setAt index digit code =
    String.left index code ++ digit ++ String.dropLeft (index + 1) code


removeAt : Int -> String -> String
removeAt index code =
    String.left index code ++ String.dropLeft (index + 1) code


boxId : Int -> String
boxId index =
    "otp-" ++ String.fromInt index


focusBox : Int -> Cmd Msg
focusBox index =
    if index >= 0 && index < codeLength then
        Task.attempt (\_ -> NoOp) (Dom.focus (boxId index))

    else
        Cmd.none


focusBoxIf : Bool -> Int -> Cmd Msg
focusBoxIf condition index =
    if condition then
        focusBox index

    else
        Cmd.none


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

        InvalidCode ->
            t.authInvalidCode


view : T -> String -> Model -> Html Msg
view t companyName model =
    div [ class "flex w-full max-w-sm flex-col items-center gap-6" ]
        [ viewBrand companyName
        , case model.step of
            Credentials ->
                viewCredentials t model

            AwaitingCode ->
                viewCode t model
        ]


viewBrand : String -> Html Msg
viewBrand name =
    div [ class "flex items-center gap-2.5" ]
        [ div [ class "flex h-8 w-8 items-center justify-center rounded-lg bg-zinc-900 text-sm font-bold text-white" ]
            [ text (String.toUpper (String.left 1 name)) ]
        , span [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text name ]
        ]


viewCredentials : T -> Model -> Html Msg
viewCredentials t model =
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


viewCode : T -> Model -> Html Msg
viewCode t model =
    Card.view
        [ form [ class "flex flex-col items-center gap-6", onSubmit SubmitCode ]
            [ div [ class "flex h-12 w-12 items-center justify-center rounded-full bg-zinc-900 text-white" ]
                [ Icons.security ]
            , div [ class "flex flex-col items-center gap-1.5 text-center" ]
                [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.twoFactor ]
                , p [ class "max-w-[16rem] text-[13px] leading-relaxed text-zinc-500" ] [ text t.enterCode ]
                ]
            , div [ class "flex gap-2" ]
                (List.map (viewDigit model.code) (List.range 0 (codeLength - 1)))
            , viewError t model.error
            , Button.primary [ type_ "submit", disabled (model.submitting || String.length model.code < codeLength) ]
                [ text
                    (if model.submitting then
                        t.signingIn

                     else
                        t.verify
                    )
                ]
            ]
        ]


viewDigit : String -> Int -> Html Msg
viewDigit code index =
    input
        [ id (boxId index)
        , type_ "text"
        , attribute "inputmode" "numeric"
        , attribute "autocomplete"
            (if index == 0 then
                "one-time-code"

             else
                "off"
            )
        , autofocus (index == 0)
        , value (digitAt index code)
        , onInput (DigitChanged index)
        , on "keydown" (Decode.map (DigitKeyDown index) (Decode.field "key" Decode.string))
        , class "h-12 w-11 rounded-xl border border-zinc-200 bg-zinc-50/50 text-center text-xl font-semibold text-zinc-900 transition-colors focus:border-zinc-900 focus:bg-white focus:outline-none focus:ring-0"
        ]
        []


viewError : T -> Maybe Error -> Html Msg
viewError t maybeError =
    case maybeError of
        Just error ->
            p [ class "text-[13px] text-red-600" ] [ text (errorMessage t error) ]

        Nothing ->
            text ""
