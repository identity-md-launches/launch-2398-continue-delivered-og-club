# OG Club mainnet continuation

Base: `identity-md-launches/launch-2382-continue-delivered-og-club`, commit
`20430cbddd7e849fadf64e07f0173eccc8f6f747`. This adaptation prepares exactly five
constructor-only applications for Ethereum mainnet (chain 1). It does not
broadcast, read deployment credentials, call the live factory or invent deployed
addresses. The launch service deploys and verifies the accepted sources.

The supplied protected constructor/runtime/ownership checks and pinned security
reference were read as task data. The explicit request to update `launch.json`
takes precedence over the background reference that delegates it to a later step.
The project's build configuration, dependencies and vendored libraries are unchanged.
No package, submodule, proxy, launch token, pool or external linked library was added.

## Changes and reasons

| Files | Change and reason |
| --- | --- |
| `src/OGClubClubs.sol` | FIX 1: constructor rejects `vault == pepes` and `vault == delegates` when the registry is nonzero, using the existing `UnexpectedTokenDebit()` selector. Prevents irrevocable payment misrouting. Constructors still perform no dependency calls or code checks. |
| `src/OGClubClubs.sol` | FIX 2: the shared footprint setter checks `set`, so a second definition always reverts `FootprintLocked()`, even before placement or for identical values. Adds owner-only `setFootprints(uint256[],uint8[],uint8[],bool[])`. Length/geometry errors use existing `BadFootprint()`; duplicates and pre-existing IDs use `FootprintLocked()`. Any error rolls back all entries. Empty owner batches are no-ops. |
| `src/OGClubStaking.sol` | Reproduced audit finding: rejects `vault == token` with existing `InvalidAddress()`. This changes only invalid constructor configuration; valid staking, point accounting, fees and role delays retain their behavior. |
| `launch.json` | Removes both mock deployments/references; five entries in requested dependency order. Uses the exact OG, Swarm Pepes and delegate registry addresses, `$owner` for every owner/royalty receiver, `1e18` point rate, `604800` notice and the specified mint/upgrade prices. Notes describe all four owner setup steps, the exact catalogue and later five-contract Safe handoff. Schema remains exactly `kind`, `contracts`, `notes`, with notes under 4,000 characters. |
| `script/DeployMainnet.s.sol` | New offline five-application rehearsal with fixed approved mainnet inputs. No mock deployment, environment/key reads or broadcast. Prints constructor arguments, call targets and exact grant/URI/batch/sale calldata. `printHandoff` accepts the five confirmed addresses after deployment, so grants can be encoded without treating local rehearsal addresses as live contracts. |
| `script/club-footprints.json` | Replaces the Sepolia example with the exact approved 24-item mainnet catalogue; only ID 23 is a wall design. |
| `script/DeployClubs.s.sol` | Retains legacy standalone helpers and JSON validation. Configures/prints a single footprint batch and prints the club URI call. Labels standalone `DeployClubsMainnet` as legacy; this launch's full entry point is `DeployMainnet`. |
| `script/Deploy.s.sol` | Corrects comments that described the historical four-contract helper as the current manifest/mainnet launch. No helper execution behavior changed. |
| `test/ClubsFootprints.t.sol` | New pending-placement regressions for floor/wall kind, rotated dimensions and edge placements. Tests identical/invalid rewrites, batch permissions/events, all length mismatches, bad final entries, duplicates, pre-existing IDs, atomic rollback, empty batches and fuzzed definition finality. |
| `test/MainnetDeployment.t.sol` | New one-call CREATE2 rehearsal of all five applications with mainnet inputs and no code at external dependency addresses. Checks code limits/opcodes, owners, royalty receivers, wiring, default state, prices/rate/notice; executes printed setup calldata and independently checks all catalogue entries; checks later grant delays and all five Ownable2Step transfers to a contract-wallet fixture. |
| `test/ClubsLaunch.t.sol`, `test/ClubsReview.t.sol`, `test/Deployment.t.sol` | Extends constructor rejection tests for the two club sentinels and the staking token/vault collision. Existing zero-registry behavior remains covered. Updates old wall-footprint edit expectations. |
| `test/ClubsPlacement.t.sol`, `test/ClubsAdversarial.t.sol`, `test/ClubsAdversarialInvariant.t.sol` | Updates old editable-before-placement expectations and the independent model to final-on-definition. Keeps placement failure, custody, geometry and legacy placed-flag assertions. No fuzz runs, invariant depths or campaigns were reduced. |
| `test/ClubsReviewDeploy.t.sol` | Identifies its inlined historical Sepolia catalogue as a test fixture distinct from the new mainnet JSON. |
| `test/test_launch.py` | Validates the five mainnet entries against compiler constructor ABIs/schema and exact inputs. Adds independent catalogue and README calldata checks using `cast`, including the 3,332-byte footprint call and grant selector templates. |
| `README.md`, `test/ADDITIONAL_COVERAGE.md`, `ADAPTATION.md` | Documents final mainnet configuration, precise owner call order, literal URI/batch/sale calldata, address-dependent grant encoding, Safe handoff, verification commands and the current test/audit coverage. |

