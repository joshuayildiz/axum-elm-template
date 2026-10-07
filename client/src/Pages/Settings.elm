module Pages.Settings exposing (Event(..), Model, Msg, init, load, update, view)

import Api
import Api.Types exposing (SettingInfo, SettingKind(..))
import Components.Button as Button
import Components.Input as Input
import Html exposing (Html, div, form, h1, input, label, p, span, text)
import Html.Attributes exposing (checked, class, disabled, type_)
import Html.Events exposing (onCheck, onSubmit)
import Http
import I18n exposing (T)


type Remote a
    = Loading
    | Loaded a
    | Failed


type Notice
    = None
    | Saved
    | SaveFailed


type alias Model =
    { settings : Remote (List SettingInfo)
    , submitting : Bool
    , notice : Notice
    }


type Msg
    = GotSettings (Result Http.Error (List SettingInfo))
    | SetValue String String
    | Submit
    | Done (Result Http.Error ())


type Event
    = NoEvent
    | SettingsSaved


init : Model
init =
    { settings = Loading, submitting = False, notice = None }


load : Cmd Msg
load =
    Api.listSettings GotSettings


update : Msg -> Model -> ( Model, Cmd Msg, Event )
update msg model =
    case msg of
        GotSettings (Ok settings) ->
            ( { model | settings = Loaded settings }, Cmd.none, NoEvent )

        GotSettings (Err _) ->
            ( { model | settings = Failed }, Cmd.none, NoEvent )

        SetValue name value ->
            case model.settings of
                Loaded settings ->
                    ( { model | settings = Loaded (setValue name value settings), notice = None }
                    , Cmd.none
                    , NoEvent
                    )

                _ ->
                    ( model, Cmd.none, NoEvent )

        Submit ->
            case model.settings of
                Loaded settings ->
                    ( { model | submitting = True, notice = None }
                    , Api.updateSettings { settings = List.map toUpdate settings } Done
                    , NoEvent
                    )

                _ ->
                    ( model, Cmd.none, NoEvent )

        Done (Ok ()) ->
            ( { model | submitting = False, notice = Saved }, Cmd.none, SettingsSaved )

        Done (Err _) ->
            ( { model | submitting = False, notice = SaveFailed }, Cmd.none, NoEvent )


setValue : String -> String -> List SettingInfo -> List SettingInfo
setValue name value =
    List.map
        (\setting ->
            if setting.name == name then
                { setting | value = value }

            else
                setting
        )


toUpdate : SettingInfo -> { name : String, value : String }
toUpdate setting =
    { name = setting.name, value = setting.value }


view : T -> Model -> Html Msg
view t model =
    div [ class "flex w-full max-w-lg flex-1 flex-col gap-5" ]
        [ div [ class "flex flex-col gap-1" ]
            [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.settings ]
            , p [ class "text-[13px] text-zinc-500" ] [ text t.settingsIntro ]
            ]
        , case model.settings of
            Loading ->
                p [ class "text-sm text-zinc-500" ] [ text t.loading ]

            Failed ->
                p [ class "text-sm text-zinc-500" ] [ text t.couldNotLoad ]

            Loaded settings ->
                viewForm t model settings
        ]


viewForm : T -> Model -> List SettingInfo -> Html Msg
viewForm t model settings =
    form [ class "flex flex-col gap-5", onSubmit Submit ]
        (List.map (viewSetting t) settings
            ++ [ viewNotice t model.notice
               , div [ class "w-40" ]
                    [ Button.primary [ type_ "submit", disabled model.submitting ] [ text t.save ] ]
               ]
        )


viewSetting : T -> SettingInfo -> Html Msg
viewSetting t setting =
    case setting.kind of
        Bool ->
            label [ class "flex items-center gap-2.5" ]
                [ input
                    [ type_ "checkbox"
                    , checked (setting.value == "true")
                    , onCheck
                        (\isChecked ->
                            SetValue setting.name
                                (if isChecked then
                                    "true"

                                 else
                                    "false"
                                )
                        )
                    , class "h-4 w-4 rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900"
                    ]
                    []
                , span [ class "text-[13px] font-medium text-zinc-800" ] [ text (settingLabel t setting.name) ]
                ]

        Text ->
            Input.view
                { label = settingLabel t setting.name
                , type_ = "text"
                , placeholder = ""
                , value = setting.value
                , onInput = SetValue setting.name
                }


viewNotice : T -> Notice -> Html Msg
viewNotice t notice =
    case notice of
        None ->
            text ""

        Saved ->
            p [ class "text-[13px] text-emerald-600" ] [ text t.saved ]

        SaveFailed ->
            p [ class "text-[13px] text-red-600" ] [ text t.settingsSaveError ]


settingLabel : T -> String -> String
settingLabel t name =
    case name of
        "registration.enabled" ->
            t.settingRegistrationEnabled

        "company.name" ->
            t.settingCompanyName

        _ ->
            name
