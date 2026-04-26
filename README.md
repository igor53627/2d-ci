# 2D Chain: Public Test Reports

[![Tests](https://img.shields.io/badge/tests-51%20passing-brightgreen)](https://igor53627.github.io/2d-ci/) [![Groups](https://img.shields.io/badge/groups-14-blue)](https://igor53627.github.io/2d-ci/) [![Docs](https://img.shields.io/badge/docs-online-blue)](https://igor53627.github.io/2d-docs/)

Browser-friendly snapshots of the [2D Chain](https://github.com/igor53627/2d) integration test suite, with EN/RU explanations and assertion details.

**[→ View live report](https://igor53627.github.io/2d-ci/)** · **[→ Architecture docs](https://igor53627.github.io/2d-docs/)**

## What's here

The integration suite is the end-to-end layer that exercises the full chain stack (RPC handler, block producer, executor, database, verifier) against realistic transaction shapes: ETH RLP, Tron protobuf, HTLC precompile calls, and cross-format scenarios.

Each test on the report page shows:

- the actual ExUnit name from the source
- a short explanation of what it proves
- the assertions checked in the test body
- both English and Russian, switchable in-page

## Updates

The HTML is regenerated whenever new groups land in the main repo. Commits in this repo follow the pattern `update: N tests / M groups — <change>`.