## Compatibility

Existing functions, custom error names/selectors, event signatures and constructor
argument lists are retained. The only added application ABI entry is
`OGClubClubs.setFootprints(uint256[],uint8[],uint8[],bool[])`.
`footprintOf` remains `(uint8 w,uint8 h,bool set,bool locked,bool wall)` and
`FootprintSet` is unchanged. The legacy `locked` flag continues to record first
successful placement; `set` now also determines whether a definition is final.
This preserves the view's previous placement information without allowing edits.

Placement data remains `abi.encode(clubId,uint8 x,uint8 y,uint8 rot)` and pieces
retain `{furnitureId,x,y,rot,wall}`. Floor masks, wall lengths, door rules, one
piece per design, 285-piece cap, mint/delegate checks, upgrade prices, 50/50
payment split and metadata URI format are unchanged. Furniture, vault and raffle
sources are untouched. All five retain Ownable2Step. Role bootstrap and subsequent
seven-day delays remain unchanged, including after ownership handoff.

## Imported audit: reproduction and disposition

Before application edits, eight temporary tests were run against the arriving
source with the requested seed; all eight passed and reproduced the described
outcomes. Permanent regression tests now check the corrected behavior. No
reported defect was dismissed as unreproducible.

| Finding | Evidence and disposition |
| --- | --- |
| `60030168d990c31d6f91c373e797b4928c035ff92c2cb949d11dee9f778574e6` (mock manifest / zero notice) | Source inspection confirmed seven Sepolia entries. A stranger minted mock OG and a mock Pepe and successfully bought club 777; an immediate raffle opening succeeded with notice zero. Fixed in the mainnet manifest and handoff. Exact-input Python tests reject regressions; the mainnet rehearsal tests seven-day opening boundaries and deploys no mocks. Historical mocks remain test fixtures only. |
| `5568e45324c84a363c26e551e81366cd9f464bb2718a57a6eebef5699872be27` (club vault sentinels) | Both collision constructors deployed, and a later mint credited 50,000 mock OG to the Pepe/registry address. Fixed with the two requested constructor checks. Both cases now assert `UnexpectedTokenDebit()` in the constructor suites. |
| `ecb46a4e6ccd145536929cbce02ff2ede5b928801cb6c15bda52122bb795c09e` (pending footprint reinterpretation) | A queued floor placement became a side-1 wall placement after an owner edit; changing 2x2 to 4x4 made a queued placement at (8,8) revert `OutOfRoom`. Fixed by immutable definitions and the atomic batch setter. New tests reject the intervening edits and execute the original bytes with unchanged geometry/kind. |
| `701c2c589b48af3b28a21823cf2cf5147101363dae30593651bcbb63129be7d3` (staking vault/token collision) | The constructor accepted its token as vault. Staking and unstaking 1,000 mock OG sent 10 OG to the token contract. The constructor now rejects this configuration; existing fee-flow tests continue to cover normal vault payments. |
| `0250404228816790b04113e06dacf236b902debdf5af44f7d870e6aac0c4b570` (owner trust) | Confirmed from all five implementations and existing role/vault/ownership tests. These are intended powers, not bypasses: furniture minters mint arbitrary IDs/amounts; staking spenders consume points; vault owners choose recipients under the budget/delay; raffle owners define terms; NFT owners set metadata/royalties and clubs' owner defines new footprints/toggles the sale. Preserved, with the requested finality rule and documented ordered setup. New tests exercise all five contract-wallet ownership transfers and unchanged subsequent role delays. |
| `b97b9e8703df9a7db8fd1d4e4f3365c9bc2d4d69dacc0a337f4cbe2b079688fc` (randomness) | Reproduced retarget rejection at target+256 and successful retarget at target+257. Proposer influence is an architectural trust assumption; no validator manipulation experiment was performed. This matches the approved raffle behavior and stays unchanged. README retains the draw-window, censorship/re-roll and independent monitoring discussion. |
| `590e3342b137e7e70e316cc76f5049661beb0d4fa82590ade22d52c7f1782e7d` (prior review coverage) | Informational historical coverage, not a defect. The current work reviewed the supplied checks, five application implementations, affected scripts/manifest/tests and the inherited behavior at each change. The prior auditor's live RPC/source observations are not presented as new verification. Current constructors and behavioral tests run offline. |

