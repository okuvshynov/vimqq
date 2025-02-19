This would be a small benchmark set to understand/evaluate the quality.

We should probably run this in docker container.

Likely we'll need individual Dockerfile for each

We can benchmark bot's strength as engineer, reviewer and 'indexer'.

Let's start with 1 step first - engineer.

Swebench uses something like this as input:

1. repo
2. commit_id
3. issue description
4. test to run to verify correctness
5. tests to run to detect regressions

In many cases SWEBench is making a bug fix. What if we need feature implementation or code quality improvement, how do we measure that?

We can use similar structure, except:
1. running tests must be more custom - it's not python-only (both success and failure)
2. how do we configure bots? just do in vimrc in docker? 
3. we need to test entire combination of bot config + vimqq implementation. So one more 'parameter' becomes:
    - vimqq version
    - bot config (model, version, settings, etc)
4. We need to tell the difference between infra failure (API overloaded, etc) and actual model output failure.

Let's start with a single issue and see how we can make it work.
Index is part of the input.

for eng, input is commit + index + custom validation.

for reviewer, same + chat + patch

for indexer, commit + list of 'eng benchmarks' to verify
