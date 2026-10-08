module Pages.Roles exposing (Caps, Model, Msg, init, load, update, view)

import Api
import Api.Types exposing (PermissionInfo, RolePage, RoleResponse)
import Components.Button as Button
import Components.Input as Input
import Components.Pagination as Pagination
import Html exposing (Html, button, div, form, h1, h2, input, label, p, span, table, tbody, td, text, textarea, th, thead, tr)
import Html.Attributes exposing (checked, class, disabled, placeholder, property, rows, type_, value)
import Html.Events exposing (on, onClick, onInput, onSubmit)
import Http
import I18n exposing (T)
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


{-| The create-role form. `error` holds the failed request, and the view turns it
into a localized message.
-}
type alias Form =
    { open : Bool
    , name : String
    , description : String
    , submitting : Bool
    , error : Maybe Http.Error
    }


type alias Model =
    { roles : Remote (List RoleResponse)
    , permissions : Remote (List PermissionInfo)
    , selected : Maybe Selection
    , nameDraft : String
    , descriptionDraft : String
    , confirmingDelete : Bool
    , search : String
    , page : Int
    , perPage : Int
    , total : Int
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
    = GotRoles (Result Http.Error RolePage)
    | GotPermissions (Result Http.Error (List PermissionInfo))
    | SetSearch String
    | PrevPage
    | NextPage
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
    , page = 1
    , perPage = defaultPerPage
    , total = 0
    , form = emptyForm
    }


defaultPerPage : Int
defaultPerPage =
    25


fetchRoles : Int -> Int -> String -> Cmd Msg
fetchRoles perPage page search =
    Api.listRoles { page = page, perPage = perPage, search = search } GotRoles


