import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import stripify/http_otp
import stripify/json
import stripify/types

pub const default_base_url = "https://api.stripe.com/v1"

pub const default_stripe_version = "2025-02-24.acacia"

pub const default_timeout_ms = 30_000

/// Build a new low-level Stripe client.
///
/// Domain modules call into this client to perform authenticated requests.
pub fn new(api_key: String) -> types.Client {
  types.Client(
    config: types.Config(
      api_key: api_key,
      base_url: default_base_url,
      stripe_version: default_stripe_version,
      timeout_ms: default_timeout_ms,
    ),
    transport: http_otp.transport(),
  )
}

/// Return a copy of the client with a custom API base URL.
pub fn with_base_url(client: types.Client, base_url: String) -> types.Client {
  let types.Client(config:, transport:) = client
  let next_config = types.Config(..config, base_url: base_url)
  types.Client(config: next_config, transport: transport)
}

/// Return a copy of the client with a custom `Stripe-Version` header value.
pub fn with_stripe_version(
  client: types.Client,
  stripe_version: String,
) -> types.Client {
  let types.Client(config:, transport:) = client
  let next_config = types.Config(..config, stripe_version: stripe_version)
  types.Client(config: next_config, transport: transport)
}

/// Return a copy of the client with a custom request timeout in milliseconds.
pub fn with_timeout_ms(client: types.Client, timeout_ms: Int) -> types.Client {
  let types.Client(config:, transport:) = client
  let next_config = types.Config(..config, timeout_ms: timeout_ms)
  types.Client(config: next_config, transport: transport)
}

/// Return a copy of the client that uses the given transport function.
///
/// Useful for tests, stubs, or alternate HTTP implementations.
pub fn with_transport(
  client: types.Client,
  transport: types.Transport,
) -> types.Client {
  let types.Client(config:, ..) = client
  types.Client(config: config, transport: transport)
}

/// Send a `GET` request and return the raw response body on success.
pub fn get(
  client: types.Client,
  path: String,
  query: List(#(String, String)),
) -> Result(String, types.Error) {
  send(client, types.Get, path, query, [])
}

/// Send a `POST` request with form-encoded data and return the raw response body.
pub fn post(
  client: types.Client,
  path: String,
  form: List(#(String, String)),
) -> Result(String, types.Error) {
  send(client, types.Post, path, [], form)
}

/// Send a `DELETE` request and return the raw response body on success.
pub fn delete(
  client: types.Client,
  path: String,
  query: List(#(String, String)),
) -> Result(String, types.Error) {
  send(client, types.Delete, path, query, [])
}

fn send(
  client: types.Client,
  method: types.HttpMethod,
  path: String,
  query: List(#(String, String)),
  form: List(#(String, String)),
) -> Result(String, types.Error) {
  let types.Client(config:, transport:) = client
  let request =
    types.Request(
      method: method,
      path: path,
      query: query,
      form: form,
      headers: default_headers(config),
    )

  case transport(config, request) {
    Error(error) -> Error(types.Transport(error))
    Ok(response) -> handle_response(response)
  }
}

fn handle_response(response: types.Response) -> Result(String, types.Error) {
  case response.status >= 200 && response.status < 300 {
    True -> Ok(response.body)
    False -> Error(types.Api(parse_api_error(response)))
  }
}

fn parse_api_error(response: types.Response) -> types.ApiError {
  case json.as_dynamic(response.body) {
    Ok(raw) -> {
      let message =
        decode.run(raw, decode.at(["error", "message"], decode.string))
        |> result.unwrap(or: "Stripe API returned an error")

      let code =
        decode.run(
          raw,
          decode.optionally_at(
            ["error", "code"],
            option.None,
            decode.optional(decode.string),
          ),
        )
        |> result.unwrap(or: option.None)

      let error_type =
        decode.run(
          raw,
          decode.optionally_at(
            ["error", "type"],
            option.None,
            decode.optional(decode.string),
          ),
        )
        |> result.unwrap(or: option.None)

      types.ApiError(
        status: response.status,
        message: message,
        code: code,
        error_type: error_type,
        request_id: header(response.headers, "request-id"),
      )
    }
    Error(_) ->
      types.ApiError(
        status: response.status,
        message: "Stripe API returned an error",
        code: option.None,
        error_type: option.None,
        request_id: header(response.headers, "request-id"),
      )
  }
}

fn default_headers(config: types.Config) -> List(#(String, String)) {
  [
    #("Authorization", "Bearer " <> config.api_key),
    #("Stripe-Version", config.stripe_version),
    #("Content-Type", "application/x-www-form-urlencoded"),
  ]
}

fn header(
  headers: List(#(String, String)),
  name: String,
) -> option.Option(String) {
  case
    list.find(headers, fn(pair) {
      string.lowercase(pair.0) == string.lowercase(name)
    })
  {
    Ok(pair) -> option.Some(pair.1)
    Error(_) -> option.None
  }
}
