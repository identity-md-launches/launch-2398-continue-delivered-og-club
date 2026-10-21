// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ClubsTestBase} from "./helpers/ClubsTestBase.sol";
import {OGClubClubs} from "../src/OGClubClubs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ClubsFootprintsTest is ClubsTestBase {
    event FootprintSet(uint256 indexed furnitureId, uint8 w, uint8 h, bool wall);

    function test_DefinitionIsFinalBeforePlacementIncludingIdenticalAndInvalidReset() public {
        clubs.setFootprint(5, 2, 1, false);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(5, 2, 1, false);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(5, 1, 1, true);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(5, 0, 0, false);
        _assertDefinition(5, 2, 1, false);
        (,,, bool locked,) = clubs.footprintOf(5);
        assertFalse(locked); // The unchanged view still records placement separately.
    }

    function test_PendingFloorPlacementKeepsKindSizeAndRotation() public {
        clubs.setFootprint(5, 2, 1, false);
        stock(alice, 5, 1);
        bytes memory pending = abi.encode(uint256(1), uint8(3), uint8(0), uint8(1));
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(5, 1, 1, true);
        vm.prank(alice);
        furniture.safeTransferFrom(alice, address(clubs), 5, 1, pending);
        OGClubClubs.Piece memory piece = clubs.piecesOf(1)[0];
        assertEq(abi.encode(piece), abi.encode(OGClubClubs.Piece(5, 3, 0, 1, false)));
        assertTrue(clubs.tileTaken(1, 3, 0));
        assertTrue(clubs.tileTaken(1, 3, 1));
        assertFalse(clubs.tileTaken(1, 4, 0));
        assertFalse(clubs.wallTaken(1, 1, 3));
        assertEq(furniture.balanceOf(address(clubs), 5), 1);
    }

    function test_PendingEdgePlacementKeepsOriginalSize() public {
        clubs.setFootprint(6, 2, 2, false);
        stock(alice, 6, 1);
        bytes memory pending = abi.encode(uint256(1), uint8(8), uint8(8), uint8(0));
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(6, 4, 4, false);
        vm.prank(alice);
        furniture.safeTransferFrom(alice, address(clubs), 6, 1, pending);
        for (uint8 x = 8; x < 10; ++x) {
            for (uint8 y = 8; y < 10; ++y) {
                assertTrue(clubs.tileTaken(1, x, y));
            }
        }
        assertFalse(clubs.tileTaken(1, 7, 8));
        _assertDefinition(6, 2, 2, false);
    }

    function test_PendingWallPlacementKeepsWidthAndSide() public {
        clubs.setFootprint(7, 2, 1, true);
        stock(alice, 7, 1);
        bytes memory pending = abi.encode(uint256(1), uint8(8), uint8(0), uint8(1));
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprint(7, 4, 4, false);
        vm.prank(alice);
        furniture.safeTransferFrom(alice, address(clubs), 7, 1, pending);
        assertEq(abi.encode(clubs.piecesOf(1)[0]), abi.encode(OGClubClubs.Piece(7, 8, 0, 1, true)));
        assertTrue(clubs.wallTaken(1, 1, 8));
        assertTrue(clubs.wallTaken(1, 1, 9));
        assertFalse(clubs.wallTaken(1, 0, 8));
        assertFalse(clubs.tileTaken(1, 8, 0));
    }

    function _batch()
        private
        pure
        returns (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall)
    {
        ids = new uint256[](3);
        w = new uint8[](3);
        h = new uint8[](3);
        wall = new bool[](3);
        ids[0] = 0;
        ids[1] = 50;
        ids[2] = type(uint256).max;
        w[0] = 4;
        h[0] = 4;
        w[1] = 2;
        h[1] = 1;
        wall[1] = true;
        w[2] = 1;
        h[2] = 3;
    }

    function test_BatchSetsAllEntriesEmitsUnchangedEventsAndLocksBothSetters() public {
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = _batch();
        for (uint256 i; i < ids.length; ++i) {
            vm.expectEmit(true, false, false, true, address(clubs));
            emit FootprintSet(ids[i], w[i], h[i], wall[i]);
        }
        clubs.setFootprints(ids, w, h, wall);
        for (uint256 i; i < ids.length; ++i) {
            _assertDefinition(ids[i], w[i], h[i], wall[i]);
            vm.expectRevert(OGClubClubs.FootprintLocked.selector);
            clubs.setFootprint(ids[i], w[i], h[i], wall[i]);
        }
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprints(ids, w, h, wall);
        stock(alice, 50, 1);
        place(alice, 1, 50, 8, 0, 0);
        assertTrue(clubs.wallTaken(1, 0, 8));
        assertTrue(clubs.wallTaken(1, 0, 9));
    }

    function test_BatchRejectsEveryLengthMismatchWithoutWrites() public {
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = _batch();
        for (uint256 length; length <= 4; ++length) {
            if (length == ids.length) continue;
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(ids, new uint8[](length), h, wall);
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(ids, w, new uint8[](length), wall);
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(ids, w, h, new bool[](length));
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(new uint256[](length), w, h, wall);
        }
        _assertUnset(ids);
    }

    function test_BatchBadLastEntryRollsBackEarlierDefinitions() public {
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = _batch();
        uint8[3] memory invalid = [uint8(0), 5, 255];
        for (uint256 i; i < invalid.length; ++i) {
            w[2] = invalid[i];
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(ids, w, h, wall);
            _assertUnset(ids);
            w[2] = 1;
            h[2] = invalid[i];
            vm.expectRevert(OGClubClubs.BadFootprint.selector);
            clubs.setFootprints(ids, w, h, wall);
            _assertUnset(ids);
            h[2] = 3;
        }
        wall[2] = true;
        vm.expectRevert(OGClubClubs.BadFootprint.selector);
        clubs.setFootprints(ids, w, h, wall);
        _assertUnset(ids);
        wall[2] = false;
        clubs.setFootprints(ids, w, h, wall); // All definitions remain available after failed batches.
        for (uint256 i; i < ids.length; ++i) {
            _assertDefinition(ids[i], w[i], h[i], wall[i]);
        }
    }

    function test_BatchDuplicateRollsBackAndCannotRewritePendingDefinition() public {
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = _batch();
        ids[2] = ids[0];
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprints(ids, w, h, wall);
        _assertUnset(ids);
        ids[2] = 1; // Already set in the fixture but never placed.
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprints(ids, w, h, wall);
        _assertDefinition(1, 1, 1, false);
        (,, bool firstSet,,) = clubs.footprintOf(0);
        (,, bool secondSet,,) = clubs.footprintOf(50);
        assertFalse(firstSet || secondSet);
        place(alice, 1, 1, 2, 2, 0);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprints(ids, w, h, wall); // Same rules after placement.
        assertTrue(clubs.tileTaken(1, 2, 2));
        assertEq(clubs.pieceCount(1), 1);
    }

    function test_BatchOwnerOnlyIncludingEmptyAndEmptyOwnerBatchIsNoop() public {
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = _batch();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        clubs.setFootprints(ids, w, h, wall);
        _assertUnset(ids);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.prank(alice);
        clubs.setFootprints(new uint256[](0), new uint8[](0), new uint8[](0), new bool[](0));
        clubs.setFootprints(new uint256[](0), new uint8[](0), new uint8[](0), new bool[](0));
        _assertDefinition(1, 1, 1, false);
    }

    function testFuzz_BatchFinalityAndAtomicity(uint256 rawId, uint8 width, uint8 height, bool isWall) public {
        uint256 id = bound(rawId, 10, type(uint256).max - 1);
        uint8 w = uint8(bound(width, 1, 4));
        uint8 h = isWall ? 1 : uint8(bound(height, 1, 4));
        clubs.setFootprint(id, w, h, isWall);
        uint256[] memory ids = new uint256[](2);
        uint8[] memory widths = new uint8[](2);
        uint8[] memory heights = new uint8[](2);
        bool[] memory walls = new bool[](2);
        ids[0] = id + 1;
        ids[1] = id;
        widths[0] = widths[1] = 1;
        heights[0] = heights[1] = 1;
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        clubs.setFootprints(ids, widths, heights, walls);
        _assertDefinition(id, w, h, isWall);
        (,, bool set,,) = clubs.footprintOf(id + 1);
        assertFalse(set);
    }

    function _assertUnset(uint256[] memory ids) private view {
        for (uint256 i; i < ids.length; ++i) {
            (uint8 w, uint8 h, bool set, bool locked, bool wall) = clubs.footprintOf(ids[i]);
            assertEq(w, 0);
            assertEq(h, 0);
            assertFalse(set || locked || wall);
        }
    }

    function _assertDefinition(uint256 id, uint8 width, uint8 height, bool isWall) private view {
        (uint8 w, uint8 h, bool set,, bool wall) = clubs.footprintOf(id);
        assertEq(w, width);
        assertEq(h, height);
        assertTrue(set);
        assertEq(wall, isWall);
    }
}
