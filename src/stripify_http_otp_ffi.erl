-module(stripify_http_otp_ffi).
-export([request/5]).

request(Method, Url, Headers, Body, TimeoutMs) ->
    _ = application:ensure_all_started(inets),
    MethodAtom = method_atom(Method),
    Request = build_request(MethodAtom, Url, normalize_headers(Headers), Body),
    HttpOptions = [{timeout, TimeoutMs}],
    Options = [{body_format, binary}],
    case httpc:request(MethodAtom, Request, HttpOptions, Options) of
        {ok, {{_Version, Status, _Reason}, ResponseHeaders, ResponseBody}} ->
            {ok, {Status, denormalize_headers(ResponseHeaders), to_binary(ResponseBody)}};
        {error, timeout} ->
            {error, <<"timeout">>};
        {error, Reason} ->
            {error, to_binary(Reason)}
    end.

method_atom(<<"GET">>) -> get;
method_atom(<<"POST">>) -> post;
method_atom(<<"DELETE">>) -> delete;
method_atom("GET") -> get;
method_atom("POST") -> post;
method_atom("DELETE") -> delete;
method_atom(_) -> get.

build_request(post, Url, Headers, Body) ->
    {to_list(Url), Headers, "application/x-www-form-urlencoded", to_list(Body)};
build_request(_, Url, Headers, _Body) ->
    {to_list(Url), Headers}.

normalize_headers(Headers) ->
    lists:map(
      fun({Key, Value}) ->
          {to_list(Key), to_list(Value)}
      end,
      Headers
    ).

denormalize_headers(Headers) ->
    lists:map(
      fun({Key, Value}) ->
          {to_binary(Key), to_binary(Value)}
      end,
      Headers
    ).

to_list(Value) when is_binary(Value) ->
    unicode:characters_to_list(Value);
to_list(Value) when is_list(Value) ->
    Value;
to_list(Value) ->
    unicode:characters_to_list(io_lib:format("~p", [Value])).

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) ->
    unicode:characters_to_binary(io_lib:format("~p", [Value])).
