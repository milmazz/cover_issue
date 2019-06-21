# Cover Issue

Basic project to reproduce an error found on Elixir `v1.9.0-rc0` using Erlang/OTP `22.0.4`.

## Environment

**Elixir version:**

```console
milmazz ~/D/e/cover_issue λ elixir --version
Erlang/OTP 22 [erts-10.4.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Elixir 1.10.0-dev (4e9dce2) (compiled with Erlang/OTP 22)
```

**Operating system:** macOS Mojave

## Current behavior

You can reproduce the issue with this repo: https://github.com/milmazz/cover_issue

```
milmazz ~/D/e/cover_issue λ mix compile
Compiling 2 files (.ex)
Generated cover_issue app
```

Unit tests are ok:

```console
milmazz ~/D/e/cover_issue λ mix test
.

Finished in 0.04 seconds
1 test, 0 failures

Randomized with seed 592432
```

But, does not work when you try to run the coverage tool:

```console
milmazz ~/D/e/cover_issue λ mix test --cover
Cover compiling modules ...
** (exit) an exception was raised:
    ** (ArithmeticError) bad argument in arithmetic expression
        :erlang.+(:undefined, 0)
        (stdlib) epp.erl:1815: anonymous fn/2 in :epp.interpret_file_attr/3
        (stdlib) erl_parse.yrl:1623: anonymous fn/3 in :erl_parse.map_anno/2
        (stdlib) erl_parse.yrl:1745: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1759: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1737: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3
    cover.erl:600: :cover.call/1
    (mix) lib/mix/tasks/test.ex:14: Mix.Tasks.Test.Cover.start/2
    (mix) lib/mix/tasks/test.ex:409: Mix.Tasks.Test.do_run/3
    (mix) lib/mix/task.ex:331: Mix.Task.run_task/3
    (mix) lib/mix/cli.ex:79: Mix.CLI.run_task/2
```

Let's run `:cover.compile_beam/1` against each `beam` file to see what's going on:

```console
milmazz ~/D/e/cover_issue λ ls _build/dev/lib/cover_issue/ebin/
Elixir.Bad.beam  Elixir.Good.beam cover_issue.app

milmazz ~/D/e/cover_issue λ iex -S mix
Erlang/OTP 22 [erts-10.4.3] [source] [64-bit] [smp:4:4] [ds:4:4:10] [async-threads:1] [hipe]

Interactive Elixir (1.10.0-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Path.expand("_build/dev/lib/cover_issue/ebin/Elixir.Good.beam", __DIR__) |> to_charlist() |> :cover.compile_beam()
{:ok, Good}
iex(2)> Path.expand("_build/dev/lib/cover_issue/ebin/Elixir.Bad.beam", __DIR__) |> to_charlist() |> :cover.compile_beam()
** (exit) an exception was raised:
    ** (ArithmeticError) bad argument in arithmetic expression
        :erlang.+(:undefined, 0)
        (stdlib) epp.erl:1815: anonymous fn/2 in :epp.interpret_file_attr/3
        (stdlib) erl_parse.yrl:1623: anonymous fn/3 in :erl_parse.map_anno/2
        (stdlib) erl_parse.yrl:1745: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1759: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1737: :erl_parse.modify_anno1/3
        (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3
    cover.erl:600: :cover.call/1
    cover.erl:310: :cover.compile_beam/1
iex(2)>
22:06:47.778 [error] Process #PID<0.143.0> raised an exception
** (ArithmeticError) bad argument in arithmetic expression
    :erlang.+(:undefined, 0)
    (stdlib) epp.erl:1815: anonymous fn/2 in :epp.interpret_file_attr/3
    (stdlib) erl_parse.yrl:1623: anonymous fn/3 in :erl_parse.map_anno/2
    (stdlib) erl_parse.yrl:1745: :erl_parse.modify_anno1/3
    (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3
    (stdlib) erl_parse.yrl:1759: :erl_parse.modify_anno1/3
    (stdlib) erl_parse.yrl:1737: :erl_parse.modify_anno1/3
    (stdlib) erl_parse.yrl:1758: :erl_parse.modify_anno1/3

nil
```

The previous error also happens with `master` (commit:
[4e9dce2820c75ebf1ccf409858953f884f0f0216](https://github.com/elixir-lang/elixir/commit/4e9dce2820c75ebf1ccf409858953f884f0f0216)), but it works as expected with
`elixir 1.8.2-otp-22`.

After doing some tests, I found that a workaround is to avoid using `with` like this:

```elixir
# Bad
with {:ok, address} <- address |> String.to_charlist() |> :inet.parse_address() do
  {:ok, %{address: address, netmask: netmask}}
else
  _ ->
    error_response(is_v6, netmask)
end
```

You have to change the previous example into a `case` like this:

```elixir
# Good
case address |> String.to_charlist() |> :inet.parse_address() do
  {:ok, address} ->
    {:ok, %{address: address, netmask: netmask}}

  _ ->
    error_response(is_v6, netmask)
end
```

I tried finding the _real issue_ decompiling both `beam` files and doing a
comparison and apparently the next piece is where the `undefined` is found:

```diff
128,144c128,144
<                   ( case call 'inet':'parse_address'
<                          (_11) of
<                   <{'ok',_X_address@5}> when 'true' ->
<                       let <_12> =
<                       ~{%% Line 14
<                        'address'=>_X_address@5,%% Line 14
<                                    'netmask'=>_X_netmask@3}~
<                       in  {'ok',_12}
<                   ( <_X__@2> when 'true' ->
<                         %% Line 17
<                         apply 'error_response'/2
<                         (_X_is_v6@1, _X_netmask@3)
<                     -| ['undefined',{'file',"lib/bad.ex"}] )
<                     end
<                     -| ['compiler_generated'] )
<           ( <( _18
<                -| ['compiler_generated'] ),( _19
---
>                   case call 'inet':'parse_address'
>                        (_11) of
>                     %% Line 14
>                     <{'ok',_X_address@5}> when 'true' ->
>                     let <_12> =
>                         ~{%% Line 15
>                          'address'=>_X_address@5,%% Line 15
>                                      'netmask'=>_X_netmask@3}~
>                     in  {'ok',_12}
>                     %% Line 17
>                     <_16> when 'true' ->
>                     %% Line 18
>                     apply 'error_response'/2
>                         (_X_is_v6@1, _X_netmask@3)
>                   end
>           ( <( _19
>                -| ['compiler_generated'] ),( _20
```

I _think_ this line `-| ['undefined',{'file',"lib/bad.ex"}] )` is the one
causing the issue, but I'm a bit lost from here.

## Expected behavior

`mix test --cover` should work as in `elixir 1.8.2-otp22`.
