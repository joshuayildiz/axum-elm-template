module I18n exposing (Lang(..), T, all, fromString, label, toString, translations)

{-| The translation layer. One record type, `T`, holds every user-facing string.
Each language is one complete value of that record, so the compiler rejects a
language that misses a key.

To add a language: add a variant to `Lang`, copy one of the records below, and
translate every field. The compiler then lists every screen that must wire it in.

-}


type Lang
    = En
    | Tr


{-| Every language the app offers, in the order the switcher shows them.
-}
all : List Lang
all =
    [ En, Tr ]


{-| The language's own name, for the switcher. This does not change with the
current language.
-}
label : Lang -> String
label lang =
    case lang of
        En ->
            "English"

        Tr ->
            "Türkçe"


{-| The short code stored in the browser. `fromString` is its inverse.
-}
toString : Lang -> String
toString lang =
    case lang of
        En ->
            "en"

        Tr ->
            "tr"


{-| Read a browser language tag or a stored code. A tag that starts with `tr`
(so `tr` and `tr-TR`) is Turkish. Every other value falls back to English.
-}
fromString : String -> Lang
fromString tag =
    if String.startsWith "tr" (String.toLower tag) then
        Tr

    else
        En


translations : Lang -> T
translations lang =
    case lang of
        En ->
            en

        Tr ->
            tr


{-| One field per user-facing string, grouped by area. Reuse a field when the
same word means the same thing on more than one screen.
-}
type alias T =
    { -- Common words, reused across screens
      cancel : String
    , delete : String
    , loading : String
    , couldNotLoad : String
    , couldNotLoadPermissions : String
    , previous : String
    , next : String
    , pageWord : String
    , ofWord : String
    , themeSystem : String
    , themeLight : String
    , themeDark : String
    , email : String
    , name : String
    , password : String
    , description : String
    , admin : String
    , users : String
    , roles : String
    , permissions : String
    , home : String

    -- App chrome (Main)
    , notFound : String
    , goHome : String

    -- Sidebar
    , menu : String
    , signedInAs : String
    , logOut : String

    -- Login
    , signIn : String
    , signingIn : String
    , loginEmailPlaceholder : String
    , loginPasswordPlaceholder : String
    , authInvalid : String
    , authDeactivated : String
    , authNotSignedIn : String
    , createAccount : String
    , registrationDisabled : String
    , haveAccount : String
    , needAccount : String

    -- HTTP errors (Api.errorToString). The *Prefix fields are joined with a
    -- value, for example the status code or the URL.
    , errBadUrlPrefix : String
    , errTimeout : String
    , errNetwork : String
    , errBadStatusPrefix : String
    , errBadBodyPrefix : String

    -- Users page
    , createUser : String
    , creating : String
    , searchUsers : String
    , loadingUsers : String
    , couldNotLoadUsers : String
    , noUsersMatch : String
    , deleteUser : String
    , deleteUserConfirmPrefix : String
    , deleteUserConfirmSuffix : String
    , noRoles : String
    , addRole : String
    , roleTag : String
    , optionalField : String
    , atLeast8 : String
    , errEmailInUse : String
    , errUserInvalid : String
    , errNoPermissionCreateUser : String

    -- Roles page
    , createRole : String
    , searchRoles : String
    , loadingRoles : String
    , couldNotLoadRoles : String
    , noRolesMatch : String
    , deleteRole : String
    , deleteRoleConfirmPrefix : String
    , deleteRoleConfirmSuffix : String
    , noDescriptionPlaceholder : String
    , noDescription : String
    , roleNamePlaceholder : String
    , errRoleNameInUse : String
    , errRoleNameRequired : String
    , errNoPermissionCreateRole : String

    -- Home page (Root). The headline "Axum + Elm" is a name and stays in the view.
    , rootBadge : String
    , rootTagline : String
    , rootBody : String
    , rootEditPrefix : String
    , rootEditSuffix : String

    -- Realtime presence and broadcast
    , online : String
    , offline : String
    , broadcastTitle : String
    , broadcastPlaceholder : String
    , broadcastSend : String
    , broadcastEmpty : String
    , security : String
    , account : String
    , changePassword : String
    , currentPassword : String
    , newPassword : String
    , updatePassword : String
    , passwordUpdated : String
    , errIncorrectPassword : String
    , errPasswordTooShort : String
    , twoFactor : String
    , twoFactorOn : String
    , twoFactorOff : String
    , twoFactorIntro : String
    , twoFactorSecretLabel : String
    , code : String
    , codePlaceholder : String
    , turnOn : String
    , turnOff : String
    , setUp : String
    , twoFactorEnabledMsg : String
    , twoFactorDisabledMsg : String
    , close : String
    , enterCode : String
    , verify : String
    , authInvalidCode : String
    , settings : String
    , settingsIntro : String
    , save : String
    , saved : String
    , settingsSaveError : String
    , settingRegistrationEnabled : String
    , settingCompanyName : String
    }


