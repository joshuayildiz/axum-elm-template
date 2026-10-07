module Components.Account exposing (Event(..), Model, Msg, Tab(..), init, update, view)

import Api
import Api.Types exposing (AuthError(..), PasswordError(..), TotpSetup)
import Components.Button as Button
import Components.Input as Input
import Html exposing (Html, button, code, div, form, h2, img, p, span, text)
import Html.Attributes as Attr exposing (alt, class, disabled, src, type_)
import Html.Events exposing (onClick, onSubmit)
import Http
import I18n exposing (T)


type Tab
    = PasswordTab
    | SecurityTab


type PwOutcome
    = PwOk
    | PwErr PasswordError
    | PwFail


type CodeOutcome
    = CodeBad
    | CodeFail


type Notice
    = EnabledNow
    | DisabledNow


type alias Model =
    { tab : Tab
    , totpEnabled : Bool
    , currentPassword : String
    , newPassword : String
    , passwordOutcome : Maybe PwOutcome
    , savingPassword : Bool
    , setup : Maybe TotpSetup
    , code : String
    , codeOutcome : Maybe CodeOutcome
    , working : Bool
    , disablePassword : String
    , disableOutcome : Maybe PwOutcome
    , notice : Maybe Notice
    }


init : Tab -> Bool -> Model
init tab totpEnabled =
    { tab = tab
    , totpEnabled = totpEnabled
    , currentPassword = ""
    , newPassword = ""
    , passwordOutcome = Nothing
    , savingPassword = False
    , setup = Nothing
    , code = ""
    , codeOutcome = Nothing
    , working = False
    , disablePassword = ""
    , disableOutcome = Nothing
    , notice = Nothing
    }


type Msg
    = SwitchTab Tab
    | Dismiss
    | CurrentPasswordChanged String
    | NewPasswordChanged String
    | SubmitPassword
    | GotPassword (Result Http.Error (Result PasswordError ()))
    | StartSetup
    | GotSetup (Result Http.Error TotpSetup)
    | CodeChanged String
    | SubmitEnable
    | GotEnable (Result Http.Error (Result AuthError ()))
    | DisablePasswordChanged String
    | SubmitDisable
    | GotDisable (Result Http.Error (Result PasswordError ()))


type Event
    = NoEvent
    | Close
    | TotpChanged Bool


