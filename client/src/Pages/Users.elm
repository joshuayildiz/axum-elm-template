module Pages.Users exposing (Model, Msg, init, load, update, view)

import Api
import Api.Types exposing (PermissionInfo, RoleResponse, UserResponse)
import Components.Button as Button
import Components.Input as Input
import Html exposing (Html, button, datalist, div, form, h1, h2, input, label, li, option, p, span, table, tbody, td, text, th, thead, tr, ul)
import Html.Attributes exposing (checked, class, disabled, id, list, placeholder, property, style, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput, onSubmit, targetValue)
import Http
import I18n exposing (T)
import Icons
import Json.Decode as Decode
import Json.Encode as Encode


{-| A value we fetch from the server: in flight, loaded, or failed.
-}
type Remote a
    = Loading
    | Loaded a
    | Failed


{-| The user whose details are open. `direct` is the user's own grants, which the
checkboxes toggle. `inherited` is what their roles grant, shown as locked.
-}
type alias Selection =
    { user : UserResponse
    , roles : Remote (List RoleResponse)
    , direct : Remote (List String)
    , inherited : Remote (List String)
    }


{-| The create-user form. It is hidden until the user opens it. `error` holds the
failed request, and the view turns it into a localized message.
-}
type alias Form =
    { open : Bool
    , email : String
    , name : String
    , password : String
    , isAdmin : Bool
    , submitting : Bool
    , error : Maybe Http.Error
    }


type alias Model =
    { users : Remote (List UserResponse)
    , permissions : Remote (List PermissionInfo)
    , allRoles : Remote (List RoleResponse)
    , selected : Maybe Selection
    , confirmingDelete : Bool
    , search : String
    , roleInput : String
    , form : Form
    }


type Msg
    = GotUsers (Result Http.Error (List UserResponse))
    | GotPermissions (Result Http.Error (List PermissionInfo))
    | GotAllRoles (Result Http.Error (List RoleResponse))
    | SetSearch String
    | SetRoleInput String
    | AddRole String
    | RemoveRole String
    | RoleAssignmentChanged (Result Http.Error ())
    | Select UserResponse
    | RequestDelete
    | CancelDelete
    | ConfirmDelete
    | UserDeleted (Result Http.Error ())
    | GotRoles (Result Http.Error (List RoleResponse))
    | GotDirect (Result Http.Error (List String))
    | GotInherited (Result Http.Error (List String))
    | ClickNode String
    | PermissionChanged (Result Http.Error ())
    | ToggleForm
    | SetEmail String
    | SetName String
    | SetPassword String
    | SetAdmin Bool
    | Submit
    | Created (Result Http.Error UserResponse)


emptyForm : Form
emptyForm =
    { open = False
    , email = ""
    , name = ""
    , password = ""
    , isAdmin = False
    , submitting = False
    , error = Nothing
    }


init : Model
init =
    { users = Loading
    , permissions = Loading
    , allRoles = Loading
    , selected = Nothing
    , confirmingDelete = False
    , search = ""
    , roleInput = ""
    , form = emptyForm
    }