en : T
en =
    { cancel = "Cancel"
    , delete = "Delete"
    , loading = "Loading..."
    , couldNotLoad = "Could not load."
    , couldNotLoadPermissions = "Could not load permissions."
    , previous = "Previous"
    , next = "Next"
    , pageWord = "Page"
    , ofWord = "of"
    , themeSystem = "System"
    , themeLight = "Light"
    , themeDark = "Dark"
    , email = "Email"
    , name = "Name"
    , password = "Password"
    , description = "Description"
    , admin = "Admin"
    , users = "Users"
    , roles = "Roles"
    , permissions = "Permissions"
    , home = "Home"
    , notFound = "Not found"
    , goHome = "Go home"
    , menu = "Menu"
    , signedInAs = "Signed in as"
    , logOut = "Log out"
    , signIn = "Sign in"
    , signingIn = "Signing in..."
    , loginEmailPlaceholder = "you@example.com"
    , loginPasswordPlaceholder = "Your password"
    , authInvalid = "Incorrect email or password."
    , authDeactivated = "This account is deactivated."
    , authNotSignedIn = "You are not signed in."
    , createAccount = "Create account"
    , registrationDisabled = "Registration is turned off."
    , haveAccount = "Already have an account?"
    , needAccount = "Need an account?"
    , errBadUrlPrefix = "Bad URL: "
    , errTimeout = "The request timed out."
    , errNetwork = "A network error occurred."
    , errBadStatusPrefix = "The server returned status "
    , errBadBodyPrefix = "The response body did not match: "
    , createUser = "Create user"
    , creating = "Creating..."
    , searchUsers = "Search users"
    , loadingUsers = "Loading users..."
    , couldNotLoadUsers = "Could not load users."
    , noUsersMatch = "No users match."
    , deleteUser = "Delete user"
    , deleteUserConfirmPrefix = "Delete \""
    , deleteUserConfirmSuffix = "\"? They will lose access immediately."
    , noRoles = "No roles."
    , addRole = "Add role"
    , roleTag = "role"
    , optionalField = "Optional"
    , atLeast8 = "At least 8 characters"
    , errEmailInUse = "That email is already in use."
    , errUserInvalid = "Enter a valid email and a password of at least 8 characters."
    , errNoPermissionCreateUser = "You do not have permission to create a user."
    , createRole = "Create role"
    , searchRoles = "Search roles"
    , loadingRoles = "Loading roles..."
    , couldNotLoadRoles = "Could not load roles."
    , noRolesMatch = "No roles match."
    , deleteRole = "Delete role"
    , deleteRoleConfirmPrefix = "Delete \""
    , deleteRoleConfirmSuffix = "\"? This cannot be undone."
    , noDescriptionPlaceholder = "No description"
    , noDescription = "No description."
    , roleNamePlaceholder = "Role name"
    , errRoleNameInUse = "That role name is already in use."
    , errRoleNameRequired = "Enter a role name."
    , errNoPermissionCreateRole = "You do not have permission to create a role."
    , rootBadge = "Running"
    , rootTagline = "Typed, calm, and ready."
    , rootBody = "This is the home page. The server is running and you are signed in. Build your own screens from here."
    , rootEditPrefix = "Edit "
    , rootEditSuffix = " to change this page."
    , online = "online"
    , offline = "offline"
    , broadcastTitle = "Live broadcast"
    , broadcastPlaceholder = "Send a line to everyone"
    , broadcastSend = "Send"
    , broadcastEmpty = "No messages yet."
    , security = "Security"
    , account = "Account"
    , changePassword = "Change password"
    , currentPassword = "Current password"
    , newPassword = "New password"
    , updatePassword = "Update password"
    , passwordUpdated = "Password updated."
    , errIncorrectPassword = "Your current password is incorrect."
    , errPasswordTooShort = "The new password must be at least 8 characters."
    , twoFactor = "Two-factor authentication"
    , twoFactorOn = "Two-factor is on."
    , twoFactorOff = "Two-factor is off."
    , twoFactorIntro = "Scan this code with an authenticator app, then enter the 6-digit code to turn it on."
    , twoFactorSecretLabel = "Or enter this secret by hand:"
    , code = "Code"
    , codePlaceholder = "123456"
    , turnOn = "Turn on"
    , turnOff = "Turn off"
    , setUp = "Set up"
    , twoFactorEnabledMsg = "Two-factor is now on."
    , twoFactorDisabledMsg = "Two-factor is now off."
    , close = "Close"
    , enterCode = "Enter the code from your authenticator app."
    , verify = "Verify"
    , authInvalidCode = "That code is not valid. Try again."
    , settings = "Settings"
    , settingsIntro = "Manage application settings. Changes apply right away."
    , save = "Save"
    , saved = "Settings saved."
    , settingsSaveError = "Could not save settings."
    , settingRegistrationEnabled = "Allow registration"
    , settingCompanyName = "Company name"
    }


