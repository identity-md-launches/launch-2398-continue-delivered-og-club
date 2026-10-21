# OG Club clubs, staking, furniture and raffles

OG Club awards ERC-1155 furniture through raffles paid with nontransferable points
accrued by staking OG. There are no lootboxes or token-paid furniture purchases.
`OGClubClubs` provides transferable ERC-721 rooms linked one-to-one to Swarm Pepes, bought and expanded with OG. Furniture can be
placed in a room permanently; the on-chain layout and its contents follow the
club when it is sold. This mainnet adaptation continues commit
`20430cbddd7e849fadf64e07f0173eccc8f6f747` of
`identity-md-launches/launch-2382-continue-delivered-og-club`. The application
changes are constructor vault guards, footprints final once set, and an atomic
batch footprint setter. Furniture, farm vault, raffle, all gameplay geometry,
payments and existing ABI entries are preserved. Staking adds only the reproduced
constructor guard against using its token as its vault.
This Foundry project uses the existing Solidity 0.8.26/Cancun configuration and
vendored OpenZeppelin 5.0.2 / forge-std 1.9.7 dependencies ([VENDOR.md](VENDOR.md)).
Builds and tests require no RPC, secrets, FFI, or downloaded dependencies.

## Contracts and configuration

All constructors are nonpayable, use explicit owners, and make no dependency
calls. They can run on an empty chain through the launch factory. Contracts are
immutable implementations, without proxies, upgrades, transfer pauses or owner sweeps.
Ownership uses OpenZeppelin's two-step transfer. Libraries are internal/inlined.

| Contract | Constructor arguments, in order |
| --- | --- |
| `OGClubFurniture` | owner, initial royalty receiver |
| `OGClubFarmVault` | token, owner |
| `OGClubStaking` | token, immutable vault, owner, pointsPerTokenDay |
| `OGClubRaffle` | staking, furniture, owner, immutable raffleNotice |
| `OGClubClubs` | token, vault, price, furniture, owner, royaltyReceiver, pepes, delegates, level2Price, level3Price, level4Price |

`launch.json` deploys exactly these five applications, in this order, on
**Ethereum mainnet, chain ID 1**. Its references point only to earlier applications.
Neither MockOG nor MockSwarmPepe is deployed; their sources remain local/Sepolia
test fixtures. This contracts-only launch creates no token or pool.

| Mainnet input | Exact value |
| --- | --- |
| Existing OG ERC-20 (18 decimals) | `0xce7eb1ad9e2e1c784ea05f7ea4a0fe625923d10a` |
| Existing Swarm Pepes ERC-721 | `0x999ce0CE8C5f7661e0c74a568FfE27CEB9177bDB` |
| delegate.xyz v2 registry | `0x00000000000000447e69651d841bD8D104Bed493` |
| `$owner`, all five owners and both royalty receivers | `0x5b95a971b4583a5f011e9da082acdd679b870d06` |
| Staking pointsPerTokenDay | `1000000000000000000` (one point per whole OG per day) |
| Raffle notice | `604800` seconds (7 days) |
| Club mint price | `100000000000000000000000` (100,000 OG) |
| Level 2 / 3 / 4 price | `200000000000000000000000` / `400000000000000000000000` / `800000000000000000000000` |

Ticket prices are owner-announced point amounts in each pool, not ERC-20
payments. Existing limits remain three blocks for `TARGET_DELAY`, 32 pools and
128 total prize lines per raffle, and 30 days for the maximum constructor notice.

## Owner setup and mainnet handoff

The factory performs constructor deployments only. It leaves raffle roles
ungranted, both base URIs empty, footprints unset and the club sale closed.
After deployment, `$owner` executes these calls **in order**, with **0 ETH**,
using the launch service's confirmed application addresses:

1. Send `furniture.grantMinter(raffle)` and `staking.grantSpender(raffle)` as
   each contract's **FIRST grant**. Verify `minters(raffle)` and `spenders(raffle)`
   are true before creating a raffle. Clubs need neither role.
2. Send `furniture.setBaseURI("https://world.ogclub.online/nft/")` and
   `clubs.setBaseURI("https://world.ogclub.online/club/")`.
3. Send the single `clubs.setFootprints(ids,w,h,wall)` transaction below.
   Check all 24 definitions before submission: a successful definition is final.
4. Send `clubs.setSaleOpen(true)` **when the launch is announced**.

