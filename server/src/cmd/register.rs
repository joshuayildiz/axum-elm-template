use std::io;

pub(crate) async fn cmd() -> io::Result<()> {
    use argon2::{Argon2, PasswordHasher};
    use dialoguer::theme::ColorfulTheme;
    use dialoguer::{Confirm, Input, Password};

    let config = crate::config::Config::from_env();
    let pool = crate::db::connect(&config.database_url).await;

    let theme = ColorfulTheme::default();

    let email: String = Input::with_theme(&theme)
        .with_prompt("Email")
        .interact_text()
        .expect("error reading email");

    let name: String = Input::with_theme(&theme)
        .with_prompt("Name")
        .allow_empty(true)
        .interact_text()
        .expect("error reading name");

    let password: String = Password::with_theme(&theme)
        .with_prompt("Password")
        .with_confirmation("Confirm password", "Passwords do not match")
        .interact()
        .expect("error reading password");

    let is_admin = Confirm::with_theme(&theme)
        .with_prompt("Make this user an admin?")
        .default(false)
        .interact()
        .expect("error reading admin choice");

    let password_hash = Argon2::default()
        .hash_password(password.as_bytes())
        .expect("error hashing password")
        .to_string();

    let name = if name.is_empty() { None } else { Some(name) };

    sqlx::query!(
        "insert into users (email, password_hash, name, is_admin) values ($1, $2, $3, $4)",
        email.as_str(),
        password_hash.as_str(),
        name.as_deref(),
        is_admin,
    )
    .execute(&pool)
    .await
    .expect("error inserting user");

    println!("Registered {email}");
    Ok(())
}