tr : T
tr =
    { cancel = "İptal"
    , delete = "Sil"
    , loading = "Yükleniyor..."
    , couldNotLoad = "Yüklenemedi."
    , couldNotLoadPermissions = "İzinler yüklenemedi."
    , previous = "Önceki"
    , next = "Sonraki"
    , pageWord = "Sayfa"
    , ofWord = "/"
    , themeSystem = "Sistem"
    , themeLight = "Açık"
    , themeDark = "Koyu"
    , email = "E-posta"
    , name = "Ad"
    , password = "Parola"
    , description = "Açıklama"
    , admin = "Yönetici"
    , users = "Kullanıcılar"
    , roles = "Roller"
    , permissions = "İzinler"
    , home = "Ana Sayfa"
    , notFound = "Bulunamadı"
    , goHome = "Ana sayfaya git"
    , menu = "Menü"
    , signedInAs = "Oturum açan"
    , logOut = "Çıkış yap"
    , signIn = "Giriş yap"
    , signingIn = "Giriş yapılıyor..."
    , loginEmailPlaceholder = "siz@ornek.com"
    , loginPasswordPlaceholder = "Parolanız"
    , authInvalid = "E-posta veya parola hatalı."
    , authDeactivated = "Bu hesap devre dışı bırakılmış."
    , authNotSignedIn = "Oturum açmadınız."
    , createAccount = "Hesap oluştur"
    , registrationDisabled = "Kayıt kapalı."
    , haveAccount = "Zaten hesabınız var mı?"
    , needAccount = "Hesabınız yok mu?"
    , errBadUrlPrefix = "Geçersiz URL: "
    , errTimeout = "İstek zaman aşımına uğradı."
    , errNetwork = "Bir ağ hatası oluştu."
    , errBadStatusPrefix = "Sunucu şu durumu döndürdü: "
    , errBadBodyPrefix = "Yanıt gövdesi eşleşmedi: "
    , createUser = "Kullanıcı oluştur"
    , creating = "Oluşturuluyor..."
    , searchUsers = "Kullanıcı ara"
    , loadingUsers = "Kullanıcılar yükleniyor..."
    , couldNotLoadUsers = "Kullanıcılar yüklenemedi."
    , noUsersMatch = "Eşleşen kullanıcı yok."
    , deleteUser = "Kullanıcıyı sil"
    , deleteUserConfirmPrefix = "\""
    , deleteUserConfirmSuffix = "\" kullanıcısı silinsin mi? Erişimini hemen kaybeder."
    , noRoles = "Rol yok."
    , addRole = "Rol ekle"
    , roleTag = "rol"
    , optionalField = "İsteğe bağlı"
    , atLeast8 = "En az 8 karakter"
    , errEmailInUse = "Bu e-posta zaten kullanımda."
    , errUserInvalid = "Geçerli bir e-posta ve en az 8 karakterlik bir parola girin."
    , errNoPermissionCreateUser = "Kullanıcı oluşturma yetkiniz yok."
    , createRole = "Rol oluştur"
    , searchRoles = "Rol ara"
    , loadingRoles = "Roller yükleniyor..."
    , couldNotLoadRoles = "Roller yüklenemedi."
    , noRolesMatch = "Eşleşen rol yok."
    , deleteRole = "Rolü sil"
    , deleteRoleConfirmPrefix = "\""
    , deleteRoleConfirmSuffix = "\" rolü silinsin mi? Bu geri alınamaz."
    , noDescriptionPlaceholder = "Açıklama yok"
    , noDescription = "Açıklama yok."
    , roleNamePlaceholder = "Rol adı"
    , errRoleNameInUse = "Bu rol adı zaten kullanımda."
    , errRoleNameRequired = "Bir rol adı girin."
    , errNoPermissionCreateRole = "Rol oluşturma yetkiniz yok."
    , rootBadge = "Çalışıyor"
    , rootTagline = "Tipli, sakin ve hazır."
    , rootBody = "Burası ana sayfa. Sunucu çalışıyor ve oturum açtınız. Kendi ekranlarınızı buradan oluşturun."
    , rootEditPrefix = "Bu sayfayı değiştirmek için "
    , rootEditSuffix = " dosyasını düzenleyin."
    , online = "çevrimiçi"
    , offline = "çevrimdışı"
    , broadcastTitle = "Canlı yayın"
    , broadcastPlaceholder = "Herkese bir satır gönderin"
    , broadcastSend = "Gönder"
    , broadcastEmpty = "Henüz mesaj yok."
    , security = "Güvenlik"
    , account = "Hesap"
    , changePassword = "Parolayı değiştir"
    , currentPassword = "Mevcut parola"
    , newPassword = "Yeni parola"
    , updatePassword = "Parolayı güncelle"
    , passwordUpdated = "Parola güncellendi."
    , errIncorrectPassword = "Mevcut parolanız hatalı."
    , errPasswordTooShort = "Yeni parola en az 8 karakter olmalı."
    , twoFactor = "İki adımlı doğrulama"
    , twoFactorOn = "İki adımlı doğrulama açık."
    , twoFactorOff = "İki adımlı doğrulama kapalı."
    , twoFactorIntro = "Bu kodu bir kimlik doğrulama uygulamasıyla tarayın, sonra açmak için 6 haneli kodu girin."
    , twoFactorSecretLabel = "Veya bu gizli anahtarı elle girin:"
    , code = "Kod"
    , codePlaceholder = "123456"
    , turnOn = "Aç"
    , turnOff = "Kapat"
    , setUp = "Kur"
    , twoFactorEnabledMsg = "İki adımlı doğrulama artık açık."
    , twoFactorDisabledMsg = "İki adımlı doğrulama artık kapalı."
    , close = "Kapat"
    , enterCode = "Kimlik doğrulama uygulamanızdaki kodu girin."
    , verify = "Doğrula"
    , authInvalidCode = "Bu kod geçerli değil. Tekrar deneyin."
    , settings = "Ayarlar"
    , settingsIntro = "Uygulama ayarlarını yönetin. Değişiklikler hemen uygulanır."
    , save = "Kaydet"
    , saved = "Ayarlar kaydedildi."
    , settingsSaveError = "Ayarlar kaydedilemedi."
    , settingRegistrationEnabled = "Kayıt olmaya izin ver"
    , settingCompanyName = "Şirket adı"
    }
