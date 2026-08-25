use std::{env, net::SocketAddr};

use universal_reader_server::app;

#[tokio::main]
async fn main() {
    let port = env::var("UNIVERSAL_READER_SERVER_PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(8787);
    let address = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = tokio::net::TcpListener::bind(address)
        .await
        .expect("failed to bind Universal Reader server");

    println!("Universal Reader server listening on http://{address}");
    axum::serve(listener, app())
        .await
        .expect("Universal Reader server stopped unexpectedly");
}
