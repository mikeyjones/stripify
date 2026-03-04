import gleam/uri
import stripify/types

/// Build the default OTP HTTP transport used by the Stripe client.
///
/// Requests are form-encoded and executed via Erlang's `httpc`.
pub fn transport() -> types.Transport {
  fn(config, request) { send(config, request) }
}

fn send(
  config: types.Config,
  request: types.Request,
) -> Result(types.Response, types.TransportError) {
  let types.Request(method:, path:, query:, form:, headers:) = request
  let url = build_url(config.base_url, path, query)
  let body = encode_form(form)
  let method_name = method_to_string(method)

  case otp_request(method_name, url, headers, body, config.timeout_ms) {
    Ok(#(status, response_headers, response_body)) ->
      Ok(types.Response(status:, headers: response_headers, body: response_body))
    Error("timeout") -> Error(types.Timeout("Request timed out"))
    Error(reason) -> Error(types.ConnectionFailed(reason))
  }
}

fn build_url(
  base: String,
  path: String,
  query: List(#(String, String)),
) -> String {
  let query_string = uri.query_to_string(query)
  case query_string {
    "" -> base <> path
    _ -> base <> path <> "?" <> query_string
  }
}

fn encode_form(form: List(#(String, String))) -> String {
  uri.query_to_string(form)
}

fn method_to_string(method: types.HttpMethod) -> String {
  case method {
    types.Get -> "GET"
    types.Post -> "POST"
    types.Delete -> "DELETE"
  }
}

@external(erlang, "stripify_http_otp_ffi", "request")
fn otp_request(
  method: String,
  url: String,
  headers: List(#(String, String)),
  body: String,
  timeout_ms: Int,
) -> Result(#(Int, List(#(String, String)), String), String)
