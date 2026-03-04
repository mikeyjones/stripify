-module(stripify_json_ffi).
-export([decode/1]).

decode(Body) ->
    try
        {ok, json:decode(Body)}
    catch
        _:Reason ->
            {error, unicode:characters_to_binary(io_lib:format("~p", [Reason]))}
    end.
