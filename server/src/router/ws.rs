use super::AppState;
use crate::api::{ClientMessage, ServerMessage};
use crate::router::auth::extractors::{CurrentUser, require_auth};
use axum::Router;
use axum::extract::State;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::response::Response;
use axum::routing::any;
use futures_util::stream::SplitSink;
use futures_util::{SinkExt, StreamExt};
use tokio::sync::broadcast::error::RecvError;

// The websocket sits behind the same auth gate as the protected HTTP routes, so
// it needs no token code of its own. `require_auth` validates the cookie and
// puts the user in the request for the handler to read.
pub(crate) fn routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/api/v1/ws", any(ws_handler))
        .route_layer(axum::middleware::from_fn_with_state(state, require_auth))
}

async fn ws_handler(
    user: CurrentUser,
    State(state): State<AppState>,
    ws: WebSocketUpgrade,
) -> Response {
    ws.on_upgrade(move |socket| connection(socket, state, user.id, user.email))
}

// One task per connection. It greets the client with the online set, announces
// the user if this is their first connection, then forwards broadcast events out
// and reads client frames in until either side ends.
async fn connection(socket: WebSocket, state: AppState, user_id: String, email: String) {
    let (mut sender, mut receiver) = socket.split();
    let mut events = state.events.subscribe();

    let (became_online, snapshot) = {
        let mut presence = state.presence.lock().expect("error locking presence");
        let count = presence.entry(user_id.clone()).or_insert(0);
        *count += 1;
        let became_online = *count == 1;
        let snapshot = presence.keys().cloned().collect();
        (became_online, snapshot)
    };

    if send_message(&mut sender, &ServerMessage::Snapshot { online: snapshot })
        .await
        .is_err()
    {
        disconnect(&state, &user_id);
        return;
    }

    if became_online {
        let _ = state.events.send(ServerMessage::Online {
            user_id: user_id.clone(),
        });
    }

    loop {
        tokio::select! {
            event = events.recv() => {
                match event {
                    Ok(message) => {
                        if send_message(&mut sender, &message).await.is_err() {
                            break;
                        }
                    }
                    Err(RecvError::Lagged(_)) => {}
                    Err(RecvError::Closed) => break,
                }
            }
            frame = receiver.next() => {
                match frame {
                    Some(Ok(Message::Text(text))) => {
                        if let Ok(ClientMessage::SendBroadcast { text }) = serde_json::from_str(text.as_str()) {
                            let text = text.trim();
                            if !text.is_empty() {
                                let _ = state.events.send(ServerMessage::Broadcast {
                                    from: email.clone(),
                                    text: text.to_string(),
                                });
                            }
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Ok(_)) => {}
                    Some(Err(_)) => break,
                }
            }
        }
    }

    disconnect(&state, &user_id);
}

// Drop one connection for the user. When it was their last, announce that they
// went offline.
fn disconnect(state: &AppState, user_id: &str) {
    let went_offline = {
        let mut presence = state.presence.lock().expect("error locking presence");
        match presence.get_mut(user_id) {
            Some(count) => {
                *count -= 1;
                if *count == 0 {
                    presence.remove(user_id);
                    true
                } else {
                    false
                }
            }
            None => false,
        }
    };

    if went_offline {
        let _ = state.events.send(ServerMessage::Offline {
            user_id: user_id.to_string(),
        });
    }
}

async fn send_message(
    sender: &mut SplitSink<WebSocket, Message>,
    message: &ServerMessage,
) -> Result<(), ()> {
    let json = serde_json::to_string(message).expect("error encoding server message");
    sender
        .send(Message::Text(json.into()))
        .await
        .map_err(|_| ())
}
