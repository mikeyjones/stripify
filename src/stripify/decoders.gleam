import gleam/dict
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

/// Decode Stripe metadata objects as flat string key/value pairs.
pub fn metadata() -> decode.Decoder(types.Metadata) {
  decode.dict(decode.string, decode.string)
}

pub fn optional_metadata(
  next: fn(types.Metadata) -> decode.Decoder(a),
) -> decode.Decoder(a) {
  decode.optional_field("metadata", dict.new(), metadata(), next)
}
