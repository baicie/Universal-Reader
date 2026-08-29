use std::{env, time::Duration};

use axum::{
    Json,
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::{Deserialize, Serialize};

use crate::AppState;

#[derive(Clone)]
pub struct AiConfig {
    endpoint: String,
    api_key: String,
    http: reqwest::Client,
}

impl AiConfig {
    pub fn from_env() -> Self {
        Self::new(
            env::var("UNIVERSAL_READER_DEEPSEEK_ENDPOINT")
                .unwrap_or_else(|_| "https://api.deepseek.com".to_string()),
            env::var("UNIVERSAL_READER_DEEPSEEK_API_KEY").unwrap_or_default(),
        )
    }

    pub fn new(endpoint: String, api_key: String) -> Self {
        let endpoint = endpoint.trim().to_string();
        Self {
            endpoint: if endpoint.is_empty() {
                "https://api.deepseek.com".to_string()
            } else {
                endpoint
            },
            api_key: api_key.trim().to_string(),
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(60))
                .build()
                .unwrap_or_else(|_| reqwest::Client::new()),
        }
    }

    pub fn configured(&self) -> bool {
        !self.api_key.is_empty()
    }
}

#[derive(Serialize)]
pub struct AiStatusResponse {
    pub configured: bool,
    pub provider: &'static str,
}

#[derive(Deserialize)]
pub struct ChatRequest {
    pub model: String,
    pub messages: Vec<ChatMessage>,
    pub api_key: Option<String>,
}

#[derive(Deserialize, Serialize, Clone)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Serialize)]
pub struct ChatResponse {
    pub content: String,
}

#[derive(Serialize)]
struct UpstreamChatRequest<'a> {
    model: &'a str,
    messages: &'a [ChatMessage],
    temperature: f32,
}

#[derive(Deserialize)]
struct UpstreamChatResponse {
    choices: Vec<UpstreamChoice>,
}

#[derive(Deserialize)]
struct UpstreamChoice {
    message: UpstreamMessage,
}

#[derive(Deserialize)]
struct UpstreamMessage {
    content: Option<String>,
}

pub fn chat_completions_url(endpoint: &str) -> String {
    let base = endpoint.trim().trim_end_matches('/');
    if base.ends_with("/chat/completions") {
        base.to_string()
    } else if base.ends_with("/v1") {
        format!("{base}/chat/completions")
    } else {
        format!("{base}/v1/chat/completions")
    }
}

fn allowed_model(model: &str) -> bool {
    matches!(model, "deepseek-chat" | "deepseek-reasoner")
}

fn error_response(status: StatusCode, error: &'static str) -> Response {
    (status, Json(crate::ApiError { error })).into_response()
}

pub async fn ai_status(State(state): State<AppState>) -> Json<AiStatusResponse> {
    Json(AiStatusResponse {
        configured: state.ai.configured(),
        provider: "deepseek",
    })
}

pub async fn ai_chat(
    State(state): State<AppState>,
    Json(body): Json<ChatRequest>,
) -> impl IntoResponse {
    if !allowed_model(body.model.trim()) {
        return error_response(
            StatusCode::BAD_REQUEST,
            "model must be deepseek-chat or deepseek-reasoner",
        );
    }
    if body.messages.is_empty() || body.messages.len() > 20 {
        return error_response(
            StatusCode::BAD_REQUEST,
            "messages must contain 1 to 20 items",
        );
    }
    for message in &body.messages {
        if !matches!(message.role.as_str(), "system" | "user" | "assistant") {
            return error_response(
                StatusCode::BAD_REQUEST,
                "message role must be system, user, or assistant",
            );
        }
        if message.content.len() > 16 * 1024 {
            return error_response(StatusCode::BAD_REQUEST, "message content is too large");
        }
    }
    let api_key = body
        .api_key
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(state.ai.api_key.as_str());
    if api_key.is_empty() {
        return error_response(
            StatusCode::SERVICE_UNAVAILABLE,
            "deepseek api key is not configured",
        );
    }
    let url = chat_completions_url(&state.ai.endpoint);
    let response = state
        .ai
        .http
        .post(url)
        .bearer_auth(api_key)
        .json(&UpstreamChatRequest {
            model: body.model.trim(),
            messages: &body.messages,
            temperature: 0.2,
        })
        .send()
        .await;
    let Ok(response) = response else {
        return error_response(StatusCode::BAD_GATEWAY, "deepseek request failed");
    };
    if !response.status().is_success() {
        return error_response(StatusCode::BAD_GATEWAY, "deepseek returned an error");
    }
    let Ok(parsed) = response.json::<UpstreamChatResponse>().await else {
        return error_response(
            StatusCode::BAD_GATEWAY,
            "deepseek returned unreadable content",
        );
    };
    let Some(content) = parsed
        .choices
        .first()
        .and_then(|choice| choice.message.content.as_deref())
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return error_response(StatusCode::BAD_GATEWAY, "deepseek returned no text");
    };
    (
        StatusCode::OK,
        Json(ChatResponse {
            content: content.to_string(),
        }),
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::chat_completions_url;

    #[test]
    fn builds_the_official_deepseek_chat_url() {
        assert_eq!(
            chat_completions_url("https://api.deepseek.com"),
            "https://api.deepseek.com/v1/chat/completions"
        );
        assert_eq!(
            chat_completions_url("https://api.deepseek.com/v1"),
            "https://api.deepseek.com/v1/chat/completions"
        );
    }
}
