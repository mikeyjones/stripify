# stripify

[![Package Version](https://img.shields.io/hexpm/v/stripify)](https://hex.pm/packages/stripify)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/stripify/)

```sh
gleam add stripify@1
```

`stripify` is an OTP-focused Stripe client for Gleam with:

- Consistent `Result(_, stripify/types.Error)` APIs
- First-class support for common Stripe billing flows
- Deterministic test coverage with optional live smoke tests

## Quick start

```gleam
import gleam/dict
import stripify
import stripify/customers
import gleam/io
import gleam/option

pub fn main() -> Nil {
  let stripe = stripify.new("sk_test_...")

  let customer =
    customers.create(
      stripe,
      customers.CreateCustomer(
        email: option.Some("jane@example.com"),
        name: option.Some("Jane"),
        description: option.Some("Example customer"),
        metadata: option.Some(dict.from_list([#("crm_id", "crm_123")])),
      ),
    )

  case customer {
    Ok(customer) -> io.println("Created customer: " <> customer.id)
    Error(error) -> io.println("Stripe request failed")
  }
}
```

## Supported APIs

- `stripify/customers`
  - `create`, `retrieve`, `update`, `list`
- `stripify/payment_intents`
  - `create`, `retrieve`, `confirm`, `cancel`
- `stripify/checkout_sessions`
  - `create`, `retrieve`, `expire`
- `stripify/refunds`
  - `create`, `retrieve`, `list`
- `stripify/subscriptions`
  - `create_subscription`, `retrieve_subscription`, `cancel_subscription`, `list_subscriptions`
  - `retrieve_product`, `list_products`, `retrieve_price`, `list_prices`
- `stripify/webhooks`
  - `verify_signature`, `decode_event`

All typed Stripe resources returned by these modules expose a `metadata` field.
Create and update helpers accept optional metadata where the underlying Stripe endpoint supports it.

## Configuration

```gleam
import stripify

let stripe =
  stripify.new("sk_test_...")
  |> stripify.with_stripe_version("2025-02-24.acacia")
  |> stripify.with_timeout_ms(30_000)
```

## Error handling

All public API calls return:

```gleam
Result(data, stripify/types.Error)
```

Error variants:

- `Transport(transport_error)` for connectivity or timeout issues
- `Api(api_error)` for non-2xx Stripe responses
- `Decode(message)` for unexpected payload shape
- `Validation(message)` for client-side input validation errors
- `Webhook(message)` for webhook verification failures

## Webhook verification

```gleam
import stripify/webhooks

let result =
  webhooks.verify_signature(
    payload,
    stripe_signature_header,
    endpoint_secret,
    now_unix_seconds,
    300,
  )
```

## Testing

Run deterministic tests:

```sh
gleam test
```

Run optional live smoke test by setting `STRIPE_TEST_API_KEY`:

```sh
STRIPE_TEST_API_KEY=sk_test_... gleam test
```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
