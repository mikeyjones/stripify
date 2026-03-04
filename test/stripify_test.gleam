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
    "{\"id\":\"cus_123\",\"object\":\"customer\",\"email\":\"jane@example.com\",\"name\":\"Jane\"}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    customers.CreateCustomer(
      email: option.Some("jane@example.com"),
      name: option.Some("Jane"),
      description: option.None,
    )

  let assert Ok(customer) = customers.create(stripe, input)
  assert customer.id == "cus_123"
  assert customer.email == option.Some("jane@example.com")
}

pub fn payment_intents_decode_test() {
  let body =
    "{\"id\":\"pi_123\",\"object\":\"payment_intent\",\"amount\":1999,\"currency\":\"usd\",\"status\":\"requires_payment_method\",\"customer\":\"cus_123\"}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    payment_intents.CreatePaymentIntent(
      amount: 1999,
      currency: "usd",
      customer: option.Some("cus_123"),
      confirm_now: False,
      payment_method: option.None,
    )

  let assert Ok(intent) = payment_intents.create(stripe, input)
  assert intent.amount == 1999
  assert intent.customer == option.Some("cus_123")
}

pub fn checkout_sessions_decode_test() {
  let body =
    "{\"id\":\"cs_123\",\"object\":\"checkout.session\",\"mode\":\"payment\",\"status\":\"open\",\"url\":\"https://checkout.stripe.com/c/session\",\"payment_intent\":\"pi_123\"}"
  let stripe = fake_client(status: 200, body: body)
  let input =
    checkout_sessions.CreateCheckoutSession(
      mode: "payment",
      success_url: "https://example.com/success",
      cancel_url: "https://example.com/cancel",
      customer: option.None,
      price_id: "price_123",
      quantity: 1,
    )

  let assert Ok(session) = checkout_sessions.create(stripe, input)
  assert session.mode == "payment"
  assert session.payment_intent == option.Some("pi_123")
}

pub fn refunds_list_decode_test() {
  let body =
    "{\"object\":\"list\",\"has_more\":false,\"data\":[{\"id\":\"re_123\",\"object\":\"refund\",\"amount\":100,\"currency\":\"usd\",\"status\":\"succeeded\",\"payment_intent\":\"pi_123\"}]}"
  let stripe = fake_client(status: 200, body: body)

  let assert Ok(refund_list) =
    refunds.list(stripe, option.None, option.Some(10))
  assert refund_list.has_more == False
  assert list.length(refund_list.data) == 1
}

pub fn subscriptions_and_prices_decode_test() {
  let body =
    "{\"id\":\"price_123\",\"object\":\"price\",\"currency\":\"usd\",\"unit_amount\":500,\"recurring\":{\"interval\":\"month\"},\"product\":\"prod_123\"}"
  let stripe = fake_client(status: 200, body: body)
  let assert Ok(price) = subscriptions.retrieve_price(stripe, "price_123")
  assert price.unit_amount == option.Some(500)
  assert price.recurring_interval == option.Some("month")
}

pub fn webhooks_verify_signature_test() {
  let payload =
    "{\"id\":\"evt_123\",\"type\":\"checkout.session.completed\",\"data\":{\"object\":{\"object\":\"checkout.session\"}}}"
  let timestamp = 1_700_000_000
  let secret = "whsec_test"
  let signature = sign_hex(secret, int.to_string(timestamp) <> "." <> payload)
  let header = "t=" <> int.to_string(timestamp) <> ",v1=" <> signature

  let assert Ok(_) =
    webhooks.verify_signature(payload, header, secret, timestamp + 5, 300)

  let assert Ok(event) = webhooks.decode_event(payload)
  assert event.id == "evt_123"
  assert event.event_type == "checkout.session.completed"
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

fn fake_client(status status: Int, body body: String) -> types.Client {
  stripify.new("sk_test_123")
  |> stripify.with_transport(client_transport(status, body))
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

fn has_authorization_header(headers: List(#(String, String))) -> Bool {
  case list.find(headers, fn(pair) { pair.0 == "Authorization" }) {
    Ok(_) -> True
    Error(_) -> False
  }
}

@external(erlang, "stripify_webhooks_ffi", "sign_hex")
fn sign_hex(secret: String, payload: String) -> String

@external(erlang, "stripify_env_ffi", "getenv")
fn getenv(key: String) -> String
