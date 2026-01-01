use axum::{
    Json, Router,
    extract::State,
    http::{Request, StatusCode},
    middleware::{self, Next},
    response::Response,
    routing::post,
};
use clap::Parser;
use jsonwebtoken::{Algorithm, DecodingKey, Validation};
use serde::{Deserialize, Serialize};
use serde_json::{Value as JsonValue, json};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::{debug, error, info, warn};

const JSONRPC_VERSION: &str = "2.0";
const JWT_SECRET_LENGTH: usize = 32;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long, default_value = "8551", help = "Engine API port")]
    port: u16,

    #[arg(long, default_value = "127.0.0.1")]
    host: String,

    #[arg(long, help = "Path to JWT secret file (hex encoded)")]
    jwt_secret: Option<PathBuf>,

    #[arg(long, default_value = "8545", help = "HTTP RPC port")]
    rpc_port: u16,

    #[arg(long, default_value = "8546", help = "WebSocket port")]
    ws_port: u16,

    #[arg(long, default_value = "9001", help = "Metrics port")]
    metrics_port: u16,

    #[arg(long, default_value = "30303", help = "P2P discovery port (TCP/UDP)")]
    p2p_port: u16,
}

#[derive(Debug, Clone)]
struct AppState {
    jwt_secret: Option<Vec<u8>>,
}

#[derive(Debug, Serialize, Deserialize)]
struct JwtClaims {
    iat: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    clv: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    method: String,
    params: JsonValue,
    id: JsonValue,
}

#[derive(Debug, Serialize, Deserialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<JsonValue>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<JsonRpcError>,
    id: JsonValue,
}

#[derive(Debug, Serialize, Deserialize)]
struct JsonRpcError {
    code: i64,
    message: String,
}

async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    request: Request<axum::body::Body>,
    next: Next,
) -> Result<Response, (StatusCode, String)> {
    // If no JWT secret is configured, skip auth
    if state.jwt_secret.is_none() {
        return Ok(next.run(request).await);
    }

    let jwt_secret = state.jwt_secret.as_ref().unwrap();

    // Check for Authorization header
    let auth_header = request
        .headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok());

    match auth_header {
        Some(auth) if auth.starts_with("Bearer ") => {
            let token = &auth[7..]; // Skip "Bearer "

            // Validate JWT token
            let mut validation = Validation::new(Algorithm::HS256);
            validation.validate_exp = false;
            validation.required_spec_claims.remove("exp");

            match jsonwebtoken::decode::<JwtClaims>(
                token,
                &DecodingKey::from_secret(jwt_secret),
                &validation,
            ) {
                Ok(_) => {
                    debug!("JWT authentication successful");
                    Ok(next.run(request).await)
                }
                Err(e) => {
                    warn!("JWT validation failed: {:?}", e);
                    Err((StatusCode::UNAUTHORIZED, "Invalid JWT token".to_string()))
                }
            }
        }
        Some(_) => {
            warn!("Authorization header present but not in Bearer format");
            Err((
                StatusCode::UNAUTHORIZED,
                "Authorization header must be in format: Bearer <token>".to_string(),
            ))
        }
        None => {
            warn!("Missing Authorization header");
            Err((
                StatusCode::UNAUTHORIZED,
                "Missing Authorization header".to_string(),
            ))
        }
    }
}

