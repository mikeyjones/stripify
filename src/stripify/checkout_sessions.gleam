import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/result
import stripify/client
import stripify/decoders
import stripify/json
import stripify/types

pub type CheckoutSession {
  CheckoutSession(
    id: String,
    mode: String,
    status: String,
    customer: option.Option(String),
    subscription: option.Option(String),
    url: option.Option(String),
    payment_intent: option.Option(String),
    metadata: types.Metadata,
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
    metadata: option.Option(types.Metadata),
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
    use status <- decode.field("status", decode.string)
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
    use metadata <- decoders.optional_metadata()
    decode.success(CheckoutSession(
      id: id,
      mode: mode,
      status: status,
      customer: customer,
      subscription: subscription,
      url: url,
      payment_intent: payment_intent,
      metadata: metadata,
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
  let base = case input.customer {
    option.Some(customer) -> [#("customer", customer), ..base]
    option.None -> base
  }
  types.push_metadata(base, input.metadata)
}
