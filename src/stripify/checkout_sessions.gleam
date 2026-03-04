import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/result
import stripify/client
import stripify/json
import stripify/types

pub type CheckoutSession {
  CheckoutSession(
    id: String,
    mode: String,
    status: option.Option(String),
    url: option.Option(String),
    payment_intent: option.Option(String),
    object: String,
  )
}

pub type CreateCheckoutSession {
  CreateCheckoutSession(
    mode: String,
    success_url: String,
    cancel_url: String,
    customer: option.Option(String),
    price_id: String,
    quantity: Int,
  )
}

/// Create a Checkout Session for hosted Stripe Checkout.
///
/// This helper currently sends one line item (`line_items[0]`).
pub fn create(
  stripe: types.Client,
  input: CreateCheckoutSession,
) -> Result(CheckoutSession, types.Error) {
  client.post(stripe, "/checkout/sessions", create_form(input))
  |> result.try(fn(body) { json.decode(body, with: session_decoder()) })
}

/// Retrieve a Checkout Session by id (for example `cs_...`).
pub fn retrieve(
  stripe: types.Client,
  checkout_session_id: String,
) -> Result(CheckoutSession, types.Error) {
  client.get(stripe, "/checkout/sessions/" <> checkout_session_id, [])
  |> result.try(fn(body) { json.decode(body, with: session_decoder()) })
}

/// Expire an open Checkout Session so it can no longer be used.
pub fn expire(
  stripe: types.Client,
  checkout_session_id: String,
) -> Result(CheckoutSession, types.Error) {
  client.post(
    stripe,
    "/checkout/sessions/" <> checkout_session_id <> "/expire",
    [],
  )
  |> result.try(fn(body) { json.decode(body, with: session_decoder()) })
}

fn session_decoder() -> decode.Decoder(CheckoutSession) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use mode <- decode.field("mode", decode.string)
    use status <- decode.optional_field(
      "status",
      option.None,
      decode.optional(decode.string),
    )
    use url <- decode.optional_field(
      "url",
      option.None,
      decode.optional(decode.string),
    )
    use payment_intent <- decode.optional_field(
      "payment_intent",
      option.None,
      decode.optional(decode.string),
    )
    decode.success(CheckoutSession(
      id: id,
      mode: mode,
      status: status,
      url: url,
      payment_intent: payment_intent,
      object: object,
    ))
  }
}

fn create_form(input: CreateCheckoutSession) -> List(#(String, String)) {
  let base = [
    #("mode", input.mode),
    #("success_url", input.success_url),
    #("cancel_url", input.cancel_url),
    #("line_items[0][price]", input.price_id),
    #("line_items[0][quantity]", int.to_string(input.quantity)),
  ]
  case input.customer {
    option.Some(customer) -> [#("customer", customer), ..base]
    option.None -> base
  }
}