The first grant in each contract is immediate and permanently spends that
contract's bootstrap. Granting another address first makes the raffle wait.
Every later grant, including a re-grant after revocation, is a seven-day proposal.
Anyone may activate in `[proposal + 7 days, proposal + 14 days]`, inclusive.
Re-proposing restarts the delay; cancellation removes a live proposal and
revocation immediately clears permission and any proposal. Ownership transfer
does not reset bootstrap or existing roles.

### Exact owner calldata

`FURNITURE`, `VAULT`, `STAKING`, `RAFFLE` and `CLUBS` below denote the five
**confirmed mainnet addresses**, supplied after deployment. Rehearsal addresses
must never be used for live setup. The grant bytes depend on that confirmed
raffle address: `RAFFLE_WORD` means its 40 hex digits without `0x`, left-padded
with 24 zero hex digits to one 32-byte ABI word. These two expressions are
encoding templates, not sendable bytes until the address is resolved:

| Target | Call | Calldata expression |
| --- | --- | --- |
| Furniture | `grantMinter(raffle)` | `0x261707fa{RAFFLE_WORD}` |
| Staking | `grantSpender(raffle)` | `0x5a4b6198{RAFFLE_WORD}` |

Print the exact grant bytes without signing anything:

```sh
cast calldata "grantMinter(address)" "${RAFFLE:?set the confirmed mainnet raffle address}"
cast calldata "grantSpender(address)" "${RAFFLE:?set the confirmed mainnet raffle address}"
```

To print all targets, exact grant/URI/batch/sale calldata and all constructor
arguments together, use the read-only printer with the confirmed addresses:

```sh
forge script script/DeployMainnet.s.sol:DeployMainnet --chain-id 1 \
  --sig 'printHandoff(address,address,address,address,address)' \
  "${FURNITURE:?confirmed furniture address}" "${VAULT:?confirmed vault address}" \
  "${STAKING:?confirmed staking address}" "${RAFFLE:?confirmed raffle address}" \
  "${CLUBS:?confirmed clubs address}"
```

Send the following furniture URI bytes to **Furniture**:

<!-- calldata:furniture-uri -->
```text
0x55f804b30000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002068747470733a2f2f776f726c642e6f67636c75622e6f6e6c696e652f6e66742f
```

Send the following club URI bytes to **Clubs**:

<!-- calldata:clubs-uri -->
```text
0x55f804b30000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002168747470733a2f2f776f726c642e6f67636c75622e6f6e6c696e652f636c75622f00000000000000000000000000000000000000000000000000000000000000
```

The exact approved `[id,w,h,wall]` catalogue is also in
[`script/club-footprints.json`](script/club-footprints.json). Numeric wall flags
below map to Solidity `false`/`true`:

```json
[[1,1,1,0],[2,1,1,0],[3,2,1,0],[4,1,1,0],[5,2,2,0],[6,1,1,0],[7,1,1,0],[8,1,1,0],[9,1,1,0],[10,1,1,0],[11,1,1,0],[12,2,1,0],[13,1,1,0],[14,1,1,0],[15,1,1,0],[16,1,1,0],[17,1,1,0],[18,2,1,0],[19,1,1,0],[20,2,1,0],[21,1,1,0],[22,1,1,0],[23,2,1,1],[24,1,1,0]]
```

Send this **single 3,332-byte calldata** to **Clubs** for
`setFootprints(uint256[],uint8[],uint8[],bool[])`:

<!-- calldata:footprints -->
```text
0xb16e1514000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000009e00000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001300000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000170000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000
```

The arrays have matching lengths. `BadFootprint()` rejects mismatched lengths,
zero/out-of-range dimensions or a wall height other than 1. `FootprintLocked()`
rejects an already-set ID, including duplicates inside the same batch. Every
failure rolls back the entire batch. An empty owner batch is a no-op.

When the launch is announced, send these `setSaleOpen(true)` bytes to **Clubs**:

<!-- calldata:sale-open -->
```text
0xaf979f250000000000000000000000000000000000000000000000000000000000000001
```

### Later ownership transfer to a Safe

Choose and verify the destination Safe separately; it is not a constructor
input for this launch. For **each of Furniture, FarmVault, Staking, Raffle and
Clubs**, the current owner calls `transferOwnership(Safe)`. The owner remains
unchanged until the **Safe itself** executes `acceptOwnership()` against that
same application. Repeat acceptance for all five, and confirm `owner() == Safe`
and `pendingOwner() == address(0)` on each. The factory has no part in this.

