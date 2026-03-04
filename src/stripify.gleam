import stripify/client
import stripify/types.{type Client, type Transport}

/// Create a Stripe client using a secret API key.
///
/// The returned client uses the default Stripe base URL, Stripe-Version header,
/// and OTP transport.
pub fn new(api_key: String) -> Client {
  client.new(api_key)
}

/// Return a copy of the client configured with a custom base URL.
///
/// This is useful for tests or proxying Stripe traffic through another service.
pub fn with_base_url(client: Client, base_url: String) -> Client {
  client.with_base_url(client, base_url)
}

/// Return a copy of the client with a specific Stripe API version header.
pub fn with_stripe_version(client: Client, stripe_version: String) -> Client {
  client.with_stripe_version(client, stripe_version)
}

/// Return a copy of the client with a custom request timeout in milliseconds.
pub fn with_timeout_ms(client: Client, timeout_ms: Int) -> Client {
  client.with_timeout_ms(client, timeout_ms)
}

/// Return a copy of the client with a custom transport function.
///
/// This is intended for deterministic tests or custom HTTP integration.
pub fn with_transport(client: Client, transport: Transport) -> Client {
  client.with_transport(client, transport)
}
