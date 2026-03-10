import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/result
import stripify/client
import stripify/decoders
import stripify/json
import stripify/types

pub type Refund {
  Refund(
    id: String,
    amount: Int,
    currency: String,
    status: option.Option(String),
    payment_intent: option.Option(String),
    metadata: types.Metadata,
    object: String,
  )
}

pub type CreateRefund {
  CreateRefund(
    payment_intent: String,
    amount: option.Option(Int),
    reason: option.Option(String),
    metadata: option.Option(types.Metadata),
  )
}

/// Create a refund for a payment intent.
///
/// If `amount` is `None`, Stripe will refund the full remaining amount.
pub fn create(
  stripe: types.Client,
  input: CreateRefund,
) -> Result(Refund, types.Error) {
  client.post(stripe, "/refunds", create_form(input))
  |> result.try(fn(body) { json.decode(body, with: refund_decoder()) })
}

/// Retrieve a refund by id (for example `re_...`).
pub fn retrieve(
  stripe: types.Client,
  refund_id: String,
) -> Result(Refund, types.Error) {
  client.get(stripe, "/refunds/" <> refund_id, [])
  |> result.try(fn(body) { json.decode(body, with: refund_decoder()) })
}

/// List refunds filtered by optional payment intent and/or limit.
pub fn list(
  stripe: types.Client,
  payment_intent: option.Option(String),
  limit: option.Option(Int),
) -> Result(types.StripeList(Refund), types.Error) {
  let query = []
  let query = case payment_intent {
    option.Some(value) -> [#("payment_intent", value), ..query]
    option.None -> query
  }
  let query = case limit {
    option.Some(value) -> [#("limit", int.to_string(value)), ..query]
    option.None -> query
  }
  client.get(stripe, "/refunds", query)
  |> result.try(fn(body) {
    json.decode(body, with: decoders.stripe_list(refund_decoder()))
  })
}

fn refund_decoder() -> decode.Decoder(Refund) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use amount <- decode.field("amount", decode.int)
    use currency <- decode.field("currency", decode.string)
    use status <- decode.optional_field(
      "status",
      option.None,
      decode.optional(decode.string),
    )
    use payment_intent <- decode.optional_field(
      "payment_intent",
      option.None,
      decode.optional(decode.string),
    )
    use metadata <- decoders.optional_metadata()
    decode.success(Refund(
      id: id,
      amount: amount,
      currency: currency,
      status: status,
      payment_intent: payment_intent,
      metadata: metadata,
      object: object,
    ))
  }
}

fn create_form(input: CreateRefund) -> List(#(String, String)) {
  let form = [#("payment_intent", input.payment_intent)]
  let form = case input.amount {
    option.Some(value) -> [#("amount", int.to_string(value)), ..form]
    option.None -> form
  }
  let form = case input.reason {
    option.Some(value) -> [#("reason", value), ..form]
    option.None -> form
  }
  types.push_metadata(form, input.metadata)
}
