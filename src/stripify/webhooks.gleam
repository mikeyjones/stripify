import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string
import stripify/json
import stripify/types

pub type Event {
  Event(id: String, event_type: String, object: String)
}

/// Verify Stripe's `Stripe-Signature` header for a webhook payload.
///
/// Returns `Ok(Nil)` only when the HMAC signature matches and the timestamp is
/// within `tolerance_seconds` of `now_unix_seconds`.
pub fn verify_signature(
  payload: String,
  stripe_signature_header: String,
  endpoint_secret: String,
  now_unix_seconds: Int,
  tolerance_seconds: Int,
) -> Result(Nil, types.Error) {
  case parse_signature_header(stripe_signature_header) {
    Error(message) -> Error(types.Webhook(message))
    Ok(#(timestamp, signatures)) -> {
      let signed_payload = int.to_string(timestamp) <> "." <> payload
      let expected = sign_hex(endpoint_secret, signed_payload)
      let valid =
        list.any(signatures, fn(signature) {
          secure_equals(signature, expected)
        })

      case valid {
        False -> Error(types.Webhook("Invalid webhook signature"))
        True -> {
          case
            int.absolute_value(now_unix_seconds - timestamp)
            <= tolerance_seconds
          {
            True -> Ok(Nil)
            False ->
              Error(types.Webhook("Webhook timestamp outside tolerance window"))
          }
        }
      }
    }
  }
}

/// Decode a webhook event payload into a compact typed event.
///
/// This extracts the top-level event id/type and the nested data object kind.
pub fn decode_event(payload: String) -> Result(Event, types.Error) {
  let decoder = {
    use id <- decode.field("id", decode.string)
    use event_type <- decode.field("type", decode.string)
    use object <- decode.subfield(["data", "object", "object"], decode.string)
    decode.success(Event(id: id, event_type: event_type, object: object))
  }
  json.decode(payload, with: decoder)
}

fn parse_signature_header(
  signature_header: String,
) -> Result(#(Int, List(String)), String) {
  let parts = string.split(signature_header, ",")
  let timestamp_result =
    parts
    |> list.filter_map(parse_signature_pair)
    |> list.find(fn(part) { part.0 == "t" })

  let signatures =
    parts
    |> list.filter_map(parse_signature_pair)
    |> list.filter_map(fn(part) {
      case part.0 == "v1" {
        True -> Ok(part.1)
        False -> Error(Nil)
      }
    })

  case timestamp_result {
    Error(_) -> Error("Missing webhook timestamp in signature header")
    Ok(#(_, raw_timestamp)) -> {
      case int.parse(raw_timestamp) {
        Error(_) -> Error("Invalid webhook timestamp")
        Ok(timestamp) ->
          case signatures {
            [] -> Error("Missing v1 signatures in signature header")
            _ -> Ok(#(timestamp, signatures))
          }
      }
    }
  }
}

fn parse_signature_pair(segment: String) -> Result(#(String, String), Nil) {
  case string.split(segment |> string.trim, "=") {
    [key, value] if key != "" && value != "" -> Ok(#(key, value))
    _ -> Error(Nil)
  }
}

@external(erlang, "stripify_webhooks_ffi", "sign_hex")
fn sign_hex(secret: String, payload: String) -> String

@external(erlang, "stripify_webhooks_ffi", "secure_equals")
fn secure_equals(left: String, right: String) -> Bool
