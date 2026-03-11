import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import stripify/client
import stripify/decoders
import stripify/json
import stripify/types

pub type Subscription {
  Subscription(
    id: String,
    status: String,
    customer: String,
    items: List(SubscriptionItem),
    metadata: types.Metadata,
    object: String,
  )
}

pub type SubscriptionItem {
  SubscriptionItem(
    id: String,
    price_id: option.Option(String),
    quantity: option.Option(Int),
    currency: option.Option(String),
    object: String,
  )
}

pub type Product {
  Product(
    id: String,
    name: String,
    active: Bool,
    metadata: types.Metadata,
    object: String,
  )
}

pub type Price {
  Price(
    id: String,
    currency: String,
    unit_amount: option.Option(Int),
    recurring_interval: option.Option(String),
    product: option.Option(String),
    metadata: types.Metadata,
    object: String,
  )
}

pub type CreateSubscription {
  CreateSubscription(
    customer: String,
    price_id: String,
    quantity: Int,
    metadata: option.Option(types.Metadata),
  )
}

/// Create a subscription for a customer and price.
pub fn create_subscription(
  stripe: types.Client,
  input: CreateSubscription,
) -> Result(Subscription, types.Error) {
  let form = [
    #("customer", input.customer),
    #("items[0][price]", input.price_id),
    #("items[0][quantity]", int.to_string(input.quantity)),
  ]
  let form = types.push_metadata(form, input.metadata)
  client.post(stripe, "/subscriptions", form)
  |> result.try(fn(body) { json.decode(body, with: subscription_decoder()) })
}

/// Update the quantity for a specific subscription item.
pub fn update_quantity(
  stripe: types.Client,
  subscription_id: String,
  item_id: String,
  quantity: Int,
) -> Result(Subscription, types.Error) {
  let form = [
    #("items[0][id]", item_id),
    #("items[0][quantity]", int.to_string(quantity)),
  ]
  client.post(stripe, "/subscriptions/" <> subscription_id, form)
  |> result.try(fn(body) { json.decode(body, with: subscription_decoder()) })
}

/// Retrieve a subscription by id (for example `sub_...`).
pub fn retrieve_subscription(
  stripe: types.Client,
  subscription_id: String,
) -> Result(Subscription, types.Error) {
  client.get(stripe, "/subscriptions/" <> subscription_id, [])
  |> result.try(fn(body) { json.decode(body, with: subscription_decoder()) })
}

/// Cancel a subscription immediately.
pub fn cancel_subscription(
  stripe: types.Client,
  subscription_id: String,
) -> Result(Subscription, types.Error) {
  client.delete(stripe, "/subscriptions/" <> subscription_id, [])
  |> result.try(fn(body) { json.decode(body, with: subscription_decoder()) })
}

