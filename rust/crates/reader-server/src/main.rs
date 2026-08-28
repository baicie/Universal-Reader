use std::{env, net::SocketAddr};

use universal_reader_server::{app_for_server, resolve_web_dir};

#[tokio::main]
async fn main() {
    let port = env::var("UNIVERSAL_READER_SERVER_PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(8787);
    let bind = env::var("UNIVERSAL_READER_SERVER_BIND").unwrap_or_else(|_| "127.0.0.1".into());
    let address = format!("{bind}:{port}")
        .parse::<SocketAddr>()
        .unwrap_or_else(|_| SocketAddr::from(([127, 0, 0, 1], port)));
    let listener = tokio::net::TcpListener::bind(address)
        .await
        .expect("failed to bind Universal Reader server");

    match resolve_web_dir() {
        Some(web_dir) => println!(
            "Universal Reader server listening on http://{address} (web {})",
            web_dir.display()
        ),
        None => println!(
            "Universal Reader server listening on http://{address} (API only; place Flutter web assets in ./web)"
        ),
    }
    axum::serve(listener, app_for_server())
        .await
        .expect("Universal Reader server stopped unexpectedly");
}
