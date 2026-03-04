import gleam/dynamic/decode
import stripify/types

/// Decode the minimal Stripe object envelope (`id` and `object`).
pub fn stripe_object() -> decode.Decoder(types.StripeObject) {
  {
    use id <- decode.field("id", decode.string)
    use object <- decode.field("object", decode.string)
    decode.success(types.StripeObject(id: id, object: object))
  }
}

/// Decode Stripe list responses with `has_more` and `data`.
///
/// Pass the decoder for each item in the `data` array.
pub fn stripe_list(
  item_decoder: decode.Decoder(item),
) -> decode.Decoder(types.StripeList(item)) {
  {
    use has_more <- decode.field("has_more", decode.bool)
    use data <- decode.field("data", decode.list(of: item_decoder))
    decode.success(types.StripeList(has_more: has_more, data: data))
  }
}
