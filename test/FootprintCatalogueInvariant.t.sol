// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OGClubClubs} from "src/OGClubClubs.sol";
import {OGClubFurniture} from "src/OGClubFurniture.sol";
import {OGClubFarmVault} from "src/OGClubFarmVault.sol";
import {IDelegateRegistry} from "src/interfaces/IDelegateRegistry.sol";
import {MockOG} from "src/mocks/MockOG.sol";
import {MockSwarmPepe} from "src/mocks/MockSwarmPepe.sol";
import {LaunchLayoutModel as Model} from "./helpers/LaunchLayoutModel.sol";

/// @dev Definitions come from successful inputs, never footprintOf. Queued payloads are saved
/// in one handler call and submitted in a later call, across arbitrary intervening admin actions.
contract FootprintCatalogueHandler is Test {
    struct Definition {
        uint8 w;
        uint8 h;
        bool wall;
        bool set;
    }

    struct Pending {
        bytes data;
        uint8 design;
        uint8 sender;
        Model.Placement placement;
        bool exists;
    }

    struct Batch {
        uint256[] ids;
        uint8[] w;
        uint8[] h;
        bool[] wall;
    }

    OGClubClubs public immutable clubs;
    OGClubFurniture public immutable furniture;
    address[3] public admins;
    address[3] public players;
    address public expectedOwner;
    address public expectedPendingOwner;
    address[3] public holders;
    uint8[3] public levels;
    Definition[32] private definitions;
    Model.Board[3] private boards;
    Pending[3] private pending;
    mapping(uint256 => OGClubClubs.Piece[]) private pieces;
    uint256[32][3] private sent;
    uint256 public successfulBatches;
    uint256 public rejectedBatches;
    uint256 public placedFloor;
    uint256 public placedWall;
    uint256 public rejectedPlacements;
    uint256 public acceptedHandoffs;

    constructor(OGClubClubs c, OGClubFurniture f, address[3] memory a, address[3] memory p) {
        clubs = c;
        furniture = f;
        admins = a;
        players = p;
        holders = p;
        expectedOwner = a[0];
        levels = [uint8(1), 1, 1];
    }

    // Include both endpoints of the full uint256 id domain in the random sequence.
    function itemId(uint256 index) public pure returns (uint256) {
        if (index == 0) return 0;
        if (index == 31) return type(uint256).max;
        return 100 + index;
    }

    function defineOne(uint8 rawItem, uint8 rawW, uint8 rawH, bool wall, bool authorized) public {
        uint8 index = rawItem % 32;
        uint8 w = uint8(bound(rawW, 1, 4));
        uint8 h = wall ? 1 : uint8(bound(rawH, 1, 4));
        address caller = authorized ? expectedOwner : _otherAdmin();
        bytes memory error = caller != expectedOwner
            ? abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
            : definitions[index].set ? abi.encodeWithSelector(OGClubClubs.FootprintLocked.selector) : bytes("");
        vm.prank(caller);
        (bool ok, bytes memory result) =
            address(clubs).call(abi.encodeCall(clubs.setFootprint, (itemId(index), w, h, wall)));
        _checkResult(ok, result, error);
        if (ok) definitions[index] = Definition(w, h, wall, true);
    }

    /// @dev Modes cover fresh entries, a duplicate, invalid geometry, an existing id,
    /// mismatched lengths, and an unauthorized caller. The error may occur at any index.
    function defineBatch(bytes32 seed, uint8 rawLength, uint8 rawMode, uint8 rawBadIndex) public {
        uint256 n = bound(rawLength, 1, 8);
        uint8[] memory indexes = new uint8[](n);
        uint256 used;
        for (uint256 i; i < 32 && used < n; ++i) {
            uint8 index = uint8((uint256(seed) % 32 + i) % 32);
            if (!definitions[index].set) indexes[used++] = index;
        }
        // Once the catalogue is full, attempts still exercise definition immutability.
        if (used == 0) indexes[used++] = uint8(uint256(seed) % 32);
        n = used;
        Batch memory b = Batch(new uint256[](n), new uint8[](n), new uint8[](n), new bool[](n));
        for (uint256 i; i < n; ++i) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            b.ids[i] = itemId(indexes[i]);
            b.w[i] = uint8(1 + r % 4);
            b.wall[i] = (r >> 8) % 2 == 1;
            b.h[i] = b.wall[i] ? 1 : uint8(1 + (r >> 16) % 4);
        }
        uint256 badIndex = rawBadIndex % n;
        uint8 mode = rawMode % 6;
        if (mode == 1 && n > 1) {
            uint256 other = (badIndex + 1) % n;
            b.ids[badIndex] = b.ids[other];
            indexes[badIndex] = indexes[other];
        } else if (mode == 2) {
            b.w[badIndex] = 0;
        } else if (mode == 3) {
            for (uint8 i; i < 32; ++i) {
                if (definitions[i].set) {
                    b.ids[badIndex] = itemId(i);
                    indexes[badIndex] = i;
                    break;
                }
            }
        } else if (mode == 4) {
            b.h = new uint8[](n + 1);
        }
        address caller = mode == 5 ? _otherAdmin() : expectedOwner;
        bytes memory error = _batchError(b, indexes, caller);
        vm.prank(caller);
        (bool ok, bytes memory result) =
            address(clubs).call(abi.encodeCall(clubs.setFootprints, (b.ids, b.w, b.h, b.wall)));
        _checkResult(ok, result, error);
        if (!ok) {
            ++rejectedBatches;
            return;
        }
        ++successfulBatches;
        for (uint256 i; i < n; ++i) {
            definitions[indexes[i]] = Definition(b.w[i], b.h[i], b.wall[i], true);
        }
    }

    function _batchError(Batch memory b, uint8[] memory indexes, address caller) private view returns (bytes memory) {
        if (caller != expectedOwner) {
            return abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller);
        }
        if (b.ids.length != b.h.length) return abi.encodeWithSelector(OGClubClubs.BadFootprint.selector);
        for (uint256 i; i < b.ids.length; ++i) {
            if (definitions[indexes[i]].set) return abi.encodeWithSelector(OGClubClubs.FootprintLocked.selector);
            for (uint256 j; j < i; ++j) {
                if (b.ids[i] == b.ids[j]) return abi.encodeWithSelector(OGClubClubs.FootprintLocked.selector);
            }
            if (b.w[i] == 0) return abi.encodeWithSelector(OGClubClubs.BadFootprint.selector);
        }
        return bytes("");
    }

    function queue(uint8 rawClub, uint8 rawItem, uint8 rawX, uint8 rawY, uint8 rawRot) public {
        uint8 club = rawClub % 3;
        uint8 index = rawItem % 32;
        Definition memory d = definitions[index];
        if (!d.set) return;
        uint8 sender;
        while (players[sender] != holders[club]) ++sender;
        Model.Placement memory p = Model.Placement(
            d.w,
            d.h,
            d.wall,
            uint8(bound(rawX, 0, 16)),
            d.wall ? 0 : uint8(bound(rawY, 0, 16)),
            uint8(rawRot % (d.wall ? 2 : 4)),
            index
        );
        pending[club] = Pending(abi.encode(uint256(club + 1), p.x, p.y, p.rot), index, sender, p, true);
    }

    function execute(uint8 rawClub) public {
        uint8 club = rawClub % 3;
        Pending memory q = pending[club];
        if (!q.exists) return;
        address sender = players[q.sender];
        bool authorized = holders[club] == sender;
        bool expected = authorized && Model.valid(boards[club], levels[club], q.placement);
        vm.prank(sender);
        (bool ok, bytes memory result) = address(furniture)
            .call(abi.encodeCall(furniture.safeTransferFrom, (sender, address(clubs), itemId(q.design), 1, q.data)));
        assertEq(ok, expected, "queued placement disagrees with original dimensions/kind");
        if (!ok) {
            ++rejectedPlacements;
            if (!authorized) {
                assertEq(result, abi.encodeWithSelector(OGClubClubs.NotClubOwner.selector));
            } else if (boards[club].designs[q.design]) {
                assertEq(result, abi.encodeWithSelector(OGClubClubs.AlreadyHasDesign.selector));
            } else {
                assertTrue(
                    keccak256(result) == keccak256(abi.encodeWithSelector(OGClubClubs.OutOfRoom.selector))
                        || keccak256(result) == keccak256(abi.encodeWithSelector(OGClubClubs.BlocksDoor.selector))
                        || keccak256(result) == keccak256(abi.encodeWithSelector(OGClubClubs.TileTaken.selector)),
                    "unexpected placement error"
                );
            }
        } else {
            boards[club] = Model.occupy(boards[club], q.placement);
            pieces[club].push(
                OGClubClubs.Piece(itemId(q.design), q.placement.x, q.placement.y, q.placement.rot, q.placement.wall)
            );
            ++sent[q.sender][q.design];
            if (q.placement.wall) ++placedWall;
            else ++placedFloor;
        }
        // Also check rejected transfers: they cannot leave partially occupied cells.
        _assertBoard(club);
    }

    function transferClub(uint8 rawClub, uint8 rawTo) public {
        uint8 club = rawClub % 3;
        address to = players[rawTo % 3];
        vm.prank(holders[club]);
        clubs.transferFrom(holders[club], to, club + 1);
        holders[club] = to;
    }

    function upgrade(uint8 rawClub) public {
        uint8 club = rawClub % 3;
        vm.prank(holders[club]);
        if (levels[club] == 4) {
            vm.expectRevert(OGClubClubs.MaxLevel.selector);
            clubs.upgradeClub(club + 1);
        } else {
            clubs.upgradeClub(club + 1);
            ++levels[club];
        }
    }

    function nominate(uint8 rawTo, bool authorized, bool cancel) public {
        address to = cancel ? address(0) : admins[rawTo % 3];
        address caller = authorized ? expectedOwner : _otherAdmin();
        vm.prank(caller);
        (bool ok, bytes memory result) = address(clubs).call(abi.encodeCall(clubs.transferOwnership, (to)));
        _checkResult(
            ok,
            result,
            authorized ? bytes("") : abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        if (ok) expectedPendingOwner = to;
    }

    function accept(uint8 rawCaller) public {
        address caller = admins[rawCaller % 3];
        bool expected = expectedPendingOwner == caller;
        vm.prank(caller);
        (bool ok, bytes memory result) = address(clubs).call(abi.encodeCall(clubs.acceptOwnership, ()));
        _checkResult(
            ok,
            result,
            expected ? bytes("") : abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        if (ok) {
            expectedOwner = caller;
            expectedPendingOwner = address(0);
            ++acceptedHandoffs;
        }
    }

    function _otherAdmin() private view returns (address) {
        return admins[0] == expectedOwner ? admins[1] : admins[0];
    }

    function _checkResult(bool ok, bytes memory result, bytes memory error) private pure {
        assertEq(ok, error.length == 0, "unexpected action result");
        if (!ok) assertEq(result, error, "wrong custom error");
    }

    function assertCatalogue() external view {
        assertEq(clubs.owner(), expectedOwner);
        assertEq(clubs.pendingOwner(), expectedPendingOwner);
        for (uint256 i; i < 32; ++i) {
            Definition memory d = definitions[i];
            (uint8 w, uint8 h, bool set, bool locked, bool wall) = clubs.footprintOf(itemId(i));
            assertEq(w, d.w, "width changed or failed batch leaked");
            assertEq(h, d.h, "height changed or failed batch leaked");
            assertEq(wall, d.wall, "kind changed");
            assertEq(set, d.set, "definition existence differs");
            assertEq(locked, boards[0].designs[i] || boards[1].designs[i] || boards[2].designs[i], "legacy placed flag");
        }
        for (uint256 c; c < 3; ++c) {
            Pending memory q = pending[c];
            if (!q.exists) continue;
            Definition memory d = definitions[q.design];
            assertEq(q.placement.w, d.w);
            assertEq(q.placement.h, d.h);
            assertEq(q.placement.wall, d.wall);
            assertEq(q.data, abi.encode(c + 1, q.placement.x, q.placement.y, q.placement.rot));
        }
    }

    function assertCustody() external view {
        for (uint256 c; c < 3; ++c) {
            assertEq(clubs.ownerOf(c + 1), holders[c]);
            assertEq(clubs.levelOf(c + 1), levels[c]);
            assertEq(abi.encode(clubs.piecesOf(c + 1)), abi.encode(pieces[c]), "permanent layout changed");
        }
        uint256 allHeld;
        for (uint256 i; i < 32; ++i) {
            uint256 recorded;
            uint256 debited;
            for (uint256 c; c < 3; ++c) {
                if (boards[c].designs[i]) ++recorded;
                assertEq(clubs.hasDesign(c + 1, itemId(i)), boards[c].designs[i]);
                assertEq(furniture.balanceOf(players[c], itemId(i)), 8 - sent[c][i]);
                debited += sent[c][i];
            }
            assertEq(recorded, debited, "custody must debit exactly one player per entry");
            assertEq(furniture.balanceOf(address(clubs), itemId(i)), recorded);
            assertEq(furniture.totalSupply(itemId(i)), 24);
            allHeld += recorded;
        }
        assertEq(allHeld, placedFloor + placedWall);
        assertEq(clubs.totalSupply(), 3);
        assertEq(furniture.totalSupply(), 32 * 24);
    }

    function assertAllBoards() external view {
        for (uint8 c; c < 3; ++c) {
            _assertBoard(c);
        }
    }

    function _assertBoard(uint8 c) private view {
        for (uint8 y; y < 16; ++y) {
            for (uint8 x; x < 16; ++x) {
                if (Model.inside(levels[c], x, y)) {
                    assertEq(clubs.tileTaken(c + 1, x, y), boards[c].floor[uint256(y) * 16 + x]);
                }
            }
        }
        for (uint8 side; side < 2; ++side) {
            for (uint8 x; x < Model.length(levels[c], side); ++x) {
                assertEq(clubs.wallTaken(c + 1, side, x), boards[c].walls[uint256(side) * 16 + x]);
            }
        }
    }
}

/// forge-config: default.invariant.runs = 128
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract FootprintCatalogueInvariantTest is Test {
    FootprintCatalogueHandler internal handler;

    function setUp() public {
        // Existing external-dependency fixtures only; no fork or mainnet deployment.
        MockOG token = new MockOG(address(this));
        MockSwarmPepe pepes = new MockSwarmPepe();
        address[3] memory admins =
            [makeAddr("catalogue owner"), makeAddr("catalogue successor"), makeAddr("catalogue third")];
        address[3] memory players =
            [makeAddr("catalogue alice"), makeAddr("catalogue bob"), makeAddr("catalogue carol")];
        OGClubFurniture furniture = new OGClubFurniture(address(this), admins[0]);
        OGClubFarmVault vault = new OGClubFarmVault(token, admins[0]);
        OGClubClubs clubs = new OGClubClubs(
            token,
            address(vault),
            100_000e18,
            IERC1155(address(furniture)),
            admins[0],
            admins[0],
            pepes,
            IDelegateRegistry(address(0)),
            200_000e18,
            400_000e18,
            800_000e18
        );
        handler = new FootprintCatalogueHandler(clubs, furniture, admins, players);
        furniture.grantMinter(address(this));
        vm.prank(admins[0]);
        clubs.setSaleOpen(true);
        uint256[] memory ids = new uint256[](32);
        uint256[] memory amounts = new uint256[](32);
        for (uint256 i; i < 32; ++i) {
            ids[i] = handler.itemId(i);
            amounts[i] = 8;
        }
        for (uint256 i; i < 3; ++i) {
            token.mint(players[i], 10_000_000e18);
            pepes.mint(players[i], i + 1);
            vm.startPrank(players[i]);
            token.approve(address(clubs), type(uint256).max);
            clubs.mintClub(i + 1);
            vm.stopPrank();
            furniture.mintBatch(players[i], ids, amounts);
        }

        // Guarantee real custody, both kinds, a pending operation across handoff, and
        // a batch success/failure before fuzzing. Every subsequent action is randomized.
        handler.defineOne(0, 2, 1, false, true);
        handler.defineOne(31, 2, 1, true, true);
        handler.queue(0, 0, 3, 0, 1);
        handler.nominate(1, true, false);
        handler.accept(1);
        handler.defineOne(0, 4, 4, true, true);
        handler.execute(0);
        handler.queue(1, 31, 8, 0, 1);
        handler.execute(1);
        handler.defineBatch(bytes32(uint256(4)), 4, 0, 0);
        handler.defineBatch(bytes32(uint256(12)), 4, 2, 3);

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.defineOne.selector;
        selectors[1] = handler.defineBatch.selector;
        selectors[2] = handler.queue.selector;
        selectors[3] = handler.execute.selector;
        selectors[4] = handler.transferClub.selector;
        selectors[5] = handler.upgrade.selector;
        selectors[6] = handler.nominate.selector;
        selectors[7] = handler.accept.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_DefinitionsAreFinalAndBatchesAtomicAcrossHandoffs() public view {
        handler.assertCatalogue();
        assertGt(handler.successfulBatches(), 0);
        assertGt(handler.rejectedBatches(), 0);
        assertGt(handler.acceptedHandoffs(), 0);
    }

    function invariant_PermanentCustodyEqualsOriginalQueuedLayouts() public view {
        handler.assertCustody();
        assertGt(handler.placedFloor(), 0);
        assertGt(handler.placedWall(), 0);
    }

    function afterInvariant() public view {
        handler.assertAllBoards();
    }

    function test_HandlerCoversBatchFailuresTransfersUpgradesAndStaleOwnerCalls() public {
        handler.defineBatch(bytes32(uint256(16)), 5, 1, 4);
        handler.defineBatch(bytes32(uint256(16)), 5, 3, 2);
        handler.defineBatch(bytes32(uint256(16)), 5, 4, 0);
        handler.defineBatch(bytes32(uint256(16)), 5, 5, 0);
        handler.defineBatch(bytes32(uint256(16)), 5, 0, 0);
        handler.defineOne(21, 4, 1, true, false);
        handler.queue(2, 0, 2, 2, 0);
        handler.transferClub(2, 0);
        handler.execute(2); // Original sender lost ownership while the transfer was pending.
        handler.transferClub(2, 2);
        handler.upgrade(2);
        handler.execute(2);
        handler.execute(2); // Retry cannot create a second entry or debit another piece.
        handler.nominate(2, true, false);
        handler.accept(0); // Former owner cannot accept another address's nomination.
        handler.nominate(0, true, true);
        handler.accept(2); // Cancelled nomination confers no authority.
        handler.nominate(2, true, false);
        handler.accept(2);
        handler.defineOne(0, 1, 1, true, true);
        handler.assertCatalogue();
        handler.assertCustody();
        handler.assertAllBoards();
        assertGe(handler.rejectedBatches(), 5);
        assertGe(handler.rejectedPlacements(), 2);
        assertEq(handler.acceptedHandoffs(), 2);
    }
}
