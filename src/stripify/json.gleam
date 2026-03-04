import gleam/dynamic
import gleam/dynamic/decode
import stripify/types

/// Decode JSON text into a typed value using a Gleam dynamic decoder.
///
/// Returns `types.Decode` for invalid JSON or mismatched decoder shape.
pub fn decode(
  body: String,
  with decoder: decode.Decoder(a),
) -> Result(a, types.Error) {
  case decode_dynamic(body) {
    Error(message) -> Error(types.Decode("Invalid JSON: " <> message))
    Ok(raw) ->
      case decode.run(raw, decoder) {
        Ok(data) -> Ok(data)
        Error(_) ->
          Error(types.Decode("JSON shape did not match expected type"))
      }
  }
}

/// Decode JSON and return both the raw dynamic tree and typed decoded value.
pub fn decode_with_raw(
  body: String,
  with decoder: decode.Decoder(a),
) -> Result(types.Decoded(a), types.Error) {
  case decode_dynamic(body) {
    Error(message) -> Error(types.Decode("Invalid JSON: " <> message))
    Ok(raw) ->
      case decode.run(raw, decoder) {
        Ok(data) -> Ok(types.Decoded(raw: raw, data: data))
        Error(_) ->
          Error(types.Decode("JSON shape did not match expected type"))
      }
  }
}

/// Parse JSON into raw dynamic data without applying a typed decoder.
pub fn as_dynamic(body: String) -> Result(dynamic.Dynamic, types.Error) {
  case decode_dynamic(body) {
    Ok(data) -> Ok(data)
    Error(message) -> Error(types.Decode("Invalid JSON: " <> message))
  }
}

@external(erlang, "stripify_json_ffi", "decode")
fn decode_dynamic(body: String) -> Result(dynamic.Dynamic, String)
