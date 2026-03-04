import gleam/dynamic
import gleam/option.{type Option}

pub type Config {
  Config(
    api_key: String,
    base_url: String,
    stripe_version: String,
    timeout_ms: Int,
  )
}

pub type HttpMethod {
  Get
  Post
  Delete
}

pub type Request {
  Request(
    method: HttpMethod,
    path: String,
    query: List(#(String, String)),
    form: List(#(String, String)),
    headers: List(#(String, String)),
  )
}

pub type Response {
  Response(status: Int, headers: List(#(String, String)), body: String)
}

pub type TransportError {
  ConnectionFailed(String)
  Timeout(String)
  InvalidResponse(String)
}

pub type ApiError {
  ApiError(
    status: Int,
    message: String,
    code: Option(String),
    error_type: Option(String),
    request_id: Option(String),
  )
}

pub type Error {
  Transport(TransportError)
  Api(ApiError)
  Decode(String)
  Validation(String)
  Webhook(String)
}

pub type Transport =
  fn(Config, Request) -> Result(Response, TransportError)

pub type Client {
  Client(config: Config, transport: Transport)
}

pub type StripeList(item) {
  StripeList(has_more: Bool, data: List(item))
}

pub type StripeObject {
  StripeObject(id: String, object: String)
}

pub type Decoded(data) {
  Decoded(raw: dynamic.Dynamic, data: data)
}