{-| Fetch the user list and the permission catalog. The router runs this when
the page opens.
-}
load : Cmd Msg
load =
    Cmd.batch
        [ Api.listUsers GotUsers
        , Api.listPermissions GotPermissions
        , Api.listRoles GotAllRoles
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        form =
            model.form
    in
    case msg of
        GotUsers result ->
            ( { model | users = fromResult result }, Cmd.none )

        GotPermissions result ->
            ( { model | permissions = fromResult result }, Cmd.none )

        GotAllRoles result ->
            ( { model | allRoles = fromResult result }, Cmd.none )

        SetSearch query ->
            ( { model | search = query }, Cmd.none )

        SetRoleInput value_ ->
            ( { model | roleInput = value_ }, Cmd.none )

        AddRole name ->
            case ( model.selected, model.allRoles ) of
                ( Just selection, Loaded all ) ->
                    case ( selection.roles, roleByName all name ) of
                        ( Loaded assigned, Just role ) ->
                            if List.any (\r -> r.id == role.id) assigned then
                                ( { model | roleInput = "" }, Cmd.none )

                            else
                                ( { model
                                    | roleInput = ""
                                    , selected = Just { selection | roles = Loaded (assigned ++ [ role ]) }
                                  }
                                , Api.assignRole selection.user.id role.id RoleAssignmentChanged
                                )

                        _ ->
                            ( { model | roleInput = "" }, Cmd.none )

                _ ->
                    ( { model | roleInput = "" }, Cmd.none )

        RemoveRole roleId ->
            case model.selected of
                Just selection ->
                    case selection.roles of
                        Loaded assigned ->
                            ( mapSelection (\s -> { s | roles = Loaded (List.filter (\r -> r.id /= roleId) assigned) }) model
                            , Api.removeRole selection.user.id roleId RoleAssignmentChanged
                            )

                        _ ->
                            ( model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        RoleAssignmentChanged result ->
            case ( result, model.selected ) of
                ( Err _, Just selection ) ->
                    ( model, Api.getUserRoles selection.user.id GotRoles )

                _ ->
                    ( model, Cmd.none )

        Select user ->
            ( { model
                | selected =
                    Just { user = user, roles = Loading, direct = Loading, inherited = Loading }
                , confirmingDelete = False
              }
            , Cmd.batch
                [ Api.getUserRoles user.id GotRoles
                , Api.getUserPermissions user.id GotDirect
                , Api.getUserRolePermissions user.id GotInherited
                ]
            )

        RequestDelete ->
            ( { model | confirmingDelete = True }, Cmd.none )

        CancelDelete ->
            ( { model | confirmingDelete = False }, Cmd.none )

        ConfirmDelete ->
            case model.selected of
                Just selection ->
                    ( { model | confirmingDelete = False }
                    , Api.deleteUser selection.user.id UserDeleted
                    )

                Nothing ->
                    ( { model | confirmingDelete = False }, Cmd.none )

        UserDeleted _ ->
            ( { model | selected = Nothing }, Api.listUsers GotUsers )

        GotRoles result ->
            ( mapSelection (\s -> { s | roles = fromResult result }) model, Cmd.none )

        GotDirect result ->
            ( mapSelection (\s -> { s | direct = fromResult result }) model, Cmd.none )

        GotInherited result ->
            ( mapSelection (\s -> { s | inherited = fromResult result }) model, Cmd.none )

        ClickNode name ->
            case ( model.selected, model.permissions ) of
                ( Just selection, Loaded catalog ) ->
                    case ( selection.direct, selection.inherited ) of
                        ( Loaded direct, Loaded inherited ) ->
                            let
                                leaves =
                                    controlledLeaves catalog name

                                effective leaf =
                                    List.member leaf direct || List.member leaf inherited

                                allEffective =
                                    not (List.isEmpty leaves) && List.all effective leaves

                                -- All on means a click removes; otherwise it assigns.
                                -- A role grant cannot be removed, so revoke only the
                                -- direct ones and assign only what is missing.
                                targets =
                                    if allEffective then
                                        leaves
                                            |> List.filter (\leaf -> List.member leaf direct)
                                            |> List.map (\leaf -> ( leaf, False ))

                                    else
                                        leaves
                                            |> List.filter (\leaf -> not (effective leaf))
                                            |> List.map (\leaf -> ( leaf, True ))

                                newDirect =
                                    List.foldl (\( leaf, granted ) acc -> setGrant granted leaf acc) direct targets
                            in
                            ( mapSelection (\s -> { s | direct = Loaded newDirect }) model
                            , Api.setUserPermissions selection.user.id newDirect PermissionChanged
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        PermissionChanged result ->
            case ( result, model.selected ) of
                ( Err _, Just selection ) ->
                    -- The write failed. Re-read the grants so the tree is honest.
                    ( model, Api.getUserPermissions selection.user.id GotDirect )

                _ ->
                    ( model, Cmd.none )

        ToggleForm ->
            ( { model | form = { emptyForm | open = not form.open } }, Cmd.none )

        SetEmail email ->
            ( { model | form = { form | email = email } }, Cmd.none )

        SetName name ->
            ( { model | form = { form | name = name } }, Cmd.none )

        SetPassword password ->
            ( { model | form = { form | password = password } }, Cmd.none )

        SetAdmin isAdmin ->
            ( { model | form = { form | isAdmin = isAdmin } }, Cmd.none )

        Submit ->
            ( { model | form = { form | submitting = True, error = Nothing } }
            , Api.createUser
                { email = String.trim form.email
                , password = form.password
                , name = optional form.name
                , isAdmin = form.isAdmin
                }
                Created
            )

        Created (Ok _) ->
            ( { model | form = emptyForm }, Api.listUsers GotUsers )

        Created (Err error) ->
            ( { model | form = { form | submitting = False, error = Just error } }
            , Cmd.none
            )


{-| Add or remove a name in a direct-grant list, so the tree flips at once while
the requests are in flight.
-}
setGrant : Bool -> String -> List String -> List String
setGrant granted name names =
    if granted then
        if List.member name names then
            names

        else
            name :: names

    else
        List.filter ((/=) name) names


optional : String -> Maybe String
optional value_ =
    if String.trim value_ == "" then
        Nothing

    else
        Just (String.trim value_)


createError : T -> Http.Error -> String
createError t error =
    case error of
        Http.BadStatus 409 ->
            t.errEmailInUse

        Http.BadStatus 422 ->
            t.errUserInvalid

        Http.BadStatus 403 ->
            t.errNoPermissionCreateUser

        _ ->
            Api.errorToString t error


fromResult : Result Http.Error a -> Remote a
fromResult result =
    case result of
        Ok value_ ->
            Loaded value_

        Err _ ->
            Failed


mapSelection : (Selection -> Selection) -> Model -> Model
mapSelection f model =
    case model.selected of
        Just selection ->
            { model | selected = Just (f selection) }

        Nothing ->
            model


matches : String -> UserResponse -> Bool
matches query user =
    let
        needle =
            String.toLower (String.trim query)

        haystack =
            String.toLower (user.email ++ " " ++ Maybe.withDefault "" user.name)
    in
    needle == "" || String.contains needle haystack



-- VIEW


type alias Caps =
    { canCreate : Bool
    , canDelete : Bool
    , canReadRoles : Bool
    , canAssignRoles : Bool
    , canReadPermissions : Bool
    , canGrant : Bool
    }


view : T -> Caps -> Model -> Html Msg
view t caps model =
    div [ class "flex w-full flex-1 flex-col gap-4" ]
        [ div [ class "flex items-center justify-between gap-3" ]
            [ h1 [ class "text-base font-semibold tracking-tight text-zinc-900" ] [ text t.users ]
            , div [ class "flex items-center gap-2" ]
                [ viewSearch t model.search
                , viewCreateButton t caps.canCreate model.form.open
                ]
            ]
        , if model.form.open then
            viewForm t model.form

          else
            text ""
        , case model.users of
            Loading ->
                hint t.loadingUsers

            Failed ->
                hint t.couldNotLoadUsers

            Loaded users ->
                viewContent t caps model.permissions model.allRoles model.roleInput model.confirmingDelete model.selected (List.filter (matches model.search) users)
        ]


viewCreateButton : T -> Bool -> Bool -> Html Msg
viewCreateButton t canCreate open =
    if canCreate then
        button
            [ onClick ToggleForm
            , class "flex items-center gap-1.5 rounded-lg bg-zinc-900 px-2.5 py-1.5 text-[13px] font-medium text-white shadow-sm transition-colors hover:bg-zinc-800"
            ]
            (if open then
                [ text t.cancel ]

             else
                [ Icons.plus, text t.createUser ]
            )

    else
        text ""


viewSearch : T -> String -> Html Msg
viewSearch t query =
    div [ class "relative" ]
        [ span [ class "pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-zinc-400" ]
            [ Icons.search ]
        , input
            [ type_ "search"
            , placeholder t.searchUsers
            , value query
            , onInput SetSearch
            , class "w-64 rounded-lg border border-zinc-200 bg-white py-1.5 pl-8 pr-3 text-[13px] text-zinc-900 transition-colors placeholder:text-zinc-400 focus:border-zinc-400 focus:outline-none"
            ]
            []
        ]


viewContent : T -> Caps -> Remote (List PermissionInfo) -> Remote (List RoleResponse) -> String -> Bool -> Maybe Selection -> List UserResponse -> Html Msg
viewContent t caps permissions allRoles roleInput confirmingDelete selected users =
    div [ class "flex flex-1 items-start gap-4" ]
        [ div [ class "min-w-0 flex-1" ] [ viewTable t selected users ]
        , case selected of
            Just selection ->
                viewDetail t caps permissions allRoles roleInput confirmingDelete selection

            Nothing ->
                text ""
        ]


viewTable : T -> Maybe Selection -> List UserResponse -> Html Msg
viewTable t selected users =
    let
        selectedId =
            Maybe.map (\s -> s.user.id) selected
    in
    div [ class "overflow-hidden rounded-xl border border-zinc-200/70 bg-white shadow-sm" ]
        [ table [ class "w-full border-collapse text-left text-[13px]" ]
            [ thead []
                [ tr [ class "border-b border-zinc-200 bg-zinc-50/60" ]
                    [ th [ class headClass ] [ text t.email ]
                    , th [ class headClass ] [ text t.name ]
                    , th [ class (headClass ++ " text-right") ] [ text t.admin ]
                    ]
                ]
            , tbody []
                (if List.isEmpty users then
                    [ tr []
                        [ td [ class "px-3 py-6 text-center text-[13px] text-zinc-400" ]
                            [ text t.noUsersMatch ]
                        ]
                    ]

                 else
                    List.map (viewTableRow t selectedId) users
                )
            ]
        ]


headClass : String
headClass =
    "px-3 py-2 text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-400"


viewTableRow : T -> Maybe String -> UserResponse -> Html Msg
viewTableRow t selectedId user =
    tr
        [ onClick (Select user)
        , class
            ("cursor-pointer border-b border-zinc-100 transition-colors last:border-0 hover:bg-zinc-50"
                ++ (if selectedId == Just user.id then
                        " bg-zinc-50"

                    else
                        ""
                   )
            )
        ]
        [ td [ class "px-3 py-2 font-medium text-zinc-900" ] [ text user.email ]
        , td [ class "px-3 py-2 text-zinc-600" ] [ text (Maybe.withDefault "—" user.name) ]
        , td [ class "px-3 py-2 text-right" ]
            [ if user.isAdmin then
                span [ class "rounded-md bg-zinc-100 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-zinc-500" ]
                    [ text t.admin ]

              else
                span [ class "text-zinc-300" ] [ text "—" ]
            ]
        ]


viewDetail : T -> Caps -> Remote (List PermissionInfo) -> Remote (List RoleResponse) -> String -> Bool -> Selection -> Html Msg
viewDetail t caps permissions allRoles roleInput confirmingDelete selection =
    div []
        [ div [ class "w-96 shrink-0 rounded-xl border border-zinc-200/70 bg-white p-5 shadow-sm" ]
            [ div [ class "flex flex-col gap-5" ]
                (viewUser selection.user
                    :: (if caps.canReadRoles then
                            [ section t.roles (viewRoles t caps allRoles roleInput selection.roles) ]

                        else
                            []
                       )
                    ++ (if caps.canReadPermissions then
                            [ section t.permissions (viewTree t caps.canGrant permissions selection) ]

                        else
                            []
                       )
                    ++ (if caps.canDelete then
                            [ viewDeleteButton t ]

                        else
                            []
                       )
                )
            ]
        , if confirmingDelete then
            viewDeleteModal t selection.user.email

          else
            text ""
        ]


viewDeleteButton : T -> Html Msg
viewDeleteButton t =
    button
        [ onClick RequestDelete
        , class "self-start rounded-lg border border-red-200 px-2.5 py-1.5 text-[13px] font-medium text-red-600 transition-colors hover:bg-red-50"
        ]
        [ text t.deleteUser ]


viewDeleteModal : T -> String -> Html Msg
viewDeleteModal t email =
    div [ class "fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-4" ]
        [ div [ class "flex w-full max-w-sm flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-lg" ]
            [ h2 [ class "text-sm font-semibold text-zinc-900" ] [ text t.deleteUser ]
            , p [ class "text-[13px] text-zinc-500" ]
                [ text (t.deleteUserConfirmPrefix ++ email ++ t.deleteUserConfirmSuffix) ]
            , div [ class "flex justify-end gap-2" ]
                [ button
                    [ onClick CancelDelete
                    , class "rounded-lg border border-zinc-200 px-2.5 py-1.5 text-[13px] font-medium text-zinc-700 transition-colors hover:bg-zinc-50"
                    ]
                    [ text t.cancel ]
                , button
                    [ onClick ConfirmDelete
                    , class "rounded-lg bg-red-600 px-2.5 py-1.5 text-[13px] font-medium text-white transition-colors hover:bg-red-700"
                    ]
                    [ text t.delete ]
                ]
            ]
        ]


{-| The assigned roles as removable pills, with an autocomplete box to add more.
Without `canAssignRoles` the pills are plain and the box is hidden.
-}
viewRoles : T -> Caps -> Remote (List RoleResponse) -> String -> Remote (List RoleResponse) -> Html Msg
viewRoles t caps allRoles roleInput assigned =
    case assigned of
        Loading ->
            hint t.loading

        Failed ->
            hint t.couldNotLoad

        Loaded roles ->
            div [ class "flex flex-col gap-2" ]
                [ if List.isEmpty roles then
                    hint t.noRoles

                  else
                    div [ class "flex flex-wrap gap-1" ]
                        (List.map (viewRolePill caps.canAssignRoles) roles)
                , if caps.canAssignRoles then
                    viewRoleInput t allRoles roleInput roles

                  else
                    text ""
                ]


viewRolePill : Bool -> RoleResponse -> Html Msg
viewRolePill canRemove role =
    span [ class "inline-flex items-center gap-1 rounded-md bg-zinc-100 px-1.5 py-0.5 text-[11px] font-medium text-zinc-600" ]
        (text role.name
            :: (if canRemove then
                    [ button
                        [ onClick (RemoveRole role.id)
                        , class "text-zinc-400 transition-colors hover:text-zinc-900"
                        ]
                        [ text "×" ]
                    ]

                else
                    []
               )
        )


viewRoleInput : T -> Remote (List RoleResponse) -> String -> List RoleResponse -> Html Msg
viewRoleInput t allRoles roleInput assigned =
    let
        assignedNames =
            List.map .name assigned

        options =
            case allRoles of
                Loaded all ->
                    List.filter (\role -> not (List.member role.name assignedNames)) all

                _ ->
                    []
    in
    div []
        [ input
            [ type_ "text"
            , placeholder t.addRole
            , value roleInput
            , onInput SetRoleInput
            , on "change" (Decode.map AddRole targetValue)
            , list "user-roles-options"
            , class "w-full rounded-lg border border-zinc-200 bg-white px-2.5 py-1.5 text-[13px] text-zinc-900 transition-colors placeholder:text-zinc-400 focus:border-zinc-400 focus:outline-none"
            ]
            []
        , datalist [ id "user-roles-options" ]
            (List.map (\role -> option [ value role.name ] []) options)
        ]


roleByName : List RoleResponse -> String -> Maybe RoleResponse
roleByName roles name =
    List.filter (\role -> role.name == name) roles
        |> List.head


viewUser : UserResponse -> Html Msg
viewUser user =
    div [ class "flex flex-col gap-0.5" ]
        [ span [ class "text-sm font-semibold text-zinc-900" ]
            [ text (Maybe.withDefault user.email user.name) ]
        , span [ class "text-[13px] text-zinc-500" ] [ text user.email ]
        ]


type Node
    = Node { name : String, segment : String, children : List Node }


viewTree : T -> Bool -> Remote (List PermissionInfo) -> Selection -> Html Msg
viewTree t canGrant permissions selection =
    case ( permissions, selection.direct, selection.inherited ) of
        ( Loaded catalog, Loaded direct, Loaded inherited ) ->
            div [ class "flex flex-col" ]
                (List.concatMap (viewNode t canGrant selection.user.isAdmin catalog direct inherited 0) (buildForest catalog))

        ( Failed, _, _ ) ->
            hint t.couldNotLoadPermissions

        ( _, Failed, _ ) ->
            hint t.couldNotLoad

        ( _, _, Failed ) ->
            hint t.couldNotLoad

        _ ->
            hint t.loading


{-| Turn the flat catalog into a forest, following the parent links.
-}
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


viewNode : T -> Bool -> Bool -> List PermissionInfo -> List String -> List String -> Int -> Node -> List (Html Msg)
viewNode t canGrant admin catalog direct inherited depth (Node node) =
    viewRow t canGrant admin catalog direct inherited depth node
        :: List.concatMap (viewNode t canGrant admin catalog direct inherited (depth + 1)) node.children


{-| One row. The checkbox reflects the leaves under the node: ticked when all are
granted, a dash when some are, empty when none. A leaf granted only through a role
is shown locked, because you change that on the role.
-}
viewRow t canGrant admin catalog direct inherited depth node =
    let
        leaves =
            controlledLeaves catalog node.name

        effective leaf =
            admin || List.member leaf direct || List.member leaf inherited

        grantedCount =
            List.length (List.filter effective leaves)

        total =
            List.length leaves

        allChecked =
            total > 0 && grantedCount == total

        indeterminate =
            grantedCount > 0 && grantedCount < total

        isLeafNode =
            List.isEmpty node.children

        fromRoleOnly =
            not admin
                && isLeafNode
                && List.member node.name inherited
                && not (List.member node.name direct)
    in
    label
        [ class "flex items-center gap-2 rounded-md py-1 pr-2 text-[13px] hover:bg-zinc-50"
        , style "padding-left" (String.fromInt (8 + depth * 16) ++ "px")
        ]
        [ input
            [ type_ "checkbox"
            , checked allChecked
            , property "indeterminate" (Encode.bool indeterminate)
            , disabled (not canGrant || admin)
            , onClick (ClickNode node.name)
            , class "h-3.5 w-3.5 accent-zinc-900 disabled:opacity-50"
            ]
            []
        , span
            [ class
                (if isLeafNode then
                    if fromRoleOnly then
                        "text-zinc-400"

                    else
                        "text-zinc-700"

                 else
                    "font-medium text-zinc-800"
                )
            ]
            [ text node.segment ]
        , if fromRoleOnly then
            span [ class "text-[10px] uppercase tracking-wide text-zinc-300" ] [ text t.roleTag ]

          else
            text ""
        ]


{-| Whether no node names this one as a parent, so it is a leaf permission.
-}
isLeaf : List PermissionInfo -> String -> Bool
isLeaf catalog name =
    not (List.any (\permission -> permission.parent == Just name) catalog)


{-| The leaf permissions a node controls: itself if it is a leaf, otherwise every
leaf under it. These are the names a click grants or revokes.
-}
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


section : String -> Html Msg -> Html Msg
section title body =
    div [ class "flex flex-col gap-1.5" ]
        [ h2 [ class "text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-400" ] [ text title ]
        , body
        ]


viewForm : T -> Form -> Html Msg
viewForm t form_ =
    form
        [ onSubmit Submit
        , class "flex flex-col gap-3.5 rounded-xl border border-zinc-200/70 bg-white p-5 shadow-sm"
        ]
        [ Input.view
            { label = t.email
            , type_ = "email"
            , placeholder = t.loginEmailPlaceholder
            , value = form_.email
            , onInput = SetEmail
            }
        , Input.view
            { label = t.name
            , type_ = "text"
            , placeholder = t.optionalField
            , value = form_.name
            , onInput = SetName
            }
        , Input.view
            { label = t.password
            , type_ = "password"
            , placeholder = t.atLeast8
            , value = form_.password
            , onInput = SetPassword
            }
        , label [ class "flex items-center gap-2 text-sm text-zinc-700" ]
            [ input
                [ type_ "checkbox"
                , checked form_.isAdmin
                , onCheck SetAdmin
                , class "h-4 w-4 accent-zinc-900"
                ]
                []
            , text t.admin
            ]
        , viewError t form_.error
        , Button.primary [ type_ "submit", disabled form_.submitting ]
            [ text
                (if form_.submitting then
                    t.creating

                 else
                    t.createUser
                )
            ]
        ]


viewError : T -> Maybe Http.Error -> Html Msg
viewError t maybeError =
    case maybeError of
        Just error ->
            p [ class "text-[13px] text-red-600" ] [ text (createError t error) ]

        Nothing ->
            text ""


hint : String -> Html Msg
hint message =
    p [ class "text-[13px] text-zinc-500" ] [ text message ]
