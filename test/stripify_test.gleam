import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleeunit
import stripify
import stripify/checkout_sessions
import stripify/client
import stripify/customers
import stripify/payment_intents
import stripify/refunds
import stripify/subscriptions
import stripify/types
import stripify/webhooks

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn client_maps_api_errors_test() {
  let body =
    "{\"error\":{\"message\":\"Card declined\",\"code\":\"card_declined\",\"type\":\"card_error\"}}"
  let stripe_client = fake_client(status: 402, body: body)
  let result = client.get(stripe_client, "/payment_intents/pi_123", [])

  case result {
    Error(types.Api(error)) -> {
      assert error.status == 402
      assert error.message == "Card declined"
    }
    _ -> panic
  }
}

pub fn customers_decode_test() {
  let body =
    "{\"id\":\"cus_123\",\"object\":\"customer\",\"email\":\"jane@example.com\",\"name\":\"Jane\",\"metadata\":{\"plan\":\"gold\"}}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    customers.CreateCustomer(
      email: option.Some("jane@example.com"),
      name: option.Some("Jane"),
      description: option.None,
      metadata: option.None,
    )

  let assert Ok(customer) = customers.create(stripe, input)
  assert customer.id == "cus_123"
  assert customer.email == option.Some("jane@example.com")
  assert customer.metadata == dict.from_list([#("plan", "gold")])
}

pub fn payment_intents_decode_test() {
  let body =
    "{\"id\":\"pi_123\",\"object\":\"payment_intent\",\"amount\":1999,\"currency\":\"usd\",\"status\":\"requires_payment_method\",\"customer\":\"cus_123\",\"metadata\":{\"order_id\":\"ord_123\"}}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    payment_intents.CreatePaymentIntent(
      amount: 1999,
      currency: "usd",
      customer: option.Some("cus_123"),
      confirm_now: False,
      payment_method: option.None,
      metadata: option.None,
    )

  let assert Ok(intent) = payment_intents.create(stripe, input)
  assert intent.amount == 1999
  assert intent.customer == option.Some("cus_123")
  assert intent.metadata == dict.from_list([#("order_id", "ord_123")])
}

pub fn checkout_sessions_decode_test() {
  let body =
    "{\"id\":\"cs_123\",\"object\":\"checkout.session\",\"mode\":\"payment\",\"status\":\"open\",\"customer\":\"cus_123\",\"subscription\":\"sub_123\",\"url\":\"https://checkout.stripe.com/c/session\",\"payment_intent\":\"pi_123\",\"metadata\":{\"cart_id\":\"cart_123\"}}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    checkout_sessions.CreateCheckoutSession(
      mode: "payment",
      success_url: "https://example.com/success",
      cancel_url: "https://example.com/cancel",
      customer: option.None,
      price_id: "price_123",
      quantity: 1,
      metadata: option.None,
    )

  let assert Ok(session) = checkout_sessions.create(stripe, input)
  assert session.mode == "payment"
  assert session.status == "open"
  assert session.customer == option.Some("cus_123")
  assert session.subscription == option.Some("sub_123")
  assert session.payment_intent == option.Some("pi_123")
  assert session.metadata == dict.from_list([#("cart_id", "cart_123")])
}

pub fn refunds_list_decode_test() {
  let body =
    "{\"object\":\"list\",\"has_more\":false,\"data\":[{\"id\":\"re_123\",\"object\":\"refund\",\"amount\":100,\"currency\":\"usd\",\"status\":\"succeeded\",\"payment_intent\":\"pi_123\",\"metadata\":{\"refund_reason\":\"requested_by_customer\"}}]}"
  let stripe = fake_client(status: 200, body: body)

  let assert Ok(refund_list) =
    refunds.list(stripe, option.None, option.Some(10))
  assert refund_list.has_more == False
  assert list.length(refund_list.data) == 1
  let assert [refund] = refund_list.data
  assert refund.metadata
    == dict.from_list([#("refund_reason", "requested_by_customer")])
}

pub fn subscriptions_decode_test() {
  let body =
    "{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"active\",\"customer\":\"cus_123\",\"items\":{\"object\":\"list\",\"data\":[{\"id\":\"si_123\",\"object\":\"subscription_item\",\"quantity\":3,\"price\":{\"id\":\"price_123\",\"currency\":\"usd\"}}]},\"metadata\":{\"plan\":\"pro\"}}"
  let stripe = fake_client(status: 200, body: body)
  let assert Ok(subscription) =
    subscriptions.retrieve_subscription(stripe, "sub_123")
  assert subscription.customer == "cus_123"
  assert list.length(subscription.items) == 1
  let assert [item] = subscription.items
  assert item.id == "si_123"
  assert item.price_id == option.Some("price_123")
  assert item.quantity == option.Some(3)
  assert item.currency == option.Some("usd")
  assert subscription.metadata == dict.from_list([#("plan", "pro")])
}

pub fn products_decode_test() {
  let body =
    "{\"id\":\"prod_123\",\"object\":\"product\",\"name\":\"Pro plan\",\"active\":true,\"metadata\":{\"category\":\"saas\"}}"
  let stripe = fake_client(status: 200, body: body)
  let assert Ok(product) = subscriptions.retrieve_product(stripe, "prod_123")
  assert product.name == "Pro plan"
  assert product.metadata == dict.from_list([#("category", "saas")])
}

pub fn prices_decode_test() {
  let body =
    "{\"id\":\"price_123\",\"object\":\"price\",\"currency\":\"usd\",\"unit_amount\":500,\"recurring\":{\"interval\":\"month\"},\"product\":\"prod_123\",\"metadata\":{\"tier\":\"starter\"}}"
  let stripe = fake_client(status: 200, body: body)
  let assert Ok(price) = subscriptions.retrieve_price(stripe, "price_123")
  assert price.unit_amount == option.Some(500)
  assert price.recurring_interval == option.Some("month")
  assert price.metadata == dict.from_list([#("tier", "starter")])
}

pub fn prices_list_with_lookup_keys_request_test() {
  let stripe =
    request_asserting_client(
      body: "{\"object\":\"list\",\"has_more\":false,\"data\":[]}",
      assert_request: fn(request) {
        let types.Request(path:, query:, ..) = request
        assert path == "/prices"
        assert_query_contains(query, #("product", "prod_123"))
        assert_query_contains(query, #("lookup_keys[]", "starter_monthly"))
        assert_query_contains(query, #("lookup_keys[]", "starter_yearly"))
        assert_query_contains(query, #("limit", "2"))
      },
    )

  let assert Ok(_) =
    subscriptions.list_prices(
      stripe,
      option.Some("prod_123"),
      option.Some(["starter_monthly", "starter_yearly"]),
      option.Some(2),
    )
}

pub fn webhooks_verify_signature_test() {
  let payload =
    "{\"id\":\"evt_123\",\"type\":\"checkout.session.completed\",\"data\":{\"object\":{\"id\":\"cs_123\",\"object\":\"checkout.session\",\"customer\":\"cus_123\",\"subscription\":\"sub_123\",\"metadata\":{\"cart_id\":\"cart_123\"}}}}"
  let timestamp = 1_700_000_000
  let secret = "whsec_test"
  let signature = sign_hex(secret, int.to_string(timestamp) <> "." <> payload)
  let header = "t=" <> int.to_string(timestamp) <> ",v1=" <> signature

  let assert Ok(_) =
    webhooks.verify_signature(payload, header, secret, timestamp + 5, 300)

  let assert Ok(event) = webhooks.decode_event(payload)
  case event {
    webhooks.CheckoutSessionCompleted(id:, checkout_session:) -> {
      assert id == "evt_123"
      let webhooks.CheckoutSessionEvent(
        id: checkout_session_id,
        customer: customer,
        subscription: subscription,
        metadata: metadata,
        ..,
      ) = checkout_session
      assert checkout_session_id == "cs_123"
      assert customer == option.Some("cus_123")
      assert subscription == option.Some("sub_123")
      assert metadata == dict.from_list([#("cart_id", "cart_123")])
    }
    _ -> panic
  }
}

pub fn webhooks_reject_bad_signature_test() {
  let payload =
    "{\"id\":\"evt_123\",\"type\":\"charge.refunded\",\"data\":{\"object\":{\"object\":\"charge\"}}}"
  let header = "t=1700000000,v1=not-a-real-signature"

  let result =
    webhooks.verify_signature(payload, header, "whsec_test", 1_700_000_010, 300)

  case result {
    Error(types.Webhook(_)) -> Nil
    _ -> panic
  }
}

pub fn webhooks_subscription_created_decode_test() {
  let payload =
    "{\"id\":\"evt_124\",\"type\":\"customer.subscription.created\",\"data\":{\"object\":{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"active\",\"customer\":\"cus_123\",\"metadata\":{\"plan\":\"pro\"}}}}"
  let assert Ok(event) = webhooks.decode_event(payload)
  case event {
    webhooks.CustomerSubscriptionCreated(id:, subscription:) -> {
      assert id == "evt_124"
      let webhooks.SubscriptionEvent(
        id: subscription_id,
        status: status,
        customer: customer,
        metadata: metadata,
        ..,
      ) = subscription
      assert subscription_id == "sub_123"
      assert status == "active"
      assert customer == "cus_123"
      assert metadata == dict.from_list([#("plan", "pro")])
    }
    _ -> panic
  }
}

pub fn webhooks_subscription_updated_decode_test() {
  let payload =
    "{\"id\":\"evt_125\",\"type\":\"customer.subscription.updated\",\"data\":{\"object\":{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"past_due\",\"customer\":\"cus_123\",\"metadata\":{\"plan\":\"pro\"}}}}"
  let assert Ok(event) = webhooks.decode_event(payload)
  case event {
    webhooks.CustomerSubscriptionUpdated(id:, subscription:) -> {
      assert id == "evt_125"
      let webhooks.SubscriptionEvent(status: status, ..) = subscription
      assert status == "past_due"
    }
    _ -> panic
  }
}

pub fn webhooks_subscription_deleted_decode_test() {
  let payload =
    "{\"id\":\"evt_126\",\"type\":\"customer.subscription.deleted\",\"data\":{\"object\":{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"canceled\",\"customer\":\"cus_123\",\"metadata\":{\"plan\":\"pro\"}}}}"
  let assert Ok(event) = webhooks.decode_event(payload)
  case event {
    webhooks.CustomerSubscriptionDeleted(id:, subscription:) -> {
      assert id == "evt_126"
      let webhooks.SubscriptionEvent(status: status, ..) = subscription
      assert status == "canceled"
    }
    _ -> panic
  }
}

pub fn optional_live_customers_smoke_test() {
  let key = getenv("STRIPE_TEST_API_KEY")
  case key == "" {
    True -> Nil
    False -> {
      let stripe = stripify.new(key)
      let result = customers.list(stripe, option.Some(1))
      case result {
        Ok(_) -> Nil
        Error(_) -> panic
      }
    }
  }
}

pub fn customers_metadata_request_test() {
  let metadata = dict.from_list([#("crm_id", "crm_123")])
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"cus_123\",\"object\":\"customer\",\"email\":\"jane@example.com\",\"name\":\"Jane\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata[crm_id]", "crm_123"))
      },
    )
  let input =
    customers.CreateCustomer(
      email: option.Some("jane@example.com"),
      name: option.Some("Jane"),
      description: option.None,
      metadata: option.Some(metadata),
    )
  let assert Ok(_) = customers.create(stripe, input)
}

pub fn customers_clear_metadata_request_test() {
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"cus_123\",\"object\":\"customer\",\"email\":\"jane@example.com\",\"name\":\"Jane\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata", ""))
      },
    )
  let input =
    customers.UpdateCustomer(
      email: option.None,
      name: option.None,
      description: option.None,
      metadata: option.Some(dict.new()),
    )
  let assert Ok(_) = customers.update(stripe, "cus_123", input)
}

pub fn payment_intents_metadata_request_test() {
  let metadata = dict.from_list([#("order_id", "ord_123")])
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"pi_123\",\"object\":\"payment_intent\",\"amount\":1999,\"currency\":\"usd\",\"status\":\"requires_payment_method\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata[order_id]", "ord_123"))
      },
    )
  let input =
    payment_intents.CreatePaymentIntent(
      amount: 1999,
      currency: "usd",
      customer: option.None,
      confirm_now: False,
      payment_method: option.None,
      metadata: option.Some(metadata),
    )
  let assert Ok(_) = payment_intents.create(stripe, input)
}

pub fn checkout_sessions_metadata_request_test() {
  let metadata = dict.from_list([#("cart_id", "cart_123")])
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"cs_123\",\"object\":\"checkout.session\",\"mode\":\"payment\",\"status\":\"open\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata[cart_id]", "cart_123"))
      },
    )
  let input =
    checkout_sessions.CreateCheckoutSession(
      mode: "payment",
      success_url: "https://example.com/success",
      cancel_url: "https://example.com/cancel",
      customer: option.None,
      price_id: "price_123",
      quantity: 1,
      metadata: option.Some(metadata),
    )
  let assert Ok(_) = checkout_sessions.create(stripe, input)
}

pub fn refunds_metadata_request_test() {
  let metadata = dict.from_list([#("refund_reason", "duplicate")])
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"re_123\",\"object\":\"refund\",\"amount\":100,\"currency\":\"usd\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata[refund_reason]", "duplicate"))
      },
    )
  let input =
    refunds.CreateRefund(
      payment_intent: "pi_123",
      amount: option.Some(100),
      reason: option.None,
      metadata: option.Some(metadata),
    )
  let assert Ok(_) = refunds.create(stripe, input)
}

pub fn subscriptions_metadata_request_test() {
  let metadata = dict.from_list([#("plan", "pro")])
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"active\",\"customer\":\"cus_123\",\"metadata\":{}}",
      assert_request: fn(request) {
        assert_form_contains(request, #("metadata[plan]", "pro"))
      },
    )
  let input =
    subscriptions.CreateSubscription(
      customer: "cus_123",
      price_id: "price_123",
      quantity: 1,
      metadata: option.Some(metadata),
    )
  let assert Ok(_) = subscriptions.create_subscription(stripe, input)
}

pub fn subscriptions_update_quantity_request_test() {
  let stripe =
    request_asserting_client(
      body: "{\"id\":\"sub_123\",\"object\":\"subscription\",\"status\":\"active\",\"customer\":\"cus_123\",\"metadata\":{}}",
      assert_request: fn(request) {
        let types.Request(path:, ..) = request
        assert path == "/subscriptions/sub_123"
        assert_form_contains(request, #("items[0][id]", "si_123"))
        assert_form_contains(request, #("items[0][quantity]", "7"))
      },
    )

  let assert Ok(subscription) =
    subscriptions.update_quantity(stripe, "sub_123", "si_123", 7)
  assert subscription.id == "sub_123"
  assert subscription.customer == "cus_123"
}

fn fake_client(status status: Int, body body: String) -> types.Client {
  stripify.new("sk_test_123")
  |> stripify.with_transport(client_transport(status, body))
}

fn request_asserting_client(
  body body: String,
  assert_request assert_request: fn(types.Request) -> Nil,
) -> types.Client {
  stripify.new("sk_test_123")
  |> stripify.with_transport(asserting_transport(body, assert_request))
}

fn client_transport(status: Int, body: String) -> types.Transport {
  fn(_config, request) {
    let types.Request(headers:, ..) = request
    let has_auth = has_authorization_header(headers)
    case has_auth {
      True ->
        Ok(types.Response(
          status: status,
          headers: [#("request-id", "req_123")],
          body: body,
        ))
      False -> Error(types.InvalidResponse("missing auth header"))
    }
  }
}

fn asserting_transport(
  body: String,
  assert_request: fn(types.Request) -> Nil,
) -> types.Transport {
  fn(_config, request) {
    let types.Request(headers:, ..) = request
    let has_auth = has_authorization_header(headers)
    case has_auth {
      True -> {
        assert_request(request)
        Ok(types.Response(
          status: 200,
          headers: [#("request-id", "req_123")],
          body: body,
        ))
      }
      False -> Error(types.InvalidResponse("missing auth header"))
    }
  }
}

fn has_authorization_header(headers: List(#(String, String))) -> Bool {
  case list.find(headers, fn(pair) { pair.0 == "Authorization" }) {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn assert_form_contains(
  request: types.Request,
  expected: #(String, String),
) -> Nil {
  let types.Request(form:, ..) = request
  let found = list.any(form, fn(pair) { pair == expected })
  assert found
}

fn assert_query_contains(
  query: List(#(String, String)),
  expected: #(String, String),
) -> Nil {
  let found = list.any(query, fn(pair) { pair == expected })
  assert found
}

@external(erlang, "stripify_webhooks_ffi", "sign_hex")
fn sign_hex(secret: String, payload: String) -> String

@external(erlang, "stripify_env_ffi", "getenv")
fn getenv(key: String) -> String
