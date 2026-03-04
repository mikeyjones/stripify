-module(stripify_env_ffi).
-export([getenv/1]).

getenv(Key) ->
    case os:getenv(to_list(Key)) of
        false -> <<"">>;
        Value -> unicode:characters_to_binary(Value)
    end.

to_list(Value) when is_binary(Value) ->
    unicode:characters_to_list(Value);
to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) ->
    unicode:characters_to_list(io_lib:format("~p", [Value])).
