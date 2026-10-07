module Pages.Roles exposing (Caps, Model, Msg, init, load, update, view)

import Api
import Api.Types exposing (PermissionInfo, RoleResponse)
import Components.Button as Button
import Components.Input as Input
import Html exposing (Html, button, div, form, h1, h2, input, label, p, span, table, tbody, td, text, textarea, th, thead, tr)
import Html.Attributes exposing (checked, class, disabled, placeholder, property, rows, type_, value)
import Html.Events exposing (on, onClick, onInput, onSubmit)
import Http
import Icons
import Json.Decode as Decode
import Json.Encode as Encode


type Remote a
    = Loading
    | Loaded a
    | Failed


type alias Selection =
    { role : RoleResponse
    , permissions : Remote (List String)
    }


type alias Form =
    { open : Bool
    , name : String
    , description : String
    , submitting : Bool
    , error : Maybe String
    }


type alias Model =
    { roles : Remote (List RoleResponse)
    , permissions : Remote (List PermissionInfo)
    , selected : Maybe Selection
    , nameDraft : String
    , descriptionDraft : String
    , confirmingDelete : Bool
    , search : String
    , form : Form
    }


type alias Caps =
    { canCreate : Bool
    , canUpdate : Bool
    , canDelete : Bool
    , canReadPermissions : Bool
    , canGrant : Bool
    }


type Msg
    = GotRoles (Result Http.Error (List RoleResponse))
    | GotPermissions (Result Http.Error (List PermissionInfo))
    | SetSearch String
    | Select RoleResponse
    | SetRoleName String
    | SetRoleDescription String
    | CommitRole
    | RoleUpdated (Result Http.Error RoleResponse)
    | RequestDelete
    | CancelDelete
    | ConfirmDelete
    | RoleDeleted (Result Http.Error ())
    | GotRolePermissions (Result Http.Error (List String))
    | ClickNode String
    | PermissionsSet (Result Http.Error ())
    | ToggleForm
    | SetName String
    | SetFormDescription String
    | Submit
    | Created (Result Http.Error RoleResponse)


emptyForm : Form
emptyForm =
    { open = False, name = "", description = "", submitting = False, error = Nothing }


init : Model
init =
    { roles = Loading
    , permissions = Loading
    , selected = Nothing
    , nameDraft = ""
    , descriptionDraft = ""
    , confirmingDelete = False
    , search = ""
    , form = emptyForm
    }


