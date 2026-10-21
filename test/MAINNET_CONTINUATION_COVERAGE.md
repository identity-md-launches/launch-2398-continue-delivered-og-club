# Additional mainnet continuation coverage

These tests extend the accepted suite without changing application code, ABIs,
deployment inputs, configuration, or dependencies. They run offline.

| File | Added checks |
| --- | --- |
| `FootprintBatchProperties.t.sol` | Batches of 1–32 distinct IDs agree with individual calls in reverse order; each input produces the unchanged `FootprintSet` event with the correct indexed ID and data. Invalid dimensions at any position and duplicates at any two positions revert atomically, and corrected batches remain usable. Explicit zero and maximum uint256 ID cases check finality. |
| `FootprintCatalogueInvariant.t.sol` | Three players, three administrators, three clubs, and 32 designs mix single/batch definitions, rejected batches, queued placements, club transfers, upgrades, and two-step ownership nominations, cancellations, and acceptance. |

The three batch fuzz properties each run 512 cases. The invariant campaign runs
128 sequences of depth 64 with unexpected handler reverts treated as failures.
Inputs use bounds instead of discarded assumptions. A deterministic handler test
exercises every batch failure mode, cancelled ownership nominations, a queued
placement whose sender loses club ownership, and repeated placement attempts.

The invariant model records definitions from successful setter inputs and keeps
them independent of `footprintOf`. A failed batch cannot add even its valid
prefix, and neither setter nor a successor owner can change a definition.
The legacy `locked` view must still indicate placement, independently of the
definition's finality.

Placement payloads and their original dimensions/kind are saved before execution
and survive arbitrary intervening calls. A separate cell-based layout model
decides whether they should succeed. Every accepted piece must debit exactly
one player's furniture and remain in club custody with its original coordinates,
rotation, and kind. Per-design supply stays constant, balances reconcile with
recorded pieces, and failed placements cannot change occupancy. Both floor and
wall custody, a handoff, and successful/rejected batches are seeded so these
properties exercise meaningful state from the first sequence. Occupancy views
are checked after every placement attempt and at the end of every sequence.

The existing suites continue to cover constructor vault sentinels, all five
mainnet constructors in one factory call, the exact launch catalogue/calldata,
all five ownership handoffs, delayed grants, staking/vault conservation, and
raffle accounting. This addition does not broadcast transactions or establish
live mainnet dependency state or Etherscan verification.

Run from the repository root using the assignment's verification seed:

```sh
forge build
FOUNDRY_FUZZ_SEED=0x9db4561c3296ebc2311047acd1329ea68f97f45eb4b09ae7deedaf1dbaa06b2e forge test
forge fmt --check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s test -p 'test_*.py' -v
```

Build artifacts can be kept in the disposable scratch directory with
`--out test/scratch/out --cache-path test/scratch/cache`. The equivalent variables
for Python's `forge inspect` subprocesses are `FOUNDRY_OUT=test/scratch/out` and
`FOUNDRY_CACHE_PATH=test/scratch/cache`.
