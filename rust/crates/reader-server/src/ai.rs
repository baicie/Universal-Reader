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
    ollama_endpoint: String,
    http: reqwest::Client,
}

impl AiConfig {
    pub fn from_env() -> Self {
        Self::new_with_ollama(
            env::var("UNIVERSAL_READER_DEEPSEEK_ENDPOINT")
                .unwrap_or_else(|_| "https://api.deepseek.com".to_string()),
            env::var("UNIVERSAL_READER_DEEPSEEK_API_KEY").unwrap_or_default(),
            env::var("UNIVERSAL_READER_OLLAMA_ENDPOINT")
                .unwrap_or_else(|_| "http://127.0.0.1:11434".to_string()),
        )
    }

    pub fn new(endpoint: String, api_key: String) -> Self {
        Self::new_with_ollama(endpoint, api_key, "http://127.0.0.1:11434".to_string())
    }

    pub fn new_with_ollama(endpoint: String, api_key: String, ollama_endpoint: String) -> Self {
        let endpoint = endpoint.trim().to_string();
        let ollama_endpoint = ollama_endpoint.trim().to_string();
        Self {
            endpoint: if endpoint.is_empty() {
                "https://api.deepseek.com".to_string()
            } else {
                endpoint
            },
            api_key: api_key.trim().to_string(),
            ollama_endpoint: if ollama_endpoint.is_empty() {
                "http://127.0.0.1:11434".to_string()
            } else {
                ollama_endpoint
            },
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
    pub providers: AiProviders,
}

#[derive(Serialize)]
pub struct AiProviders {
    pub deepseek: bool,
    pub ollama: bool,
}

#[derive(Deserialize)]
pub struct ChatRequest {
    pub model: String,
    pub messages: Vec<ChatMessage>,
    pub api_key: Option<String>,
    pub provider: Option<String>,
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

fn allowed_ollama_model(model: &str) -> bool {
    let model = model.trim();
    !model.is_empty()
        && model.len() <= 64
        && model
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '.' | '-' | '_' | ':' | '/'))
}

fn error_response(status: StatusCode, error: &'static str) -> Response {
    (status, Json(crate::ApiError { error })).into_response()
}

pub async fn ai_status(State(state): State<AppState>) -> Json<AiStatusResponse> {
    Json(AiStatusResponse {
        configured: state.ai.configured(),
        provider: "deepseek",
        providers: AiProviders {
            deepseek: state.ai.configured(),
            ollama: true,
        },
    })
}

pub async fn ai_chat(
    State(state): State<AppState>,
    Json(body): Json<ChatRequest>,
) -> impl IntoResponse {
    let provider = body
        .provider
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("deepseek");
    let use_ollama = provider == "ollama";
    if use_ollama {
        if !allowed_ollama_model(body.model.trim()) {
            return error_response(StatusCode::BAD_REQUEST, "ollama model is invalid");
        }
    } else if !allowed_model(body.model.trim()) {
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
    if !use_ollama && api_key.is_empty() {
        return error_response(
            StatusCode::SERVICE_UNAVAILABLE,
            "deepseek api key is not configured",
        );
    }
    let url = chat_completions_url(if use_ollama {
        &state.ai.ollama_endpoint
    } else {
        &state.ai.endpoint
    });
    let mut request = state.ai.http.post(url).json(&UpstreamChatRequest {
        model: body.model.trim(),
        messages: &body.messages,
        temperature: 0.2,
    });
    if !api_key.is_empty() {
        request = request.bearer_auth(api_key);
    }
    let response = request.send().await;
    let Ok(response) = response else {
        return error_response(StatusCode::BAD_GATEWAY, "upstream request failed");
    };
    if !response.status().is_success() {
        return error_response(StatusCode::BAD_GATEWAY, "upstream returned an error");
    }
    let Ok(parsed) = response.json::<UpstreamChatResponse>().await else {
        return error_response(
            StatusCode::BAD_GATEWAY,
            "upstream returned unreadable content",
        );
    };
    let Some(content) = parsed
        .choices
        .first()
        .and_then(|choice| choice.message.content.as_deref())
        .map(str::trim)
        .filter(|value| !value.is_empty())
    else {
        return error_response(StatusCode::BAD_GATEWAY, "upstream returned no text");
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
