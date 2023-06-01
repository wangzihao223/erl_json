erl_json
=====

实现简单并且易用的json解析器

Build
-----

    $ rebar3 compile

API
------

*JSON String —> Erlang Term* 

```erlang
1> erl_json:deserialization("[1, 2, 3, 4, 5]").
{ok,[1,2,3,4,5]}
2> erl_json:deserialization("[1, 2, 3, 4, 5"). 
{error,"array_error"}
3> erl_json:deserialization("{\"name\":\"zihao\", \"age\":23}").
{ok,#{<<"age">> => 23,<<"name">> => <<"zihao">>}}
```

*Erlang Term-> JSON String*

```erlang
4> erl_json:serialization([1,2,3,4]).
{ok,<<"[1,2,3,4]">>}
15> erl_json:serialization([1,2,3,<<"hello">>]).
{ok,<<"[1,2,3,\"hello\"]">>}
17> erl_json:serialization([true ,3,<<"hello">>, #{<<"name">>=><<"zihao">>}]).                             
{ok,<<"[true,3,\"hello\",{\"name\":\"zihao\"}]">>}
```

JSON <->Erlang mapping
------

| JSON                 | Erlang                     |
| -------------------- | -------------------------- |
| number               | interger() and float()     |
| string               | binary()                   |
| true, false and null | true false and null (atom) |
| object               | #{}  map                   |
| array                | [] and [JSON] list()       |