async fn handle_rpc(
    State(_state): State<Arc<AppState>>,
    Json(request): Json<JsonRpcRequest>,
) -> (StatusCode, Json<JsonRpcResponse>) {
    info!(
        method = %request.method,
        params = ?request.params,
        "Received RPC request"
    );

    let result = match request.method.as_str() {
        "eth_syncing" => {
            debug!("eth_syncing: returning false (not syncing)");
            Ok(json!(false))
        }
        "eth_getBlockByNumber" => {
            debug!("eth_getBlockByNumber: returning null");
            Ok(json!(null))
        }
        "eth_getBlockByHash" => {
            debug!("eth_getBlockByHash: returning null");
            Ok(json!(null))
        }
        "engine_newPayloadV1"
        | "engine_newPayloadV2"
        | "engine_newPayloadV3"
        | "engine_newPayloadV4" => {
            debug!("{}: returning SYNCING status", request.method);
            Ok(json!({
                "status": "SYNCING",
                "latestValidHash": null,
                "validationError": null
            }))
        }
        "engine_forkchoiceUpdatedV1"
        | "engine_forkchoiceUpdatedV2"
        | "engine_forkchoiceUpdatedV3" => {
            debug!("{}: returning SYNCING status", request.method);
            Ok(json!({
                "payloadStatus": {
                    "status": "SYNCING",
                    "latestValidHash": null,
                    "validationError": null
                },
                "payloadId": null
            }))
        }
        "engine_getPayloadV1"
        | "engine_getPayloadV2"
        | "engine_getPayloadV3"
        | "engine_getPayloadV4"
        | "engine_getPayloadV5" => {
            debug!(
                "{}: returning error (payload not available)",
                request.method
            );
            Err(JsonRpcError {
                code: -38001,
                message: "Unknown payload".to_string(),
            })
        }
        "engine_getPayloadBodiesByHashV1" => {
            debug!("engine_getPayloadBodiesByHashV1: returning empty array");
            Ok(json!([]))
        }
        "engine_getPayloadBodiesByRangeV1" => {
            debug!("engine_getPayloadBodiesByRangeV1: returning empty array");
            Ok(json!([]))
        }
        "engine_exchangeCapabilities" => {
            let capabilities = vec![
                "engine_newPayloadV1",
                "engine_newPayloadV2",
                "engine_newPayloadV3",
                "engine_newPayloadV4",
                "engine_getPayloadV1",
                "engine_getPayloadV2",
                "engine_getPayloadV3",
                "engine_getPayloadV4",
                "engine_getPayloadV5",
                "engine_forkchoiceUpdatedV1",
                "engine_forkchoiceUpdatedV2",
                "engine_forkchoiceUpdatedV3",
                "engine_getPayloadBodiesByHashV1",
                "engine_getPayloadBodiesByRangeV1",
                "engine_getClientVersionV1",
                "engine_getBlobsV1",
                "engine_getBlobsV2",
            ];
            debug!(
                "engine_exchangeCapabilities: returning {} capabilities",
                capabilities.len()
            );
            Ok(json!(capabilities))
        }
        "engine_getClientVersionV1" => {
            debug!("engine_getClientVersionV1: returning client info");
            Ok(json!([{
                "code": "DM",
                "name": "Dummy-EL",
                "version": "v0.1.0",
                "commit": "00000000"
            }]))
        }
        "engine_getBlobsV1" | "engine_getBlobsV2" => {
            debug!("{}: returning empty array", request.method);
            Ok(json!([]))
        }
        _ => {
            info!(method = %request.method, "Method not found");
            Err(JsonRpcError {
                code: -32601,
                message: format!("Method not found: {}", request.method),
            })
        }
    };

    let response = match result {
        Ok(result) => JsonRpcResponse {
            jsonrpc: JSONRPC_VERSION.to_string(),
            result: Some(result),
            error: None,
            id: request.id,
        },
        Err(error) => JsonRpcResponse {
            jsonrpc: JSONRPC_VERSION.to_string(),
            result: None,
            error: Some(error),
            id: request.id,
        },
    };

    info!(method = %request.method, success = response.error.is_none(), "RPC response sent");
    (StatusCode::OK, Json(response))
}

// Simple RPC handler without JWT auth for non-Engine API ports
async fn handle_simple_rpc(
    Json(request): Json<JsonRpcRequest>,
) -> (StatusCode, Json<JsonRpcResponse>) {
    debug!(method = %request.method, "Received simple RPC request");

    let result: Result<JsonValue, JsonRpcError> = match request.method.as_str() {
        "admin_nodeInfo" => Ok(json!({
            "id": "0ecd4a2c5f7c2a304e3acbec67efea275510d31c304fe47f4e626a2ebd5fb101",
            "name": "Dummy-EL/v0.1.0",
            "enode": "enode://dummy@127.0.0.1:30303",
            "enr": "enr:-Iq4QDummy0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001",
            "ip": "127.0.0.1",
            "ports": {
                "discovery": 30303,
                "listener": 30303
            }
        })),
        _ => {
            // For any other method, just return a success response
            Ok(json!(null))
        }
    };

    let response = JsonRpcResponse {
        jsonrpc: JSONRPC_VERSION.to_string(),
        result: Some(result.unwrap_or(json!(null))),
        error: None,
        id: request.id,
    };

    (StatusCode::OK, Json(response))
}

fn strip_prefix(s: &str) -> &str {
    s.strip_prefix("0x").unwrap_or(s)
}

