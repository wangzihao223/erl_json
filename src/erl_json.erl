-module(erl_json).

% api
-export([deserialization/1]).
-export([serialization/1]).


-export([test/1]).
-export([test_s/1]).

% API

% JSON String —> Erlang Term 

deserialization(List) -> 
    case type_analyser(List) of
        {error, R} -> {error, R};
        {_, R} -> {ok, R}
    end.

% Erlang Term-> JSON String
serialization(Object) when erlang:is_binary(Object) -> 
    S = bit_size(Object),
    <<H:S>> = Object,
    {ok, <<34:8, H:S, 34:8>>};
serialization(Object) when erlang:is_atom(Object) ->
    {ok, atom_to_binary(Object)};
serialization(Object) when erlang:is_integer(Object) ->
    {ok, integer_to_binary(Object)};
serialization(Object) when erlang:is_float(Object) ->
    {ok, float_to_binary(Object, [short])};
serialization(Object) when erlang:is_list(Object) ->
    loop_list(Object, [91]);
serialization(Object) when erlang:is_map(Object) ->
    Iter = maps:iterator(Object),
    loop_maps(maps:next(Iter), [123]);
serialization(_Object) ->
    {error, "typer_error"}.

type_analyser([]) -> {error, "typer_error"};
type_analyser([W|Body]) ->
    case W of
        32 ->
            type_analyser(Body);
        10 ->
            type_analyser(Body);
        116 ->
            true_obj(Body);
        102 ->
            false_obj(Body);
        110 ->
            null_obj(Body);
        34 ->
            string_obj(Body, []);
        N when N > 47 , N < 58 ->
            number_obj(Body, [N]);
        91 ->
            array_obj(Body, []);
        123 ->
            object_obj(Body, #{});
        N ->
            {error, "typer_error", N, Body}
    end.


string_obj([], _S) -> {error, "string_error"};
string_obj([W|Body], S)->
    case W of
        34 ->
            {Body, list_to_binary(lists:reverse(S))};
        92 ->
            case escape_character(Body, S) of
                {error, _} -> {error, "string_error"};
                {Body1, S1} -> string_obj(Body1, S1)
            end;
        _ ->
            NS = [W|S],
            string_obj(Body, NS)
    end.

escape_character([W1,W2 | Body], S) -> {Body, [W1, W2| S]};
escape_character(_, _) -> {error, "string_error"}.
            


number_obj([], S) ->
    {[], erlang:list_to_integer(lists:reverse(S))};
number_obj([W|Body], S) ->
    case W of
        _Number when W > 47 , W < 58 ->
            % number;
            NS = [W|S],
            number_obj(Body, NS);
        46 ->
            % float
            float_legality(Body, [W|S]);
        _ ->
            R = erlang:list_to_integer(lists:reverse(S)),
            {[W|Body], R}
    end.

float_legality([], _S) ->
    {error, "float_error"};
float_legality([W|B],S) ->
    if W > 47, W < 58 ->
       NS = [W|S],
       float_obj(B, NS);
    true ->
        {error, "float_error"}
    end.

float_obj([], S) ->
    R = erlang:list_to_float(lists:reverse(S)),
    {[], R};
float_obj([W|Body], S) ->
    if W > 47, W < 58 ->
        NS = [W|S],
        float_obj(Body, NS);
    true ->
        {[W|Body], erlang:list_to_float(lists:reverse(S))}
    end.


null_obj([117, 108, 108 | Body]) ->
    {Body, null};
null_obj(_B) ->
    {error, "null_error"}.


true_obj([114, 117, 101 | Body]) ->
    {Body, true};
true_obj(_B) ->
    {error, "true_error"}.

false_obj([97, 108, 115, 101 | Body]) ->
    {Body, false};
false_obj(_B) ->
    {error, "false_error"}.

array_obj(Body, S) ->
    case type_analyser(Body) of
        {error, R, N, B} ->
            if N == 93 -> {B, S};
                true -> {error, R}
            end;
        {error, R} ->
            {error, R};
        {NBody, NS} ->
            NS1 = [NS|S],
            case array_next(NBody) of
                {true, NBody1} -> array_obj(NBody1, NS1);
                {false, NBody1} -> {NBody1, lists:reverse(NS1)};
                {error, _} -> {error, "array_error"}
            end
    end.
array_next([]) ->
    {error, "array_error"};
array_next([W|Body]) ->
    case W of
        10 -> array_next(Body);
        44 ->
            {true, Body};
        32 ->
            array_next(Body);
        93 ->
            {false, Body};
        _ ->
            {error, "array_error"}
    end.


object_obj(Body, KV) ->
    case find_kv(Body)  of
        {error, R} -> {error, R};
        {Body1, Key, V} -> 
            NKV = KV#{Key=>V},
            case object_next(Body1) of
                {true, Body2} -> object_obj(Body2, NKV);
                {false, Body2} -> {Body2, NKV};
                {error, R} -> {error, R}
            end
    end.

object_next([W|Body]) ->
    case W of
        10 -> object_next(Body);
        44 -> {true, Body};
        32 -> object_next(Body);
        125 -> {false, Body};
        _ -> {error, "object_error"}
    end.

find_kv([]) ->{error, "object_key_error"};
find_kv([W|Body]) ->
    case W of 
        10 ->
            find_kv(Body);
        32 ->
            find_kv(Body);
        34 ->
            case string_obj(Body, []) of
                {error, R} -> {error, R};
                {NBody, Key} -> 
                    case find_colon(NBody) of
                        {error, R} -> {error, R};
                        {Body1, V} -> {Body1, Key, V};
                        {error, R, _, _} -> {error, R}
                    end
            end;
        125 ->
            {Body, {}};
        _ ->
            {error, "object_key_error"}
    end.


find_colon([W|Body]) ->
    case W of
        10 ->
            find_colon(Body);
        32 ->
            find_colon(Body);
        58 ->
            type_analyser(Body);
        _ ->
            {error, "object_colon_error"}
    end.





loop_list([], Bin) ->
    [_| Main] = Bin,
    Res = list_to_binary(lists:reverse([93|Main])),
    {ok, Res};
loop_list([E|Body], Bin) ->
    case serialization(E) of 
        {ok, B} ->
            NB = [44, B|Bin],
            loop_list(Body, NB);
        {error, R} -> {error, R}
    end.

loop_maps(none, Bin) ->
    [_|Main] = Bin,
    Res = list_to_binary(lists:reverse([125|Main])),
    {ok, Res};
loop_maps({K, V, Iter}, Bin)->
    R1 = serialization(K),
    R2 = serialization(V),
    case [R1, R2] of
        [{ok, B1}, {ok, B2}] ->
            NB = [44, B2, 58, B1 | Bin],
            loop_maps(maps:next(Iter), NB);
        [E1, _E2] -> E1
    end.

% pack_maps(K, V) -> [V, 58, K].


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

test(N) ->
    {ok, Bin} = file:read_file("001.json"),
    L = binary:bin_to_list(Bin),
    S = erlang:system_time(microsecond),
    loop(N, L),
    E = erlang:system_time(microsecond),
    io:format("Spend ~p ~n", [E-S]),
    io:format("one second ~p, ~n", [N/(E-S)/1000_000]),
    io:format("spend time once ~p ~n", [(E-S)/N/1000]).

loop(0, _L) ->ok;
loop(N, L) ->
    type_analyser(L),
    loop(N-1, L).

loop1(0, _L) ->ok;
loop1(N, L) ->
    serialization(L),
    % Ls = binary:bin_to_list(R),
    % type_analyser(Ls),
    loop1(N-1, L).
test_s(N) ->
    {ok, Bin} = file:read_file("002.json"),
    L = binary:bin_to_list(Bin),
    {_, ET} = type_analyser(L),
    io:format("ET ~p ~n", [ET]),
    % S = erlang:system_time(microsecond),
    % loop1(N, ET),
    {ok,B} = serialization(ET),
    % io:format("B ~p ~n", [B]),
        % E = erlang:system_time(microsecond),
        % io:format("Spend ~p ~n", [(E-S)/1000]),
        % io:format("one second ~p, ~n", [N/((E-S)/1000_000)]),
        % io:format("spend time once ~p ~n", [(E-S)/N/1000]).
    % B = serialization(<<"wangzihaonihao">>),
    file:write_file("003.json", B).