{-| Fetch the role list and the permission catalog. The router runs this when
the page opens.
-}
load : Cmd Msg
load =
    Cmd.batch [ Api.listRoles GotRoles, Api.listPermissions GotPermissions ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        GotRoles result ->
            ( { model | roles = fromResult result }, Cmd.none )

        GotPermissions result ->
            ( { model | permissions = fromResult result }, Cmd.none )

        SetSearch query ->
            ( { model | search = query }, Cmd.none )

        Select role ->
            ( { model
                | selected = Just { role = role, permissions = Loading }
                , nameDraft = role.name
                , descriptionDraft = Maybe.withDefault "" role.description
                , confirmingDelete = False
              }
            , Api.getRolePermissions role.id GotRolePermissions
            )

        SetRoleName name ->
            ( { model | nameDraft = name }, Cmd.none )

        SetRoleDescription description ->
            ( { model | descriptionDraft = description }, Cmd.none )

        CommitRole ->
            case model.selected of
                Just selection ->
                    let
                        name =
                            String.trim model.nameDraft

                        description =
                            String.trim model.descriptionDraft

                        currentDescription =
                            Maybe.withDefault "" selection.role.description
                    in
                    if name == "" then
                        ( resetDrafts model, Cmd.none )

                    else if name == selection.role.name && description == currentDescription then
                        ( model, Cmd.none )

                    else
                        ( model
                        , Api.updateRole selection.role.id
                            { name = name
                            , description =
                                if description == "" then
                                    Nothing

                                else
                                    Just description
                            }
                            RoleUpdated
                        )

                Nothing ->
                    ( model, Cmd.none )

        RoleUpdated (Ok role) ->
            ( { model
                | nameDraft = role.name
                , descriptionDraft = Maybe.withDefault "" role.description
                , selected = Maybe.map (\s -> { s | role = role }) model.selected
              }
            , Api.listRoles GotRoles
            )

        RoleUpdated (Err _) ->
            ( resetDrafts model, Cmd.none )

        RequestDelete ->
            ( { model | confirmingDelete = True }, Cmd.none )

        CancelDelete ->
            ( { model | confirmingDelete = False }, Cmd.none )

        ConfirmDelete ->
            case model.selected of
                Just selection ->
                    ( { model | confirmingDelete = False }
                    , Api.deleteRole selection.role.id RoleDeleted
                    )

                Nothing ->
                    ( { model | confirmingDelete = False }, Cmd.none )

        RoleDeleted _ ->
            ( { model | selected = Nothing }, Api.listRoles GotRoles )

        GotRolePermissions result ->
            ( mapSelection (\s -> { s | permissions = fromResult result }) model, Cmd.none )

        ClickNode name ->
            case ( model.selected, model.permissions ) of
                ( Just selection, Loaded catalog ) ->
                    case selection.permissions of
                        Loaded granted ->
                            let
                                leaves =
                                    controlledLeaves catalog name

                                allGranted =
                                    not (List.isEmpty leaves) && List.all (\leaf -> List.member leaf granted) leaves

                                newGranted =
                                    if allGranted then
                                        List.filter (\g -> not (List.member g leaves)) granted

                                    else
                                        List.foldl
                                            (\leaf acc ->
                                                if List.member leaf acc then
                                                    acc

                                                else
                                                    leaf :: acc
                                            )
                                            granted
                                            leaves
                            in
                            ( mapSelection (\s -> { s | permissions = Loaded newGranted }) model
                            , Api.setRolePermissions selection.role.id newGranted PermissionsSet
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        PermissionsSet result ->
            case ( result, model.selected ) of
                ( Err _, Just selection ) ->
                    ( model, Api.getRolePermissions selection.role.id GotRolePermissions )

                _ ->
                    ( model, Cmd.none )

        ToggleForm ->
            ( { model | form = { emptyForm | open = not form.open } }, Cmd.none )

        SetName name ->
            ( { model | form = { form | name = name } }, Cmd.none )

        SetFormDescription description ->
            ( { model | form = { form | description = description } }, Cmd.none )

        Submit ->
            let
                description =
                    String.trim form.description
            in
            ( { model | form = { form | submitting = True, error = Nothing } }
            , Api.createRole
                { name = String.trim form.name
                , description =
                    if description == "" then
                        Nothing

                    else
                        Just description
                }
                Created
            )

        Created (Ok _) ->
            ( { model | form = emptyForm }, Api.listRoles GotRoles )

        Created (Err error) ->
            ( { model | form = { form | submitting = False, error = Just (createError error) } }
            , Cmd.none
            )


mapSelection : (Selection -> Selection) -> Model -> Model
mapSelection f model =
    { model | selected = Maybe.map f model.selected }


resetDrafts : Model -> Model
resetDrafts model =
    case model.selected of
        Just selection ->
            { model
                | nameDraft = selection.role.name
                , descriptionDraft = Maybe.withDefault "" selection.role.description
            }

        Nothing ->
            model


createError : Http.Error -> String
createError error =
    case error of
        Http.BadStatus 409 ->
            "That role name is already in use."

        Http.BadStatus 422 ->
            "Enter a role name."

        Http.BadStatus 403 ->
            "You do not have permission to create a role."

        _ ->
            Api.errorToString error


fromResult : Result Http.Error a -> Remote a
fromResult result =
    case result of
        Ok value ->
            Loaded value

        Err _ ->
            Failed


matches : String -> RoleResponse -> Bool
matches query role =
    String.contains (String.toLower (String.trim query)) (String.toLower role.name)



-- VIEW


view : Caps -> Model -> Html Msg
view caps model =
    div [ class "flex w-full flex-1 flex-col gap-4" ]
        [ div [ class "flex items-center justify-between gap-3" ]
            [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text "Roles" ]
            , div [ class "flex items-center gap-2" ]
                [ viewSearch model.search
                , viewCreateButton caps.canCreate model.form.open
                ]
            ]
        , if model.form.open then
            viewForm model.form

          else
            text ""
        , case model.roles of
            Loading ->
                hint "Loading roles..."

            Failed ->
                hint "Could not load roles."

            Loaded roles ->
                viewContent caps model (List.filter (matches model.search) roles)
        ]


viewCreateButton : Bool -> Bool -> Html Msg
viewCreateButton canCreate open =
    if canCreate then
        button
            [ onClick ToggleForm
            , class "flex items-center gap-1.5 rounded-lg bg-zinc-900 px-2.5 py-1.5 text-[13px] font-medium text-white shadow-sm transition-colors hover:bg-zinc-800"
            ]
            (if open then
                [ text "Cancel" ]

             else
                [ Icons.plus, text "Create role" ]
            )

    else
        text ""


viewSearch : String -> Html Msg
viewSearch query =
    div [ class "relative" ]
        [ span [ class "pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" ]
            [ Icons.search ]
        , input
            [ type_ "search"
            , placeholder "Search roles"
            , value query
            , onInput SetSearch
            , class "w-64 rounded-lg border border-zinc-200 bg-white py-1.5 pl-8 pr-3 text-[13px] text-zinc-900 transition-colors placeholder:text-zinc-400 focus:border-zinc-400 focus:outline-none"
            ]
            []
        ]


viewContent : Caps -> Model -> List RoleResponse -> Html Msg
viewContent caps model roles =
    div [ class "flex flex-1 items-start gap-4" ]
        [ div [ class "min-w-0 flex-1" ] [ viewTable model.selected roles ]
        , case model.selected of
            Just selection ->
                viewDetail caps model selection

            Nothing ->
                text ""
        ]


viewTable : Maybe Selection -> List RoleResponse -> Html Msg
viewTable selected roles =
    let
        selectedId =
            Maybe.map (\s -> s.role.id) selected
    in
    div [ class "overflow-hidden rounded-xl border border-zinc-200/70 bg-white shadow-sm" ]
        [ table [ class "w-full border-collapse text-left text-[13px]" ]
            [ thead []
                [ tr [ class "border-b border-zinc-200 bg-zinc-50/60" ]
                    [ th [ class headClass ] [ text "Name" ]
                    , th [ class headClass ] [ text "Description" ]
                    ]
                ]
            , tbody []
                (if List.isEmpty roles then
                    [ tr []
                        [ td [ class "px-3 py-6 text-center text-[13px] text-zinc-400", Html.Attributes.colspan 2 ]
                            [ text "No roles match." ]
                        ]
                    ]

                 else
                    List.map (viewTableRow selectedId) roles
                )
            ]
        ]


headClass : String
headClass =
    "px-3 py-2 text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-400"


viewTableRow : Maybe String -> RoleResponse -> Html Msg
viewTableRow selectedId role =
    tr
        [ onClick (Select role)
        , class
            ("cursor-pointer border-b border-zinc-100 transition-colors last:border-0 hover:bg-zinc-50"
                ++ (if selectedId == Just role.id then
                        " bg-zinc-50"

                    else
                        ""
                   )
            )
        ]
        [ td [ class "px-3 py-2 font-medium text-zinc-900" ] [ text role.name ]
        , td [ class "px-3 py-2 text-zinc-500" ] [ text (Maybe.withDefault "—" role.description) ]
        ]


viewDetail : Caps -> Model -> Selection -> Html Msg
viewDetail caps model selection =
    div []
        [ div [ class "w-96 shrink-0 rounded-xl border border-zinc-200/70 bg-white p-5 shadow-sm" ]
            [ div [ class "flex flex-col gap-5" ]
                (viewName caps.canUpdate model.nameDraft selection.role.name
                    :: section "Description"
                        (viewDescription caps.canUpdate
                            model.descriptionDraft
                            (Maybe.withDefault "" selection.role.description)
                        )
                    :: ((if caps.canReadPermissions then
                            [ section "Permissions" (viewTree caps.canGrant model.permissions selection.permissions) ]

                         else
                            []
                        )
                            ++ (if caps.canDelete then
                                    [ viewDeleteButton ]

                                else
                                    []
                               )
                       )
                )
            ]
        , if model.confirmingDelete then
            viewDeleteModal selection.role.name

          else
            text ""
        ]


viewName : Bool -> String -> String -> Html Msg
viewName canUpdate nameDraft name =
    if canUpdate then
        input
            [ type_ "text"
            , value nameDraft
            , onInput SetRoleName
            , on "change" (Decode.succeed CommitRole)
            , class "-ml-2 w-full rounded-lg border border-transparent px-2 py-1 text-sm font-semibold text-zinc-900 transition-colors hover:border-zinc-200 focus:border-zinc-400 focus:outline-none"
            ]
            []

    else
        span [ class "text-sm font-semibold text-zinc-900" ] [ text name ]


viewDescription : Bool -> String -> String -> Html Msg
viewDescription canUpdate descriptionDraft current =
    if canUpdate then
        textarea
            [ value descriptionDraft
            , onInput SetRoleDescription
            , on "change" (Decode.succeed CommitRole)
            , rows 2
            , placeholder "No description"
            , class "w-full resize-none rounded-lg border border-zinc-200 px-2 py-1.5 text-[13px] text-zinc-700 transition-colors placeholder:text-zinc-400 focus:border-zinc-400 focus:outline-none"
            ]
            []

    else if current == "" then
        hint "No description."

    else
        p [ class "text-[13px] text-zinc-600" ] [ text current ]


viewDeleteButton : Html Msg
viewDeleteButton =
    button
        [ onClick RequestDelete
        , class "self-start rounded-lg border border-red-200 px-2.5 py-1.5 text-[13px] font-medium text-red-600 transition-colors hover:bg-red-50"
        ]
        [ text "Delete role" ]


viewDeleteModal : String -> Html Msg
viewDeleteModal name =
    div [ class "fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4" ]
        [ div [ class "flex w-full max-w-sm flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-lg" ]
            [ h2 [ class "text-sm font-semibold text-zinc-900" ] [ text "Delete role" ]
            , p [ class "text-[13px] text-zinc-500" ]
                [ text ("Delete \"" ++ name ++ "\"? This cannot be undone.") ]
            , div [ class "flex justify-end gap-2" ]
                [ button
                    [ onClick CancelDelete
                    , class "rounded-lg border border-zinc-200 px-2.5 py-1.5 text-[13px] font-medium text-zinc-700 transition-colors hover:bg-zinc-50"
                    ]
                    [ text "Cancel" ]
                , button
                    [ onClick ConfirmDelete
                    , class "rounded-lg bg-red-600 px-2.5 py-1.5 text-[13px] font-medium text-white transition-colors hover:bg-red-700"
                    ]
                    [ text "Delete" ]
                ]
            ]
        ]


section : String -> Html Msg -> Html Msg
section title body =
    div [ class "flex flex-col gap-1.5" ]
        [ h2 [ class "text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-400" ] [ text title ]
        , body
        ]



-- PERMISSION TREE


type Node
    = Node { name : String, segment : String, children : List Node }


viewTree : Bool -> Remote (List PermissionInfo) -> Remote (List String) -> Html Msg
viewTree canGrant permissions granted =
    case ( permissions, granted ) of
        ( Loaded catalog, Loaded names ) ->
            div [ class "flex flex-col" ]
                (List.concatMap (viewNode canGrant catalog names 0) (buildForest catalog))

        ( Failed, _ ) ->
            hint "Could not load permissions."

        ( _, Failed ) ->
            hint "Could not load."

        _ ->
            hint "Loading..."


buildForest : List PermissionInfo -> List Node
buildForest catalog =
    catalog
        |> List.filter (\permission -> permission.parent == Nothing)
        |> List.map (toNode catalog)


toNode : List PermissionInfo -> PermissionInfo -> Node
toNode catalog permission =
    Node
        { name = permission.name
        , segment = segmentOf permission.name
        , children =
            catalog
                |> List.filter (\child -> child.parent == Just permission.name)
                |> List.map (toNode catalog)
        }


viewNode : Bool -> List PermissionInfo -> List String -> Int -> Node -> List (Html Msg)
viewNode canGrant catalog granted depth (Node node) =
    viewRow canGrant catalog granted depth node
        :: List.concatMap (viewNode canGrant catalog granted (depth + 1)) node.children


viewRow canGrant catalog granted depth node =
    let
        leaves =
            controlledLeaves catalog node.name

        grantedCount =
            List.length (List.filter (\leaf -> List.member leaf granted) leaves)

        total =
            List.length leaves

        allChecked =
            total > 0 && grantedCount == total

        indeterminate =
            grantedCount > 0 && grantedCount < total

        isBranch =
            not (List.isEmpty node.children)
    in
    label
        [ class "flex items-center gap-2 rounded-md py-1 pr-2 text-[13px] hover:bg-zinc-50"
        , Html.Attributes.style "padding-left" (String.fromInt (8 + depth * 16) ++ "px")
        ]
        [ input
            [ type_ "checkbox"
            , checked allChecked
            , property "indeterminate" (Encode.bool indeterminate)
            , disabled (not canGrant)
            , onClick (ClickNode node.name)
            , class "h-3.5 w-3.5 accent-zinc-900 disabled:opacity-50"
            ]
            []
        , span
            [ class
                (if isBranch then
                    "font-medium text-zinc-800"

                 else
                    "text-zinc-700"
                )
            ]
            [ text node.segment ]
        ]


isLeaf : List PermissionInfo -> String -> Bool
isLeaf catalog name =
    not (List.any (\permission -> permission.parent == Just name) catalog)


controlledLeaves : List PermissionInfo -> String -> List String
controlledLeaves catalog name =
    catalog
        |> List.filter
            (\permission ->
                (permission.name == name || String.startsWith (name ++ ".") permission.name)
                    && isLeaf catalog permission.name
            )
        |> List.map .name


segmentOf : String -> String
segmentOf name =
    String.split "." name
        |> List.reverse
        |> List.head
        |> Maybe.withDefault name


viewForm : Form -> Html Msg
viewForm form_ =
    form
        [ onSubmit Submit
        , class "flex flex-col gap-3.5 rounded-xl border border-zinc-200/70 bg-white p-5 shadow-sm"
        ]
        [ Input.view
            { label = "Name"
            , type_ = "text"
            , placeholder = "Role name"
            , value = form_.name
            , onInput = SetName
            }
        , Input.view
            { label = "Description"
            , type_ = "text"
            , placeholder = "Optional"
            , value = form_.description
            , onInput = SetFormDescription
            }
        , viewError form_.error
        , Button.primary [ type_ "submit", disabled form_.submitting ]
            [ text
                (if form_.submitting then
                    "Creating..."

                 else
                    "Create role"
                )
            ]
        ]


viewError : Maybe String -> Html Msg
viewError maybeError =
    case maybeError of
        Just message ->
            p [ class "text-[13px] text-red-600" ] [ text message ]

        Nothing ->
            text ""


hint : String -> Html Msg
hint message =
    p [ class "text-[13px] text-zinc-500" ] [ text message ]