fn read_jwt_secret(path: &PathBuf) -> anyhow::Result<Vec<u8>> {
    let contents = std::fs::read_to_string(path)?;
    let hex_str = strip_prefix(contents.trim());
    let bytes = hex::decode(hex_str)?;

    if bytes.len() != JWT_SECRET_LENGTH {
        anyhow::bail!(
            "Invalid JWT secret length. Expected {} bytes, got {}",
            JWT_SECRET_LENGTH,
            bytes.len()
        );
    }

    Ok(bytes)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    let args = Args::parse();

    // Read JWT secret if provided
    let jwt_secret = match &args.jwt_secret {
        Some(path) => match read_jwt_secret(path) {
            Ok(secret) => {
                info!("JWT secret loaded from {:?}", path);
                Some(secret)
            }
            Err(e) => {
                error!("Failed to read JWT secret from {:?}: {}", path, e);
                return Err(e);
            }
        },
        None => {
            warn!("No JWT secret provided - authentication disabled!");
            warn!("This is insecure and should only be used for testing");
            None
        }
    };

    info!(
        host = %args.host,
        engine_port = args.port,
        rpc_port = args.rpc_port,
        ws_port = args.ws_port,
        metrics_port = args.metrics_port,
        p2p_port = args.p2p_port,
        jwt_auth = jwt_secret.is_some(),
        "Starting Dummy Execution Layer"
    );

    let state = Arc::new(AppState { jwt_secret });

    // Engine API server (port 8551) with JWT auth
    let engine_app = Router::new()
        .route("/", post(handle_rpc))
        .layer(middleware::from_fn_with_state(
            state.clone(),
            auth_middleware,
        ))
        .with_state(state.clone());

    let engine_addr = format!("{}:{}", args.host, args.port)
        .parse::<SocketAddr>()
        .expect("Invalid engine address");

    info!("Engine API listening on http://{}", engine_addr);

    // Simple RPC server for HTTP RPC (port 8545) - no JWT auth
    let rpc_app = Router::new().route("/", post(handle_simple_rpc));
    let rpc_addr = format!("{}:{}", args.host, args.rpc_port)
        .parse::<SocketAddr>()
        .expect("Invalid RPC address");
    info!("HTTP RPC listening on http://{}", rpc_addr);

    // Simple RPC server for WebSocket (port 8546) - no JWT auth
    let ws_app = Router::new().route("/", post(handle_simple_rpc));
    let ws_addr = format!("{}:{}", args.host, args.ws_port)
        .parse::<SocketAddr>()
        .expect("Invalid WebSocket address");
    info!("WebSocket RPC listening on http://{}", ws_addr);

    // Simple server for metrics (port 9001)
    let metrics_app = Router::new().route("/", post(handle_simple_rpc));
    let metrics_addr = format!("{}:{}", args.host, args.metrics_port)
        .parse::<SocketAddr>()
        .expect("Invalid metrics address");
    info!("Metrics listening on http://{}", metrics_addr);

    // Bind P2P discovery ports (TCP and UDP) - just to satisfy Kurtosis port checks
    let p2p_tcp_addr = format!("{}:{}", args.host, args.p2p_port)
        .parse::<SocketAddr>()
        .expect("Invalid P2P TCP address");
    let p2p_udp_addr = format!("{}:{}", args.host, args.p2p_port)
        .parse::<SocketAddr>()
        .expect("Invalid P2P UDP address");

    // Spawn P2P TCP listener in a task to keep it alive
    let p2p_tcp_listener = tokio::net::TcpListener::bind(p2p_tcp_addr).await?;
    info!("P2P TCP listening on {}", p2p_tcp_addr);
    let p2p_tcp_task = tokio::spawn(async move {
        loop {
            // Accept connections but do nothing with them
            if let Ok((_socket, _addr)) = p2p_tcp_listener.accept().await {
                // Connection accepted, just drop it
            }
        }
    });

    // Spawn P2P UDP listener in a task to keep it alive
    let p2p_udp_socket = tokio::net::UdpSocket::bind(p2p_udp_addr).await?;
    info!("P2P UDP listening on {}", p2p_udp_addr);
    let p2p_udp_task = tokio::spawn(async move {
        let mut buf = [0u8; 1024];
        loop {
            // Receive packets but do nothing with them
            let _ = p2p_udp_socket.recv(&mut buf).await;
        }
    });

    info!("Ready to accept requests on all ports");

    // Spawn all servers concurrently
    let engine_listener = tokio::net::TcpListener::bind(engine_addr).await?;
    let rpc_listener = tokio::net::TcpListener::bind(rpc_addr).await?;
    let ws_listener = tokio::net::TcpListener::bind(ws_addr).await?;
    let metrics_listener = tokio::net::TcpListener::bind(metrics_addr).await?;

    tokio::select! {
        result = axum::serve(engine_listener, engine_app) => result?,
        result = axum::serve(rpc_listener, rpc_app) => result?,
        result = axum::serve(ws_listener, ws_app) => result?,
        result = axum::serve(metrics_listener, metrics_app) => result?,
        _ = p2p_tcp_task => {},
        _ = p2p_udp_task => {},
    }

    Ok(())
}