update : Msg -> Model -> ( Model, Cmd Msg, Event )
update msg model =
    case msg of
        SwitchTab tab ->
            ( { model | tab = tab }, Cmd.none, NoEvent )

        Dismiss ->
            ( model, Cmd.none, Close )

        CurrentPasswordChanged value ->
            ( { model | currentPassword = value, passwordOutcome = Nothing }, Cmd.none, NoEvent )

        NewPasswordChanged value ->
            ( { model | newPassword = value, passwordOutcome = Nothing }, Cmd.none, NoEvent )

        SubmitPassword ->
            ( { model | savingPassword = True, passwordOutcome = Nothing }
            , Api.changePassword
                { currentPassword = model.currentPassword, newPassword = model.newPassword }
                GotPassword
            , NoEvent
            )

        GotPassword (Ok (Ok ())) ->
            ( { model
                | savingPassword = False
                , currentPassword = ""
                , newPassword = ""
                , passwordOutcome = Just PwOk
              }
            , Cmd.none
            , NoEvent
            )

        GotPassword (Ok (Err error)) ->
            ( { model | savingPassword = False, passwordOutcome = Just (PwErr error) }, Cmd.none, NoEvent )

        GotPassword (Err _) ->
            ( { model | savingPassword = False, passwordOutcome = Just PwFail }, Cmd.none, NoEvent )

        StartSetup ->
            ( { model | working = True, codeOutcome = Nothing, notice = Nothing }
            , Api.totpSetup GotSetup
            , NoEvent
            )

        GotSetup (Ok setup) ->
            ( { model | working = False, setup = Just setup, code = "", codeOutcome = Nothing }, Cmd.none, NoEvent )

        GotSetup (Err _) ->
            ( { model | working = False, codeOutcome = Just CodeFail }, Cmd.none, NoEvent )

        CodeChanged value ->
            ( { model | code = value, codeOutcome = Nothing }, Cmd.none, NoEvent )

        SubmitEnable ->
            case model.setup of
                Just setup ->
                    ( { model | working = True, codeOutcome = Nothing }
                    , Api.totpEnable { secret = setup.secret, code = model.code } GotEnable
                    , NoEvent
                    )

                Nothing ->
                    ( model, Cmd.none, NoEvent )

        GotEnable (Ok (Ok ())) ->
            ( { model
                | working = False
                , totpEnabled = True
                , setup = Nothing
                , code = ""
                , codeOutcome = Nothing
                , notice = Just EnabledNow
              }
            , Cmd.none
            , TotpChanged True
            )

        GotEnable (Ok (Err InvalidCode)) ->
            ( { model | working = False, codeOutcome = Just CodeBad }, Cmd.none, NoEvent )

        GotEnable (Ok (Err _)) ->
            ( { model | working = False, codeOutcome = Just CodeFail }, Cmd.none, NoEvent )

        GotEnable (Err _) ->
            ( { model | working = False, codeOutcome = Just CodeFail }, Cmd.none, NoEvent )

        DisablePasswordChanged value ->
            ( { model | disablePassword = value, disableOutcome = Nothing }, Cmd.none, NoEvent )

        SubmitDisable ->
            ( { model | working = True, disableOutcome = Nothing }
            , Api.totpDisable { password = model.disablePassword } GotDisable
            , NoEvent
            )

        GotDisable (Ok (Ok ())) ->
            ( { model
                | working = False
                , totpEnabled = False
                , disablePassword = ""
                , disableOutcome = Nothing
                , notice = Just DisabledNow
              }
            , Cmd.none
            , TotpChanged False
            )

        GotDisable (Ok (Err error)) ->
            ( { model | working = False, disableOutcome = Just (PwErr error) }, Cmd.none, NoEvent )

        GotDisable (Err _) ->
            ( { model | working = False, disableOutcome = Just PwFail }, Cmd.none, NoEvent )


view : T -> Model -> Html Msg
view t model =
    div [ class "fixed inset-0 z-50 flex items-center justify-center p-4" ]
        [ div [ class "absolute inset-0 bg-zinc-900/30", onClick Dismiss ] []
        , div [ class "relative z-10 flex w-full max-w-md flex-col gap-5 rounded-2xl border border-zinc-200/70 bg-white p-6 shadow-xl" ]
            [ viewHeader t
            , viewTabs t model.tab
            , case model.tab of
                PasswordTab ->
                    viewPassword t model

                SecurityTab ->
                    viewSecurity t model
            ]
        ]


viewHeader : T -> Html Msg
viewHeader t =
    div [ class "flex items-center justify-between" ]
        [ h2 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.account ]
        , button
            [ onClick Dismiss
            , class "rounded-md px-2 py-1 text-[13px] font-medium text-zinc-500 transition-colors hover:bg-zinc-100 hover:text-zinc-900"
            ]
            [ text t.close ]
        ]


viewTabs : T -> Tab -> Html Msg
viewTabs t active =
    div [ class "flex gap-1 rounded-lg bg-zinc-100 p-1" ]
        [ tabButton t.changePassword (active == PasswordTab) (SwitchTab PasswordTab)
        , tabButton t.twoFactor (active == SecurityTab) (SwitchTab SecurityTab)
        ]


tabButton : String -> Bool -> Msg -> Html Msg
tabButton label isActive onSelect =
    button
        [ onClick onSelect
        , class
            (if isActive then
                "flex-1 rounded-md bg-white px-3 py-1.5 text-[13px] font-medium text-zinc-900 shadow-sm"

             else
                "flex-1 rounded-md px-3 py-1.5 text-[13px] font-medium text-zinc-500 transition-colors hover:text-zinc-900"
            )
        ]
        [ text label ]


viewPassword : T -> Model -> Html Msg
viewPassword t model =
    form [ class "flex flex-col gap-4", onSubmit SubmitPassword ]
        [ Input.view
            { label = t.currentPassword
            , type_ = "password"
            , placeholder = t.loginPasswordPlaceholder
            , value = model.currentPassword
            , onInput = CurrentPasswordChanged
            }
        , Input.view
            { label = t.newPassword
            , type_ = "password"
            , placeholder = t.atLeast8
            , value = model.newPassword
            , onInput = NewPasswordChanged
            }
        , viewPwOutcome t t.passwordUpdated model.passwordOutcome
        , Button.primary [ type_ "submit", disabled model.savingPassword ] [ text t.updatePassword ]
        ]


