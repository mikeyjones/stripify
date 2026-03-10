import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/result
import stripify/client
import stripify/decoders
import stripify/json
import stripify/types

pub type Customer {
  Customer(
    id: String,
    email: option.Option(String),
    name: option.Option(String),
    metadata: types.Metadata,
    object: String,
  )
}

pub type CreateCustomer {
  CreateCustomer(
    email: option.Option(String),
    name: option.Option(String),
    description: option.Option(String),
    metadata: option.Option(types.Metadata),
  )
}

pub type UpdateCustomer {
  UpdateCustomer(
    email: option.Option(String),
    name: option.Option(String),
    description: option.Option(String),
    metadata: option.Option(types.Metadata),
  )
}

/// Create a Stripe customer.
///
/// Optional fields are only sent when they are `Some`.
pub fn create(
  stripe: types.Client,
  input: CreateCustomer,
) -> Result(Customer, types.Error) {
  client.post(stripe, "/customers", create_form(input))
  |> result.try(fn(body) { json.decode(body, with: customer_decoder()) })
}

/// Retrieve a customer by Stripe customer id (for example `cus_...`).
pub fn retrieve(
  stripe: types.Client,
  customer_id: String,
) -> Result(Customer, types.Error) {
  client.get(stripe, "/customers/" <> customer_id, [])
  |> result.try(fn(body) { json.decode(body, with: customer_decoder()) })
}

/// Update an existing Stripe customer by id.
///
/// Only provided optional fields are sent to Stripe.
pub fn update(
  stripe: types.Client,
  customer_id: String,
  input: UpdateCustomer,
) -> Result(Customer, types.Error) {
  client.post(stripe, "/customers/" <> customer_id, update_form(input))
  |> result.try(fn(body) { json.decode(body, with: customer_decoder()) })
}

/// List customers with an optional page size limit.
pub fn list(
  stripe: types.Client,
  limit: option.Option(Int),
) -> Result(types.StripeList(Customer), types.Error) {
  let query = case limit {
    option.Some(l) -> [#("limit", int.to_string(l))]
    option.None -> []
  }

  client.get(stripe, "/customers", query)
  |> result.try(fn(body) {
    json.decode(body, with: decoders.stripe_list(customer_decoder()))
  })
}

fn customer_decoder() -> decode.Decoder(Customer) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use email <- decode.optional_field(
      "email",
      option.None,
      decode.optional(decode.string),
    )
    use name <- decode.optional_field(
      "name",
      option.None,
      decode.optional(decode.string),
    )
    use metadata <- decoders.optional_metadata()
    decode.success(Customer(
      id: id,
      email: email,
      name: name,
      metadata: metadata,
      object: object,
    ))
  }
}

fn create_form(input: CreateCustomer) -> List(#(String, String)) {
  []
  |> push_optional("email", input.email)
  |> push_optional("name", input.name)
  |> push_optional("description", input.description)
  |> types.push_metadata(input.metadata)
}

fn update_form(input: UpdateCustomer) -> List(#(String, String)) {
  []
  |> push_optional("email", input.email)
  |> push_optional("name", input.name)
  |> push_optional("description", input.description)
  |> types.push_metadata(input.metadata)
}

fn push_optional(
  form: List(#(String, String)),
  key: String,
  value: option.Option(String),
) -> List(#(String, String)) {
  case value {
    option.Some(value) -> [#(key, value), ..form]
    option.None -> form
  }
}