```sh
cast calldata 'transferOwnership(address)' "${SAFE:?set the intended Safe address}"
# The Safe sends this acceptance calldata to EACH of the five applications:
# 0x79ba5097
```

Existing metadata, immutable footprints, role grants and seven-day delays
survive handoff. Royalty receivers are independent of ownership and stay
`$owner`; changing either receiver requires that NFT contract's separate
`setRoyalty(receiver,bps)` owner call. All five retain standard Ownable2Step
transfer, cancellation and renunciation behavior.

## Clubs: minting by Swarm Pepe

Clubs are named **OG Club Clubs**, symbol **OGCLUBS**. Approve exactly `price`
OG units, then call `mintClub(pepeId)`. The caller must own that Swarm Pepe or
be authorized by the current holder through delegate.xyz v2's
`checkDelegateForERC721(caller, holder, pepes, pepeId, bytes32(0))`. Ordinary
ERC-721 transfer approval is not mint authorization. The supplied registry is
`0x00000000000000447e69651d841bD8D104Bed493`; a constructor registry address of
zero explicitly disables delegation. Holder minting does not query the registry.
The registry must be available on the target chain for delegate minting.

The caller pays and receives the club through safe ERC-721 delivery. The club ID
**equals the Pepe ID**, including zero if the collection has that ID; IDs are
not sequential. Each Pepe can mint only once, ever. Selling either NFT does not
reset `clubsMinted(pepeId)`, and the club can subsequently trade independently
of the Pepe. `mintClubTo` and the no-argument mint function have been removed.
The sale starts closed. The owner can close new mints without restricting club
transfers, upgrades or furniture placement. Minting and upgrades are reentrancy
guarded, and neither has a free owner path.

Each mint or upgrade transfers `floor(payment / 2)` directly from the payer to
`0x000000000000000000000000000000000000dEaD`, with the remainder sent directly
to the immutable farm vault. Odd-price dust goes to the vault. This sink transfer
does not reduce the ERC-20's reported supply. Final increases at both recipients
and the payer's total debit must match exactly; any failure rolls back payment,
allowance use and club state. Constructors reject a zero vault, the predicted
club address, the burn sink, the OG token address, the furniture address,
the Pepe collection and a nonzero delegate registry. Staking also rejects a
vault equal to its token. The manifest wires both applications to the newly
constructed farm vault using that same OG token.

Use a standard fixed-balance OG token. Transfer taxes, sender fees, rebasing and
dishonest balance reporting are unsupported. No-return ERC-20s are supported by
SafeERC20. Payments never pass through the club contract. Unsolicited ERC-20
donations remain possible and irrecoverable; the zero-balance invariant covers
protocol operations. Revenue increases the vault's season budget under its
unchanged 50% allocation rule.

## Room levels and placement

Every club starts at level 1, with `(0,0)` the fixed back corner. The four
constant floor masks use bit `y * 16 + x`; every level contains the preceding
floor. Upgrades preserve all existing pieces and occupied tiles.

| Level | Floor | Wall side 0 length | Wall side 1 length | Price to reach level |
| --- | --- | ---: | ---: | ---: |
| 1 | `x < 10, y < 10` | 10 | 10 | Mint: 100,000 OG |
| 2 | `x < 14, y < 10` | 14 | 10 | 200,000 OG |
| 3 | Level 2 plus `x < 10, y < 16` (an L) | 14 | 16 | 400,000 OG |
| 4 | `x < 16, y < 16` | 16 | 16 | 800,000 OG |

These mainnet prices use 18 decimals. Mint price remains an explicit constructor input.
`upgradeClub(clubId)` requires the current club holder, its token-approved account
or an operator approved for all. **The caller pays**, including an approved
operator. Approve `upgradePrice(levelOf(clubId))` before calling. Prices are
immutable and positive. `upgradePrice(4)` returns zero; another upgrade reverts
`MaxLevel`. Level arguments outside 1–4 revert `BadLevel`.

To place furniture, transfer **one** unit of the configured furniture contract:

```solidity
furniture.safeTransferFrom(
    from,
    address(clubs),
    furnitureId,
    1,
    abi.encode(uint256(clubId), uint8(x), uint8(y), uint8(rot))
);
```