/// List subscriptions with optional customer and limit filters.
pub fn list_subscriptions(
  stripe: types.Client,
  customer: option.Option(String),
  limit: option.Option(Int),
) -> Result(types.StripeList(Subscription), types.Error) {
  let query = []
  let query = case customer {
    option.Some(value) -> [#("customer", value), ..query]
    option.None -> query
  }
  let query = case limit {
    option.Some(value) -> [#("limit", int.to_string(value)), ..query]
    option.None -> query
  }
  client.get(stripe, "/subscriptions", query)
  |> result.try(fn(body) {
    json.decode(body, with: decoders.stripe_list(subscription_decoder()))
  })
}

/// Retrieve a product by id (for example `prod_...`).
pub fn retrieve_product(
  stripe: types.Client,
  product_id: String,
) -> Result(Product, types.Error) {
  client.get(stripe, "/products/" <> product_id, [])
  |> result.try(fn(body) { json.decode(body, with: product_decoder()) })
}

/// List products with optional active and limit filters.
pub fn list_products(
  stripe: types.Client,
  active: option.Option(Bool),
  limit: option.Option(Int),
) -> Result(types.StripeList(Product), types.Error) {
  let query = []
  let query = case active {
    option.Some(True) -> [#("active", "true"), ..query]
    option.Some(False) -> [#("active", "false"), ..query]
    option.None -> query
  }
  let query = case limit {
    option.Some(value) -> [#("limit", int.to_string(value)), ..query]
    option.None -> query
  }
  client.get(stripe, "/products", query)
  |> result.try(fn(body) {
    json.decode(body, with: decoders.stripe_list(product_decoder()))
  })
}

/// Retrieve a price by id (for example `price_...`).
pub fn retrieve_price(
  stripe: types.Client,
  price_id: String,
) -> Result(Price, types.Error) {
  client.get(stripe, "/prices/" <> price_id, [])
  |> result.try(fn(body) { json.decode(body, with: price_decoder()) })
}

/// List prices with optional product, lookup keys, and limit filters.
pub fn list_prices(
  stripe: types.Client,
  product: option.Option(String),
  lookup_keys: option.Option(List(String)),
  limit: option.Option(Int),
) -> Result(types.StripeList(Price), types.Error) {
  let query = []
  let query = case product {
    option.Some(value) -> [#("product", value), ..query]
    option.None -> query
  }
  let query = case lookup_keys {
    option.Some(values) ->
      list.fold(over: values, from: query, with: fn(query, value) {
        [#("lookup_keys[]", value), ..query]
      })
    option.None -> query
  }
  let query = case limit {
    option.Some(value) -> [#("limit", int.to_string(value)), ..query]
    option.None -> query
  }
  client.get(stripe, "/prices", query)
  |> result.try(fn(body) {
    json.decode(body, with: decoders.stripe_list(price_decoder()))
  })
}

fn subscription_decoder() -> decode.Decoder(Subscription) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use status <- decode.field("status", decode.string)
    use customer <- decode.field("customer", decode.string)
    use items <- decode.optional_field("items", [], subscription_items_decoder())
    use metadata <- decoders.optional_metadata()
    decode.success(Subscription(
      id: id,
      status: status,
      customer: customer,
      items: items,
      metadata: metadata,
      object: object,
    ))
  }
}

fn subscription_items_decoder() -> decode.Decoder(List(SubscriptionItem)) {
  {
    use data <- decode.field("data", decode.list(subscription_item_decoder()))
    decode.success(data)
  }
}

fn subscription_item_decoder() -> decode.Decoder(SubscriptionItem) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use quantity <- decode.optional_field(
      "quantity",
      option.None,
      decode.optional(decode.int),
    )
    use price <- decode.optional_field(
      "price",
      option.None,
      decode.optional(subscription_item_price_decoder()),
    )
    let price_id = option.map(price, fn(value) { value.0 })
    let currency = option.map(price, fn(value) { value.1 })
    decode.success(SubscriptionItem(
      id: id,
      price_id: price_id,
      quantity: quantity,
      currency: currency,
      object: object,
    ))
  }
}

fn subscription_item_price_decoder() -> decode.Decoder(#(String, String)) {
  {
    use id <- decode.field("id", decode.string)
    use currency <- decode.field("currency", decode.string)
    decode.success(#(id, currency))
  }
}

fn product_decoder() -> decode.Decoder(Product) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use name <- decode.field("name", decode.string)
    use active <- decode.field("active", decode.bool)
    use metadata <- decoders.optional_metadata()
    decode.success(Product(
      id: id,
      name: name,
      active: active,
      metadata: metadata,
      object: object,
    ))
  }
}

fn price_decoder() -> decode.Decoder(Price) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    use currency <- decode.field("currency", decode.string)
    use unit_amount <- decode.optional_field(
      "unit_amount",
      option.None,
      decode.optional(decode.int),
    )
    use recurring_interval <- decode.optional_field(
      "recurring",
      option.None,
      recurring_interval_decoder(),
    )
    use product <- decode.optional_field(
      "product",
      option.None,
      decode.optional(decode.string),
    )
    use metadata <- decoders.optional_metadata()
    decode.success(Price(
      id: id,
      currency: currency,
      unit_amount: unit_amount,
      recurring_interval: recurring_interval,
      product: product,
      metadata: metadata,
      object: object,
    ))
  }
}

fn recurring_interval_decoder() -> decode.Decoder(option.Option(String)) {
  {
    use interval <- decode.optional_field(
      "interval",
      option.None,
      decode.optional(decode.string),
    )
    decode.success(interval)
  }
}