## Owner and deployment handoff

The owner is the provided `0x5b95a971b4583a5f011e9da082acdd679b870d06`, encoded as
`$owner` in the manifest. No new deployment address, signer or Safe address is
invented. After deployment the owner grants the raffle both FIRST roles, sets
the two specified URIs, sets the exact catalogue in one transaction, and opens
the sale when announced. Those are separate owner transactions, not factory
initialization. README contains fixed calldata and the exact grant encoding;
the latter needs the service's confirmed raffle address, so local rehearsal
addresses are explicitly not sendable mainnet configuration.

Later, the owner calls `transferOwnership(Safe)` on each of the five applications;
the Safe calls `acceptOwnership()` on each. Verify both `owner` and `pendingOwner`
after acceptance. Royalty receivers remain the original owner unless separately
changed through the existing NFT royalty setters. No role bootstrap resets.

Live mainnet deployment, Etherscan verification and publication of the five
confirmed addresses remain launch-service steps after acceptance. README includes
all five verification commands and exact compiler settings. No live deployment,
explorer success, Slither run, Mythril run or fresh mainnet dependency audit is
claimed here.

## Verification

Run with the unchanged project configuration and the verifier's seed:

```sh
forge build
FOUNDRY_FUZZ_SEED=0x9db4561c3296ebc2311047acd1329ea68f97f45eb4b09ae7deedaf1dbaa06b2e forge test
forge fmt --check
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s test -p 'test_*.py' -v
forge script script/DeployMainnet.s.sol:DeployMainnet --chain-id 1
```

| Check | Final result |
| --- | --- |
| `forge build` | Passed with the existing project configuration; compiler lint warnings are nonfatal. |
| `forge test` with the supplied seed | 273 tests passed across all 42 suites, zero failures/skips; 94.46 seconds wall time. All existing unit, fuzz and invariant suites ran. |
| `forge fmt --check` | Passed. |
| Python manifest/header tests | All 10 passed, including exact mainnet inputs/catalogue and literal README calldata. |
| Mainnet constructor rehearsal | Passed: all five applications deployed in the single-call CREATE2 factory test. The standalone `forge script ... --chain-id 1` rehearsal also completed successfully and printed all setup calls. |
| Output cross-check | Both grant calls independently match `cast calldata` for the rehearsal's actual raffle address; both URI calls, the full batch and sale call exactly match the README bytes. |
| ABI comparison against the delivered artifacts | No removed or modified entries on any application. Only the requested batch setter was added. |
| Runtime comparison against the delivered artifacts | Furniture, FarmVault, Staking and Raffle runtime bytecode is byte-for-byte unchanged. The staking fix affects constructor code only. |
| Manifest/scope | Five entries, scalar inputs matching each constructor ABI, 3,109-character notes. No protected configuration, dependencies or forbidden paths changed. |

Runtime sizes are Furniture 9,044 bytes, FarmVault 4,199, Staking 6,329,
Raffle 9,854 and Clubs 16,089, all below EIP-170. The factory test also checks
init-code limits and reachable forbidden opcodes. The external protected
harness consumes service-provided factory/salt inputs; the permanent local
mainnet rehearsal checks the same constructor/runtime/ownership properties in
one factory call without inventing service inputs. These are local verification
results, not a claim of a completed live launch.
