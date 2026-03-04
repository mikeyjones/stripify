import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/result
import stripify/client
import stripify/json
import stripify/types

pub type PaymentIntent {
  PaymentIntent(
    id: String,
    amount: Int,
    currency: String,
    status: String,
    customer: option.Option(String),
    object: String,
  )
}

pub type CreatePaymentIntent {
  CreatePaymentIntent(
    amount: Int,
    currency: String,
    customer: option.Option(String),
    confirm_now: Bool,
    payment_method: option.Option(String),
  )
}

/// Create a Stripe payment intent.
///
/// Amount is in the currency's minor unit (for example cents for USD).
pub fn create(
  stripe: types.Client,
  input: CreatePaymentIntent,
) -> Result(PaymentIntent, types.Error) {
  client.post(stripe, "/payment_intents", create_form(input))
  |> result.try(fn(body) { json.decode(body, with: payment_intent_decoder()) })
}

/// Retrieve a payment intent by id (for example `pi_...`).
pub fn retrieve(
  stripe: types.Client,
  payment_intent_id: String,
) -> Result(PaymentIntent, types.Error) {
  client.get(stripe, "/payment_intents/" <> payment_intent_id, [])
  |> result.try(fn(body) { json.decode(body, with: payment_intent_decoder()) })
}

/// Confirm a payment intent, optionally attaching a payment method id.
pub fn confirm(
  stripe: types.Client,
  payment_intent_id: String,
  payment_method: option.Option(String),
) -> Result(PaymentIntent, types.Error) {
  let form = case payment_method {
    option.Some(method) -> [#("payment_method", method)]
    option.None -> []
  }
  client.post(
    stripe,
    "/payment_intents/" <> payment_intent_id <> "/confirm",
    form,
  )
  |> result.try(fn(body) { json.decode(body, with: payment_intent_decoder()) })
}

/// Cancel a payment intent by id.
pub fn cancel(
  stripe: types.Client,
  payment_intent_id: String,
) -> Result(PaymentIntent, types.Error) {
  client.post(stripe, "/payment_intents/" <> payment_intent_id <> "/cancel", [])
  |> result.try(fn(body) { json.decode(body, with: payment_intent_decoder()) })
}

fn payment_intent_decoder() -> decode.Decoder(PaymentIntent) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use amount <- decode.field("amount", decode.int)
    use currency <- decode.field("currency", decode.string)
    use status <- decode.field("status", decode.string)
    use customer <- decode.optional_field(
      "customer",
      option.None,
      decode.optional(decode.string),
    )
    decode.success(PaymentIntent(
      id: id,
      amount: amount,
      currency: currency,
      status: status,
      customer: customer,
      object: object,
    ))
  }
}

fn create_form(input: CreatePaymentIntent) -> List(#(String, String)) {
  let base = [
    #("amount", int.to_string(input.amount)),
    #("currency", input.currency),
  ]
  let base = case input.confirm_now {
    True -> [#("confirm", "true"), ..base]
    False -> base
  }
  let base = case input.customer {
    option.Some(customer) -> [#("customer", customer), ..base]
    option.None -> base
  }
  case input.payment_method {
    option.Some(method) -> [#("payment_method", method), ..base]
    option.None -> base
  }
}
