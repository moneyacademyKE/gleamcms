-module(gleamcms_httpc_ffi).
-export([post/3, get_env/1, hmac_sha256/2, run_gemini/2]).

%% HMAC-SHA256, returned as lowercase hex. Used to sign the stateless admin
%% session cookie. crypto is guaranteed running under the wisp/mist runtime.
hmac_sha256(Secret, Msg) ->
    Mac = crypto:mac(hmac, sha256, binary_to_list(Secret), binary_to_list(Msg)),
    Hex = lists:flatten([io_lib:format("~2.16.0B", [B]) || B <- binary_to_list(Mac)]),
    list_to_binary(Hex).

%% Spawn the `gemini` executable with the prompt as a separate argv element via
%% open_port({spawn_executable, ...}, [{args, [...]}]). This NEVER goes through a
%% shell, so arbitrary user text in the prompt cannot inject shell operators or
%% metacharacters — it is passed verbatim as one argument to `gemini -p`.
%% Returns {ok, Stdout} on exit 0, {error, Msg} otherwise.
run_gemini(SystemPrompt, UserPrompt) ->
    case os:find_executable("gemini") of
        false ->
            {error, <<"gemini executable not found on PATH">>};
        Path ->
            Full = iolist_to_binary([SystemPrompt, <<" Prompt: ">>, UserPrompt]),
            Port = open_port({spawn_executable, Path}, [
                {args, ["-p", binary_to_list(Full)]},
                exit_status, use_stdio, binary, stream
            ]),
            collect_port(Port, <<>>)
    end.

%% Drain stdout chunks until the process exits, then close the port.
collect_port(Port, Acc) ->
    receive
        {Port, {data, Chunk}} ->
            collect_port(Port, <<Acc/binary, Chunk/binary>>);
        {Port, {exit_status, 0}} ->
            port_close(Port),
            {ok, Acc};
        {Port, {exit_status, Code}} ->
            port_close(Port),
            {error, iolist_to_binary([
                <<"gemini exited with code ">>, integer_to_binary(Code)
            ])}
    end.

post(Url, Headers, Body) ->
    inets:start(),
    ssl:start(),
    UrlStr = binary_to_list(Url),
    HeadersList = [{binary_to_list(K), binary_to_list(V)} || {K, V} <- Headers],
    BodyStr = binary_to_list(Body),
    ContentType = "application/json",

    case httpc:request(post, {UrlStr, HeadersList, ContentType, BodyStr}, [], []) of
        {ok, {{_Version, 200, _Reason}, _RespHeaders, RespBody}} ->
            {ok, list_to_binary(RespBody)};
        {ok, {{_Version, Status, Reason}, _RespHeaders, RespBody}} ->
            {error, list_to_binary(io_lib:format("HTTP ~p: ~s - ~s", [Status, Reason, RespBody]))};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("Network error: ~p", [Reason]))}
    end.

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Val -> {ok, list_to_binary(Val)}
    end.
