-module(stripify_webhooks_ffi).
-export([secure_equals/2, sign_hex/2]).

sign_hex(Secret, Payload) ->
    Mac = crypto:mac(hmac, sha256, Secret, Payload),
    hex(Mac).

secure_equals(Left, Right) ->
    LeftBin = to_binary(Left),
    RightBin = to_binary(Right),
    case byte_size(LeftBin) =:= byte_size(RightBin) of
        false -> false;
        true -> crypto:hash_equals(LeftBin, RightBin)
    end.

hex(Bin) ->
    << <<(hex_char(N bsr 4)), (hex_char(N band 15))>> || <<N>> <= Bin >>.

hex_char(N) when N >= 0, N =< 9 ->
    $0 + N;
hex_char(N) ->
    $a + (N - 10).

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) ->
    unicode:characters_to_binary(io_lib:format("~p", [Value])).