First, the owner registers `setFootprint(id, w, h, wall)` or the atomic
`setFootprints(ids,w,h,wall)` batch. Floor dimensions are 1–4; wall width is 1–4
and its height must be 1. Dimensions and the wall flag are **final once set**,
even before placement. Repeating either setter for a defined ID reverts
`FootprintLocked`, including identical values. A pending placement therefore
keeps its original kind and dimensions. The unchanged `footprintOf` view's
`set` flag marks a defined/final footprint; its legacy `locked` flag still
records whether that ID has ever been successfully placed. A failed placement
leaves both flags unchanged.
Catalogue IDs, including zero, are owner-configured. A club may hold **only one
permanent piece of each ID**, floor or wall. `AlreadyHasDesign` rejects a second
copy, including after a club transfer. Other clubs may hold the same design.

For a floor piece, rotations 0–3 are allowed; 1 and 3 swap width and height.
The entire rectangle must lie inside the current level's mask, avoid occupied
floor tiles, and keep `(0,4)` and `(1,4)` free at every level. In particular, a
rectangle anchored in the level-3 L cannot extend into its missing corner.
The contract uses one uint256 floor bitmap per club.

For a wall piece, interpret `rot` as side 0 or 1, `x` as its starting position
along the wall, and require `y == 0`. Side 0 runs along `y = 0` (positions x);
side 1 runs along `x = 0` (positions y). The width must fit the side's current
length and must not overlap another piece on that side. **Side 1 position 4 is
the door**: width 2 starting at 3 or 4 fails, starting at 5 fits. Each side has
its own uint32 occupancy bitmap; floor and both walls are independent. A fully
expanded club can reach `MAX_PIECES = 285`: 254 distinct one-tile floor designs,
16 one-wide designs on side 0, and 15 on side 1. A further fresh design reverts
`ClubFull`. The test reaches this cap through real transfers without storage cheats.

Placement authenticates the ERC-1155 **`from` address** as club holder or an
approved club account, and separately relies on normal furniture transfer
approval. A furniture operator can therefore permanently place its principal's
pieces into that principal's club without a separate club approval. A club
approval does not authorize spending someone else's furniture. These approvals
grant permanent-placement power and should be given accordingly.

Only the immutable furniture contract can call the single-item hook. Data must
be exactly four canonical ABI words; wrong lengths or uint8 words over 255
revert `BadPlacementData`. Bad geometry/rotation uses `OutOfRoom`, door coverage
uses `BlocksDoor`, and occupied floor or wall space uses `TileTaken`. The batch
hook rejects all calls. The unchanged OpenZeppelin 5.0.2 ERC-1155 routes a
one-element batch through the single-item hook, so it accepts one valid placement;
empty and multi-element batches revert. Minting furniture directly into clubs
fails. Furniture never leaves club custody: no removal, relocation, withdrawal,
ERC-1155 approval or privileged seizure path exists.

## Rendering, metadata and owner powers

`ClubMinted(id, to, payer, burned, toVault, pepeId)` records the initial recipient
before safe delivery can trigger a receiver's onward transfer or placement.
`ClubUpgraded(clubId, newLevel, payer, burned, toVault)` and
`FurniturePlaced(clubId, furnitureId, x, y, rot, index, wall)` are followed by
ERC-4906 `MetadataUpdate(clubId)`. Placement indices start at zero.

| View | Result |
| --- | --- |
| `clubsMinted(pepeId)` | Whether this Pepe has ever minted a club |
| `levelOf(clubId)`, `floorMask(level)`, `upgradePrice(currentLevel)` | Level, geometry and next price |
| `piecesOf(clubId)` | Ordered `Piece { furnitureId, x, y, rot, wall }[]` |
| `pieceCount(clubId)`, `hasDesign(clubId, id)` | Piece count and design membership |
| `tileTaken(clubId, x, y)` | Floor occupancy; reserved door tiles return false |
| `wallTaken(clubId, side, position)` | Wall occupancy; side-1 door position returns false |
| `footprintOf(id)` | `(uint8 w, uint8 h, bool set, bool locked, bool wall)` |
| `tokenByIndex`, `tokenOfOwnerByIndex`, `totalSupply` | ERC-721 enumeration, including sparse IDs |
| `token`, `vault`, `price`, `furniture`, `pepes`, `delegates`, `saleOpen` | Payment, dependency and sale configuration |

