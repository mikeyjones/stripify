import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import stripify/decoders
import stripify/json
import stripify/types

pub type Event {
  CheckoutSessionCompleted(
    id: String,
    checkout_session: CheckoutSessionEvent,
  )
  CustomerSubscriptionCreated(
    id: String,
    subscription: SubscriptionEvent,
  )
  CustomerSubscriptionUpdated(
    id: String,
    subscription: SubscriptionEvent,
  )
  CustomerSubscriptionDeleted(
    id: String,
    subscription: SubscriptionEvent,
  )
  Unknown(
    id: String,
    event_type: String,
    object: String,
    metadata: types.Metadata,
  )
}

pub type CheckoutSessionEvent {
  CheckoutSessionEvent(
    id: String,
    customer: option.Option(String),
    subscription: option.Option(String),
    metadata: types.Metadata,
    object: String,
  )
}

pub type SubscriptionEvent {
  SubscriptionEvent(
    id: String,
    status: String,
    customer: String,
    metadata: types.Metadata,
    object: String,
  )
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
    decode.success(#(id, event_type))
  }
  case json.as_dynamic(payload) {
    Error(error) -> Error(error)
    Ok(raw) -> {
      case decode.run(raw, decoder) {
        Error(_) -> Error(types.Decode("JSON shape did not match expected type"))
        Ok(#(id, event_type)) ->
          case event_type {
            "checkout.session.completed" ->
              case decode.run(raw, decode.at(["data", "object"], checkout_session_event_decoder())) {
                Error(_) ->
                  Error(types.Decode("JSON shape did not match expected type"))
                Ok(checkout_session) ->
                  Ok(CheckoutSessionCompleted(id: id, checkout_session: checkout_session))
              }
            "customer.subscription.created" ->
              case decode.run(raw, decode.at(["data", "object"], subscription_event_decoder())) {
                Error(_) ->
                  Error(types.Decode("JSON shape did not match expected type"))
                Ok(subscription) ->
                  Ok(CustomerSubscriptionCreated(id: id, subscription: subscription))
              }
            "customer.subscription.updated" ->
              case decode.run(raw, decode.at(["data", "object"], subscription_event_decoder())) {
                Error(_) ->
                  Error(types.Decode("JSON shape did not match expected type"))
                Ok(subscription) ->
                  Ok(CustomerSubscriptionUpdated(id: id, subscription: subscription))
              }
            "customer.subscription.deleted" ->
              case decode.run(raw, decode.at(["data", "object"], subscription_event_decoder())) {
                Error(_) ->
                  Error(types.Decode("JSON shape did not match expected type"))
                Ok(subscription) ->
                  Ok(CustomerSubscriptionDeleted(id: id, subscription: subscription))
              }
            _ ->
              case decode.run(raw, unknown_event_data_decoder()) {
                Error(_) ->
                  Error(types.Decode("JSON shape did not match expected type"))
                Ok(#(object, metadata)) ->
                  Ok(Unknown(
                    id: id,
                    event_type: event_type,
                    object: object,
                    metadata: metadata,
                  ))
              }
          }
      }
    }
  }
}

fn checkout_session_event_decoder() -> decode.Decoder(CheckoutSessionEvent) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use customer <- decode.optional_field(
      "customer",
      option.None,
      decode.optional(decode.string),
    )
    use subscription <- decode.optional_field(
      "subscription",
      option.None,
      decode.optional(decode.string),
    )
    use metadata <- decoders.optional_metadata()
    decode.success(CheckoutSessionEvent(
      id: id,
      customer: customer,
      subscription: subscription,
      metadata: metadata,
      object: object,
    ))
  }
}

fn subscription_event_decoder() -> decode.Decoder(SubscriptionEvent) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use status <- decode.field("status", decode.string)
    use customer <- decode.field("customer", decode.string)
    use metadata <- decoders.optional_metadata()
    decode.success(SubscriptionEvent(
      id: id,
      status: status,
      customer: customer,
      metadata: metadata,
      object: object,
    ))
  }
}

fn unknown_event_data_decoder() -> decode.Decoder(#(String, types.Metadata)) {
  decode.at(["data", "object"], unknown_object_decoder())
}

fn unknown_object_decoder() -> decode.Decoder(#(String, types.Metadata)) {
  {
    use object <- decode.field("object", decode.string)
    use metadata <- decoders.optional_metadata()
    decode.success(#(object, metadata))
  }
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