viewSecurity : T -> Model -> Html Msg
viewSecurity t model =
    if model.totpEnabled then
        viewDisable t model

    else
        case model.setup of
            Just setup ->
                viewEnroll t model setup

            Nothing ->
                div [ class "flex flex-col gap-4" ]
                    [ p [ class "text-[13px] text-zinc-500" ] [ text t.twoFactorOff ]
                    , viewNotice t model.notice
                    , Button.primary [ type_ "button", onClick StartSetup, disabled model.working ] [ text t.setUp ]
                    ]


viewEnroll : T -> Model -> TotpSetup -> Html Msg
viewEnroll t model setup =
    form [ class "flex flex-col gap-4", onSubmit SubmitEnable ]
        [ p [ class "text-[13px] text-zinc-500" ] [ text t.twoFactorIntro ]
        , div [ class "flex justify-center" ]
            [ img
                [ src setup.qrPng
                , alt t.twoFactor
                , class "h-44 w-44 rounded-lg border border-zinc-200"
                ]
                []
            ]
        , div [ class "flex flex-col gap-1" ]
            [ span [ class "text-[10px] font-medium uppercase tracking-[0.16em] text-zinc-400" ] [ text t.twoFactorSecretLabel ]
            , code [ class "break-all rounded-md bg-zinc-100 px-2 py-1.5 font-mono text-[12px] text-zinc-700" ] [ text setup.secret ]
            ]
        , Input.view
            { label = t.code
            , type_ = "text"
            , placeholder = t.codePlaceholder
            , value = model.code
            , onInput = CodeChanged
            }
        , viewCodeOutcome t model.codeOutcome
        , Button.primary [ type_ "submit", disabled model.working ] [ text t.turnOn ]
        ]


viewDisable : T -> Model -> Html Msg
viewDisable t model =
    form [ class "flex flex-col gap-4", onSubmit SubmitDisable ]
        [ p [ class "text-[13px] text-zinc-500" ] [ text t.twoFactorOn ]
        , viewNotice t model.notice
        , Input.view
            { label = t.currentPassword
            , type_ = "password"
            , placeholder = t.loginPasswordPlaceholder
            , value = model.disablePassword
            , onInput = DisablePasswordChanged
            }
        , viewPwOutcome t "" model.disableOutcome
        , Button.secondary [ type_ "submit", disabled model.working ] [ text t.turnOff ]
        ]


viewPwOutcome : T -> String -> Maybe PwOutcome -> Html Msg
viewPwOutcome t okText outcome =
    case outcome of
        Just PwOk ->
            p [ class "text-[13px] text-emerald-600" ] [ text okText ]

        Just (PwErr IncorrectPassword) ->
            p [ class "text-[13px] text-red-600" ] [ text t.errIncorrectPassword ]

        Just (PwErr PasswordTooShort) ->
            p [ class "text-[13px] text-red-600" ] [ text t.errPasswordTooShort ]

        Just PwFail ->
            p [ class "text-[13px] text-red-600" ] [ text t.couldNotLoad ]

        Nothing ->
            text ""


viewCodeOutcome : T -> Maybe CodeOutcome -> Html Msg
viewCodeOutcome t outcome =
    case outcome of
        Just CodeBad ->
            p [ class "text-[13px] text-red-600" ] [ text t.authInvalidCode ]

        Just CodeFail ->
            p [ class "text-[13px] text-red-600" ] [ text t.couldNotLoad ]

        Nothing ->
            text ""


viewNotice : T -> Maybe Notice -> Html Msg
viewNotice t notice =
    case notice of
        Just EnabledNow ->
            p [ class "text-[13px] text-emerald-600" ] [ text t.twoFactorEnabledMsg ]

        Just DisabledNow ->
            p [ class "text-[13px] text-emerald-600" ] [ text t.twoFactorDisabledMsg ]

        Nothing ->
            text ""