Club layout views reject missing clubs with `NonexistentToken`; occupancy views
reject coordinates outside the current floor or wall. Transfers preserve level,
layout and design membership, clear token approvals and change who can place or
upgrade. Pepe ownership is only checked at mint; subsequent club rights depend
on the club NFT.

The owner can set the metadata prefix until `freezeMetadata()`. `tokenURI(id)`
is `baseURI + decimal id + ".json"`, initially e.g. `1.json`. Prefix changes and
freezing emit `BatchMetadataUpdate(0, uint256.max)` to include Pepe ID zero.
Freezing survives ownership transfers and freezes the **URI prefix**, not
layouts, levels, new footprint definitions or content hosted at a mutable URL. Royalties
start at 500 bps (5%); the owner may set a nonzero receiver and 0–1000 bps.
Marketplace enforcement is external. Ownable2Step retains its standard transfer,
cancellation and renunciation behavior. Ownership gives no free club, transfer
privilege, furniture withdrawal or payment sweep.

## Constructor rehearsal and deployment verification

Run the five-application rehearsal on an empty local EVM with mainnet chain ID:

```sh
forge script script/DeployMainnet.s.sol:DeployMainnet --chain-id 1
```

It uses exactly the mainnet inputs above, deploys no mock, performs only the five
constructors, and prints constructor arguments and all owner setup calldata.
It reads no keys, performs no broadcast and makes no calls to live dependencies.
The printed addresses are **local simulation addresses only**. The separate
`MainnetDeploymentTest` deploys all five through CREATE2 in one factory call,
checks owners/dependencies/runtime limits/opcodes, executes the printed owner
calls, and exercises two-step handoff to a contract wallet on all five.

The club constructor retains eleven scalar inputs; the other constructors use
2, 2, 4 and 4 inputs respectively. All are nonpayable, within the factory's
16-argument bound, and require no dependency code during construction. Owner
setup is separate from constructor deployment.

`script/Deploy.s.sol` and `script/DeployClubs.s.sol` retain the historical
four-contract and standalone club helpers and their local/Sepolia tests.
`DeployClubsMainnet` is a legacy standalone helper, not this launch's entry
point. Its owner footprint output now uses one batch. The approved launch uses
`launch.json`; its offline rehearsal and full handoff use `DeployMainnet`.
The supplied footprint JSON is the **approved mainnet catalogue**, not sample
geometry.