{-| Fetch the role list and the permission catalog. The router runs this when
the page opens.
-}
load : Int -> Cmd Msg
load perPage =
    Cmd.batch [ fetchRoles perPage 1 "", Api.listPermissions GotPermissions ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        GotRoles (Ok rolePage) ->
            if List.isEmpty rolePage.items && rolePage.page > 1 then
                let
                    previous =
                        rolePage.page - 1
                in
                ( { model | page = previous }, fetchRoles model.perPage previous model.search )

            else
                ( { model
                    | roles = Loaded rolePage.items
                    , total = rolePage.total
                    , page = rolePage.page
                    , perPage = rolePage.perPage
                  }
                , Cmd.none
                )

        GotRoles (Err _) ->
            ( { model | roles = Failed }, Cmd.none )

        GotPermissions result ->
            ( { model | permissions = fromResult result }, Cmd.none )

        SetSearch query ->
            ( { model | search = query, page = 1 }, fetchRoles model.perPage 1 query )

        PrevPage ->
            let
                previous =
                    max 1 (model.page - 1)
            in
            ( { model | page = previous }, fetchRoles model.perPage previous model.search )

        NextPage ->
            let
                next =
                    model.page + 1
            in
            ( { model | page = next }, fetchRoles model.perPage next model.search )

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
            , fetchRoles model.perPage model.page model.search
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
            ( { model | selected = Nothing }, fetchRoles model.perPage model.page model.search )

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
            ( { model | form = emptyForm }, fetchRoles model.perPage model.page model.search )

        Created (Err error) ->
            ( { model | form = { form | submitting = False, error = Just error } }
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


createError : T -> Http.Error -> String
createError t error =
    case error of
        Http.BadStatus 409 ->
            t.errRoleNameInUse

        Http.BadStatus 422 ->
            t.errRoleNameRequired

        Http.BadStatus 403 ->
            t.errNoPermissionCreateRole

        _ ->
            Api.errorToString t error


fromResult : Result Http.Error a -> Remote a
fromResult result =
    case result of
        Ok value ->
            Loaded value

        Err _ ->
            Failed



-- VIEW


view : T -> Caps -> Model -> Html Msg
view t caps model =
    div [ class "flex w-full flex-1 flex-col gap-4" ]
        [ div [ class "flex items-center justify-between gap-3" ]
            [ h1 [ class "text-base font-semibold tracking-tight text-foreground" ] [ text t.roles ]
            , div [ class "flex items-center gap-2" ]
                [ viewSearch t model.search
                , viewCreateButton t caps.canCreate model.form.open
                ]
            ]
        , if model.form.open then
            viewForm t model.form

          else
            text ""
        , case model.roles of
            Loading ->
                hint t.loadingRoles

            Failed ->
                hint t.couldNotLoadRoles

            Loaded roles ->
                viewContent t caps model roles
        ]


viewCreateButton : T -> Bool -> Bool -> Html Msg
viewCreateButton t canCreate open =
    if canCreate then
        button
            [ onClick ToggleForm
            , class "flex items-center gap-1.5 rounded-lg bg-primary px-2.5 py-1.5 text-[13px] font-medium text-primary-foreground shadow-sm transition-colors hover:bg-primary/90"
            ]
            (if open then
                [ text t.cancel ]

             else
                [ Icons.plus, text t.createRole ]
            )

    else
        text ""


viewSearch : T -> String -> Html Msg
viewSearch t query =
    div [ class "relative" ]
        [ span [ class "pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" ]
            [ Icons.search ]
        , input
            [ type_ "search"
            , placeholder t.searchRoles
            , value query
            , onInput SetSearch
            , class "w-64 rounded-lg border border-border bg-card py-1.5 pl-8 pr-3 text-[13px] text-foreground transition-colors placeholder:text-muted-foreground focus:border-ring focus:outline-none"
            ]
            []
        ]


viewContent : T -> Caps -> Model -> List RoleResponse -> Html Msg
viewContent t caps model roles =
    div [ class "flex flex-1 items-start gap-4" ]
        [ div [ class "flex min-w-0 flex-1 flex-col gap-3" ]
            [ Pagination.view t { page = model.page, perPage = model.perPage, total = model.total, onPrev = PrevPage, onNext = NextPage }
            , viewTable t model.selected roles
            ]
        , case model.selected of
            Just selection ->
                viewDetail t caps model selection

            Nothing ->
                text ""
        ]


viewTable : T -> Maybe Selection -> List RoleResponse -> Html Msg
viewTable t selected roles =
    let
        selectedId =
            Maybe.map (\s -> s.role.id) selected
    in
    div [ class "overflow-hidden rounded-xl border border-border bg-card shadow-sm" ]
        [ table [ class "w-full border-collapse text-left text-[13px]" ]
            [ thead []
                [ tr [ class "border-b border-border bg-muted/50" ]
                    [ th [ class headClass ] [ text t.name ]
                    , th [ class headClass ] [ text t.description ]
                    ]
                ]
            , tbody []
                (if List.isEmpty roles then
                    [ tr []
                        [ td [ class "px-3 py-6 text-center text-[13px] text-muted-foreground", Html.Attributes.colspan 2 ]
                            [ text t.noRolesMatch ]
                        ]
                    ]

                 else
                    List.map (viewTableRow selectedId) roles
                )
            ]
        ]


headClass : String
headClass =
    "px-3 py-2 text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground"


viewTableRow : Maybe String -> RoleResponse -> Html Msg
viewTableRow selectedId role =
    tr
        [ onClick (Select role)
        , class
            ("cursor-pointer border-b border-border transition-colors last:border-0 hover:bg-accent"
                ++ (if selectedId == Just role.id then
                        " bg-muted"

                    else
                        ""
                   )
            )
        ]
        [ td [ class "px-3 py-2 font-medium text-foreground" ] [ text role.name ]
        , td [ class "px-3 py-2 text-muted-foreground" ] [ text (Maybe.withDefault "—" role.description) ]
        ]


viewDetail : T -> Caps -> Model -> Selection -> Html Msg
viewDetail t caps model selection =
    div []
        [ div [ class "max-h-[calc(100dvh-10rem)] w-96 shrink-0 overflow-y-auto rounded-xl border border-border bg-card p-5 shadow-sm" ]
            [ div [ class "flex flex-col gap-5" ]
                (viewName caps.canUpdate model.nameDraft selection.role.name
                    :: section t.description
                        (viewDescription t
                            caps.canUpdate
                            model.descriptionDraft
                            (Maybe.withDefault "" selection.role.description)
                        )
                    :: ((if caps.canReadPermissions then
                            [ section t.permissions (viewTree t caps.canGrant model.permissions selection.permissions) ]

                         else
                            []
                        )
                            ++ (if caps.canDelete then
                                    [ viewDeleteButton t ]

                                else
                                    []
                               )
                       )
                )
            ]
        , if model.confirmingDelete then
            viewDeleteModal t selection.role.name

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
            , class "-ml-2 w-full rounded-lg border border-transparent px-2 py-1 text-sm font-semibold text-foreground transition-colors hover:border-border focus:border-ring focus:outline-none"
            ]
            []

    else
        span [ class "text-sm font-semibold text-foreground" ] [ text name ]


viewDescription : T -> Bool -> String -> String -> Html Msg
viewDescription t canUpdate descriptionDraft current =
    if canUpdate then
        textarea
            [ value descriptionDraft
            , onInput SetRoleDescription
            , on "change" (Decode.succeed CommitRole)
            , rows 2
            , placeholder t.noDescriptionPlaceholder
            , class "w-full resize-none rounded-lg border border-border px-2 py-1.5 text-[13px] text-muted-foreground transition-colors placeholder:text-muted-foreground focus:border-ring focus:outline-none"
            ]
            []

    else if current == "" then
        hint t.noDescription

    else
        p [ class "text-[13px] text-muted-foreground" ] [ text current ]


viewDeleteButton : T -> Html Msg
viewDeleteButton t =
    button
        [ onClick RequestDelete
        , class "self-start rounded-lg border border-destructive/30 px-2.5 py-1.5 text-[13px] font-medium text-destructive transition-colors hover:bg-destructive/10"
        ]
        [ text t.deleteRole ]


viewDeleteModal : T -> String -> Html Msg
viewDeleteModal t name =
    div [ class "fixed inset-0 z-50 flex items-center justify-center bg-foreground/20 p-4" ]
        [ div [ class "flex w-full max-w-sm flex-col gap-4 rounded-2xl border border-border bg-card p-6 shadow-lg" ]
            [ h2 [ class "text-sm font-semibold text-foreground" ] [ text t.deleteRole ]
            , p [ class "text-[13px] text-muted-foreground" ]
                [ text (t.deleteRoleConfirmPrefix ++ name ++ t.deleteRoleConfirmSuffix) ]
            , div [ class "flex justify-end gap-2" ]
                [ button
                    [ onClick CancelDelete
                    , class "rounded-lg border border-border px-2.5 py-1.5 text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent"
                    ]
                    [ text t.cancel ]
                , button
                    [ onClick ConfirmDelete
                    , class "rounded-lg bg-destructive px-2.5 py-1.5 text-[13px] font-medium text-destructive-foreground transition-colors hover:bg-destructive/90"
                    ]
                    [ text t.delete ]
                ]
            ]
        ]


section : String -> Html Msg -> Html Msg
section title body =
    div [ class "flex flex-col gap-1.5" ]
        [ h2 [ class "text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground" ] [ text title ]
        , body
        ]



-- PERMISSION TREE


type Node
    = Node { name : String, segment : String, children : List Node }


viewTree : T -> Bool -> Remote (List PermissionInfo) -> Remote (List String) -> Html Msg
viewTree t canGrant permissions granted =
    case ( permissions, granted ) of
        ( Loaded catalog, Loaded names ) ->
            div [ class "flex flex-col" ]
                (List.concatMap (viewNode canGrant catalog names 0) (buildForest catalog))

        ( Failed, _ ) ->
            hint t.couldNotLoadPermissions

        ( _, Failed ) ->
            hint t.couldNotLoad

        _ ->
            hint t.loading


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
        [ class "flex items-center gap-2 rounded-md py-1 pr-2 text-[13px] hover:bg-accent"
        , Html.Attributes.style "padding-left" (String.fromInt (8 + depth * 16) ++ "px")
        ]
        [ input
            [ type_ "checkbox"
            , checked allChecked
            , property "indeterminate" (Encode.bool indeterminate)
            , disabled (not canGrant)
            , onClick (ClickNode node.name)
            , class "h-3.5 w-3.5 accent-primary disabled:opacity-50"
            ]
            []
        , span
            [ class
                (if isBranch then
                    "font-medium text-foreground"

                 else
                    "text-muted-foreground"
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


viewForm : T -> Form -> Html Msg
viewForm t form_ =
    form
        [ onSubmit Submit
        , class "flex flex-col gap-3.5 rounded-xl border border-border bg-card p-5 shadow-sm"
        ]
        [ Input.view
            { label = t.name
            , type_ = "text"
            , placeholder = t.roleNamePlaceholder
            , value = form_.name
            , onInput = SetName
            }
        , Input.view
            { label = t.description
            , type_ = "text"
            , placeholder = t.optionalField
            , value = form_.description
            , onInput = SetFormDescription
            }
        , viewError t form_.error
        , Button.primary [ type_ "submit", disabled form_.submitting ]
            [ text
                (if form_.submitting then
                    t.creating

                 else
                    t.createRole
                )
            ]
        ]


viewError : T -> Maybe Http.Error -> Html Msg
viewError t maybeError =
    case maybeError of
        Just error ->
            p [ class "text-[13px] text-destructive" ] [ text (createError t error) ]

        Nothing ->
            text ""


hint : String -> Html Msg
hint message =
    p [ class "text-[13px] text-muted-foreground" ] [ text message ]