The launch service performs live deployment and Etherscan verification after
acceptance. No live transactions, confirmed deployment addresses or explorer
verification results are claimed by this repository adaptation. After deployment,
use the five confirmed addresses and the exact constructor arguments printed
by `printHandoff` to verify **each** source. The following are deployer-side
verification commands (with the service's explorer authorization configured):

```sh
forge verify-contract --chain 1 "$FURNITURE" src/OGClubFurniture.sol:OGClubFurniture \
  --constructor-args "$(cast abi-encode 'constructor(address,address)' "$OWNER" "$OWNER")" --watch
forge verify-contract --chain 1 "$VAULT" src/OGClubFarmVault.sol:OGClubFarmVault \
  --constructor-args "$(cast abi-encode 'constructor(address,address)' "$OG_TOKEN" "$OWNER")" --watch
forge verify-contract --chain 1 "$STAKING" src/OGClubStaking.sol:OGClubStaking \
  --constructor-args "$(cast abi-encode 'constructor(address,address,address,uint256)' "$OG_TOKEN" "$VAULT" "$OWNER" 1000000000000000000)" --watch
forge verify-contract --chain 1 "$RAFFLE" src/OGClubRaffle.sol:OGClubRaffle \
  --constructor-args "$(cast abi-encode 'constructor(address,address,address,uint256)' "$STAKING" "$FURNITURE" "$OWNER" 604800)" --watch
forge verify-contract --chain 1 "$CLUBS" src/OGClubClubs.sol:OGClubClubs \
  --constructor-args "$(cast abi-encode 'constructor(address,address,uint256,address,address,address,address,address,uint256,uint256,uint256)' "$OG_TOKEN" "$VAULT" 100000000000000000000000 "$FURNITURE" "$OWNER" "$OWNER" "$SWARM_PEPES" "$DELEGATE_REGISTRY" 200000000000000000000000 400000000000000000000000 800000000000000000000000)" --watch
```

Use the exact OG/Pepe/registry/owner values in the table above. Verification
uses the unchanged project compiler settings: Solidity 0.8.26, optimizer 200,
Cancun EVM and `bytecode_hash = "none"`. Publish the five verified addresses
from the service's confirmed receipt, then carry out the owner setup in order.

## Staking and points

Approve the staking contract, then call `stake(amount)`. The stake credited is
its actual token balance increase, so a fee deducted from a deposit cannot mint
extra stake or points. `unstake(amount)` is available immediately, including in
the same block as a stake. The immutable vault receives
`ceil(amount * 100 / 10000)` token units and the remaining units go to the staker.
A one-unit withdrawal pays one unit in fees; splitting withdrawals cannot avoid
fees. No points are awarded on unstaked balances.

For a balance held over `seconds`, accrual in point-wei is:

```text
balanceInTokenUnits * pointsPerTokenDay * seconds / (10**tokenDecimals * 86400)
```

`pointsOf(account)` includes pending accrual. Balances are checkpointed before
stake changes and point spending. Division remainders persist, including through
a full exit, so many small checkpoints have exactly the same result as one large
checkpoint. `spendPoints(account, amount)` is available only to authorized
spenders, and never makes an external token transfer. Points have no transfer,
approval, mint, or admin-adjustment function. Zero-point spends are harmless
checkpoints that retain fractions.

Each account occupies **two slots**: `uint128 balance`, `uint48 updatedAt` and
`uint80 remainder` packed together, plus `uint256 points`. The per-account stake
limit is `2**128 - 1` token units; the maximum rate is `2**96 - 1` point units per
token-day. Checked casts and full-precision multiplication prevent truncation and
intermediate overflow. The timestamp range extends to `2**48 - 1` seconds.

Token decimals (0–18, including OG/MockOG's 18) are read and fixed on the first
stake, not in the constructor. This supports ordinary fixed-balance ERC-20s with
stable metadata, including tokens returning no transfer boolean and fees deducted
from the transferred amount. Outbound transfers must debit exactly the requested
amount; extra sender-side fees revert atomically. Recipients of a taxed token
receive less after that token's own fee. Rebasing/reflection tokens and dishonest
balance reporting are unsupported. Unsolicited transfers to staking are surplus,
not stake or points, and cannot be swept. The balance-equals-total-staked invariant
applies to stake/unstake flows without unsolicited donations or rebases.

## Raffles, winning tickets and claims

The owner calls `createRaffle(opensAt, closesAt, pools)` with a nonempty pool list.
Opening must be at least `now + raffleNotice`; closing must be later. Each pool
has a display-only `uint8 tier`, positive point ticket price, a per-wallet ticket
cap (zero means unlimited), and one or more `{itemId, quantity}` prizes with
positive quantities. Item ID zero and repeated item IDs are supported. Caps are
per wallet **per pool per raffle**, not identity-based or Sybil resistant.
Quantities and total sold tickets per pool are at most `2**48 - 1`.

The terms and prize list cannot be edited. The owner can cancel only **before**
opening, when entry has not yet been possible. `enter(raffleId, poolId, tickets)`
works during `[opensAt, closesAt)`, spends `tickets * ticketPrice`, and appends an
entry for the sender. It records the contiguous half-open range `[first, end)` in
one storage slot, regardless of the ticket count. Ticket indices, pool indices,
entry indices and win indices start at zero; raffle IDs start at one. Tickets
cannot be transferred. Failed spending rolls back the range and cap update.

At or after closing, anyone calls `commitDraw(raffleId)` to target the block
**three blocks ahead**. Anyone may then call `draw(raffleId, header)` when
`target < block.number <= target + 256`. The entire canonical RLP header must
hash to `blockhash(target)`, and its decoded block number must equal the target.
Its `prevRandao` is stored as the seed, even when zero. Drawing never mints or
iterates over pools, tickets or entrants. After drawing the seed cannot change.

Let `W = min(prizes, ticketsSold)` for a pool. The valid wins are exactly
`k = 0 ... W-1`. `winningTicket(raffleId, pool, k)` evaluates an eight-round
Keccak Feistel permutation with cycle walking over ticket indices. `prizeOf`
evaluates a **separate, domain-separated permutation** over the expanded prize
positions and locates its item by binary search of cumulative quantities.
Thus each ticket wins at most once, wallets may win multiple times, and a pool
with enough tickets awards every listed quantity exactly. With fewer tickets,
the unused prize positions are random too; they are never minted.

Both permutations also bind the seed to the chain, raffle contract, raffle ID
and pool. Cycle walking uses the next power-of-four domain (less than four times
the requested size). It is an invertible pseudorandom selection without modulo
bias or a table of entrants. Walk length depends on the seed; it has a short
expected cost, not a fixed worst-case gas bound.

Anyone calls `claim(raffleId, pool, wins)`, where each win is `{k, entry}` and the
supplied entry must contain `winningTicket(k)`. It pays the entry wallet, never
the caller. Claimed win indices are recorded in a bitmap. Adjacent claims for
the same wallet share one `furniture.mintBatch`; grouping by wallet saves gas.
The on-chain work grows with the **wins submitted**, independently of entrant
and ticket counts (prize lookup is bounded by 128 lines). Read `Entered` events
or `getEntry` to locate ticket ranges off chain.

`claimTo(raffleId, pool, wins, to)` requires the caller to be the wallet of **every**
supplied entry and a nonzero recipient. It lets contract wallets redirect prizes.
Receiver or mint-permission failures roll back that transaction's claims and
mints; they remain retryable with the same results indefinitely. Submit subsets
to isolate a rejecting recipient. Claims are guarded against receiver reentrancy.

### Randomness and owner trust

This is the requested on-chain future-block randomness, not an external VRF.
Validators can influence/censor the target block and its prevRandao, and callers
can choose when to commit after closing. If **nobody draws** by target + 256,
anyone can re-commit beginning at target + 257, choosing a new future target.
An operator who withholds unfavorable draws, especially with censorship or no
independent keeper, can obtain another seed and bias results. Permissionless
drawing lets an independent party preserve an available outcome; it does not
eliminate these biases. Operators must monitor closed raffles and retrieve
headers inside the blockhash window. A finalized draw cannot be retargeted.

Owners cannot directly change stakes, point balances or drawn outcomes. They do
control spender authorization; an authorized spender can consume any account's
points, so later grants need scrutiny during their notice window. Furniture
minters can mint arbitrary IDs/quantities outside raffles. Revoking the raffle's
roles stops new point spending or prize delivery until reinstated, although
staking exits remain available and drawn claims retain their results. Prize
quantities are per pool, not global collection scarcity limits.

Furniture retains its original supply tracking, ERC-1155 transfers, metadata URI
format, permanent metadata freeze, and ERC-2981 royalties: initially 5%, owner
adjustable up to 10%. Its owner has no confiscation, privileged transfer or burn
right. Royalties are informational; marketplace enforcement is external.

## Farming vault

Unstake fees accumulate in `OGClubFarmVault`. The owner publishes a farming
allocation with `proposeSeason(root, total)`. Total must be positive and at most
`floor((tokenBalance - reserved) / 2)`. It is reserved immediately, claims open
three days later, and the next proposal must wait at least seven days after the
previous proposal even if that proposal was canceled.

Use sorted-pair OpenZeppelin Merkle trees (compatible with StandardMerkleTree)
and exactly this double-hashed leaf, with the types shown:

```solidity
keccak256(bytes.concat(keccak256(abi.encode(
    uint256(seasonId), address(account), uint256(amount)
))))
```

Season IDs begin at one; generate allocations for the correct ID. Include each
account once per season, since the contract pays only one allocation per account.
Keep the sum of allocations equal to `total`; a root alone cannot prove that sum,
and the contract refuses claims above the remaining season budget. Anyone may
submit `claim(seasonId, account, amount, proof)`, which pays only that account.
There is no relayer redirect. Zero allocations are valid but unnecessary.

`cancelSeason` is owner-only and works strictly before claims open. Claims are
valid during `[opensAt, opensAt + 90 days)`. At exactly `opensAt + 90 days`, claims
stop and the owner may call `releaseSeason` to unreserve the unpaid balance.
Cancellation and release **never transfer tokens**; the released funds become
eligible for later seasons. The owner has no other token-moving function.
The owner chooses recipients/root/total and could include itself in a valid
season: this remains a trust assumption subject to the budget and time limits.

## Header encoder and offline fixtures

`script/encode_header.py` takes an `eth_getBlockByNumber` JSON object or response
wrapper from a file or stdin. It encodes fields after `requestsHash` in the order
**blockAccessListHash, slotNumber** (slotNumber is an integer). It refuses gaps
and all unknown keys except explicitly allowlisted non-header RPC metadata.

```sh
python3 script/encode_header.py test/fixtures/sepolia-11921684.json
```

Sepolia block **11921684** has published hash
`0x0beea75b48cae0d6c13bf5a289c3f64ea9e4473bfacd2f9709d5c0a827e73629`.
The JSON and embedded RLP are checked both against that hash and through raffle
`draw`. Existing real Shanghai, Cancun and Prague fixtures remain tested. See
[test/fixtures/SOURCES.md](test/fixtures/SOURCES.md) for provenance. Always compare
`cast keccak` of the encoded header with the published hash before submitting it.

## Gas and EIP-8037

The project still targets Cancun. These are isolated-call measurements, followed
by a **storage-cost projection**, not a claim to execute the future fork.
[EIP-8037](https://eips.ethereum.org/EIPS/eip-8037) specifies 64 state bytes per
new storage slot and CPSB 1530: **97,920 state gas per fresh slot**, replacing
20,000 Cancun gas. The projected total adds **77,920 per durable fresh slot**
across all callees. Companion EIPs, transaction intrinsic/calldata gas and
refunds are not modeled; these are gross call costs, not receipt or gas-limit
estimates. ERC-20 transfers and ERC-1155 receiver behavior can change costs.

| Operation | Measured Cancun call gas | Fresh slots | EIP-8037 state gas | Storage-repriced call gas |
| --- | ---: | ---: | ---: | ---: |
| First-ever stake, fresh staker | 120,547 | 3 | 293,760 | 354,307 |
| Partial unstake, first checkpoint and first vault fee | 110,662 | 2 | 195,840 | 266,502 |
| First entry, 10 tickets, first point checkpoint | 155,364 | 4 | 391,680 | 467,044 |
| Draw, 23-field header | 74,312 | 1 | 97,920 | 152,232 |
| Claim 1 win to a fresh furniture wallet | 160,885 | 4 | 391,680 | 472,565 |
| Claim 10 distinct items to a fresh furniture wallet | 816,170 | 22 | 2,154,240 | 2,530,410 |

Measured with MockOG, 1e18 accrual, preapproved spending, and freshly granted
roles. Claim rows start with zero collection supply, mint to one EOA, and set the
first claim bitmap word. The ten-win pool has ten different IDs, so it creates
ten recipient balances and ten per-ID supply slots; repeated IDs cost less.
Draw uses the deterministic synthetic header in the gas test; real header sizes
change decoding costs. Permutation costs vary with the seed and domain sizes.
The two-slot staking account, one-slot entry and claim bitmap limit new state.
Reproduce both measurements and the asserted new-slot counts:

```sh
forge test --match-contract GasTest --isolate -vv
```

## Local checks

```sh
forge build
FOUNDRY_FUZZ_SEED=0x9db4561c3296ebc2311047acd1329ea68f97f45eb4b09ae7deedaf1dbaa06b2e forge test
forge fmt --check
forge script script/DeployMainnet.s.sol:DeployMainnet --chain-id 1
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s test -p 'test_*.py' -v
```

Tests cover accrual fractions and packed bounds, taxed/nonstandard tokens,
reentrancy, spender/minter lapse, raffle time/cap/header boundaries, retargeting,
permutation bijections, exact prize quantities, wrong entries and duplicate
claims, contract-wallet redirection, vault proofs and reserve deadlines. Stateful
invariants check stakes against token custody, independently integrated accrual
minus spending, and vault balances against all remaining reservations. The
retained furniture suite checks supply, transfer authorization, royalties and
frozen metadata. [ADAPTATION.md](ADAPTATION.md) records the changes and audit
reproductions.

Club tests cover exact payment splitting and rollback, safe receivers,
reentrancy, real furniture integration, all rotations, authorization, permanent
custody, metadata, royalties and script/factory deployment. Fuzz tests compare
random levels, floor/wall placements, footprints, rotations and duplicate designs
against an independent cell grid. Stateful club
invariants exercise Pepe ownership/delegation, minting, upgrades, rejected
placements, approvals, sale changes and both NFT transfers,
checking payment conservation, zero protocol OG custody, and an exact match
between per-ID furniture holdings and all clubs' ordered layouts.
