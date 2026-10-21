// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OGClubClubs} from "src/OGClubClubs.sol";
import {IDelegateRegistry} from "src/interfaces/IDelegateRegistry.sol";

/// @dev Setter properties need no token/NFT implementation. Constructor dependencies
/// are deliberately empty addresses on the local chain; all tests run offline.
/// forge-config: default.fuzz.runs = 512
contract FootprintBatchPropertiesTest is Test {
    OGClubClubs private batched;
    OGClubClubs private individual;

    struct Catalogue {
        uint256[] ids;
        uint8[] w;
        uint8[] h;
        bool[] wall;
    }

    function setUp() public {
        batched = _deploy();
        individual = _deploy();
    }

    function _deploy() private returns (OGClubClubs) {
        return new OGClubClubs(
            IERC20(0xCe7EB1Ad9e2E1c784ea05F7eA4A0Fe625923D10A),
            makeAddr("batch property vault"),
            100_000e18,
            IERC1155(makeAddr("batch property furniture")),
            address(this),
            address(this),
            IERC721(0x999ce0CE8C5f7661e0c74a568FfE27CEB9177bDB),
            IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493),
            200_000e18,
            400_000e18,
            800_000e18
        );
    }

    function _catalogue(bytes32 seed, uint256 n) private pure returns (Catalogue memory c) {
        c = Catalogue(new uint256[](n), new uint8[](n), new uint8[](n), new bool[](n));
        uint256 first = bound(uint256(seed), 0, type(uint256).max - (n - 1));
        for (uint256 i; i < n; ++i) {
            uint256 r = uint256(keccak256(abi.encode(seed, i)));
            c.ids[i] = first + i;
            c.w[i] = uint8(1 + r % 4);
            c.wall[i] = (r >> 8) % 2 == 1;
            c.h[i] = c.wall[i] ? 1 : uint8(1 + (r >> 16) % 4);
        }
    }

    function testFuzz_BatchEqualsReversedSinglesAndEmitsOneUnchangedEventPerItem(bytes32 seed, uint8 rawLength) public {
        Catalogue memory c = _catalogue(seed, bound(rawLength, 1, 32));
        vm.recordLogs();
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, c.ids.length);
        for (uint256 i; i < c.ids.length; ++i) {
            assertEq(logs[i].emitter, address(batched));
            assertEq(logs[i].topics.length, 2);
            assertEq(logs[i].topics[0], keccak256("FootprintSet(uint256,uint8,uint8,bool)"));
            assertEq(logs[i].topics[1], bytes32(c.ids[i]));
            assertEq(logs[i].data, abi.encode(c.w[i], c.h[i], c.wall[i]));
        }
        for (uint256 i = c.ids.length; i > 0; --i) {
            individual.setFootprint(c.ids[i - 1], c.w[i - 1], c.h[i - 1], c.wall[i - 1]);
        }
        _assertCatalogue(batched, c);
        _assertCatalogue(individual, c);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        _assertCatalogue(batched, c);
    }

    function testFuzz_InvalidGeometryAtAnyPositionRollsBackAndCanBeRetried(
        bytes32 seed,
        uint8 rawLength,
        uint8 rawIndex,
        uint8 rawKind
    ) public {
        Catalogue memory c = _catalogue(seed, bound(rawLength, 2, 32));
        uint256 index = bound(rawIndex, 0, c.ids.length - 1);
        uint8 originalW = c.w[index];
        uint8 originalH = c.h[index];
        bool originalWall = c.wall[index];
        uint8 kind = rawKind % 7;
        if (kind == 0) {
            c.w[index] = 0;
        } else if (kind == 1) {
            c.h[index] = 0;
        } else if (kind == 2) {
            c.w[index] = 5;
        } else if (kind == 3) {
            c.h[index] = 5;
        } else if (kind == 4) {
            c.w[index] = type(uint8).max;
        } else if (kind == 5) {
            c.h[index] = type(uint8).max;
        } else {
            c.wall[index] = true;
            c.h[index] = 2;
        }
        vm.expectRevert(OGClubClubs.BadFootprint.selector);
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        _assertUnset(c.ids);
        c.w[index] = originalW;
        c.h[index] = originalH;
        c.wall[index] = originalWall;
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        _assertCatalogue(batched, c);
    }

    function testFuzz_DuplicateAtAnyTwoPositionsRollsBackIncludingDifferentDefinitions(
        bytes32 seed,
        uint8 rawLength,
        uint8 rawFirst,
        uint8 rawOffset
    ) public {
        Catalogue memory c = _catalogue(seed, bound(rawLength, 2, 32));
        uint256 first = bound(rawFirst, 0, c.ids.length - 1);
        uint256 second = (first + bound(rawOffset, 1, c.ids.length - 1)) % c.ids.length;
        uint256 originalId = c.ids[second];
        c.ids[second] = c.ids[first];
        c.w[second] = c.w[first] == 4 ? 1 : 4;
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        c.ids[second] = originalId;
        _assertUnset(c.ids);
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        _assertCatalogue(batched, c);
    }

    function test_ZeroAndMaximumIdsHaveTheSameFinalityRules() public {
        Catalogue memory c = _catalogue(bytes32(0), 2);
        c.ids[1] = type(uint256).max;
        c.w[0] = 4;
        c.h[0] = 4;
        c.wall[0] = false;
        c.w[1] = 4;
        c.h[1] = 1;
        c.wall[1] = true;
        batched.setFootprints(c.ids, c.w, c.h, c.wall);
        for (uint256 i; i < c.ids.length; ++i) {
            vm.expectRevert(OGClubClubs.FootprintLocked.selector);
            batched.setFootprint(c.ids[i], 1, 1, !c.wall[i]);
        }
        _assertCatalogue(batched, c);
    }

    function _assertUnset(uint256[] memory ids) private view {
        for (uint256 i; i < ids.length; ++i) {
            (uint8 w, uint8 h, bool set, bool locked, bool wall) = batched.footprintOf(ids[i]);
            assertEq(abi.encode(w, h, set, locked, wall), abi.encode(uint8(0), uint8(0), false, false, false));
        }
    }

    function _assertCatalogue(OGClubClubs clubs, Catalogue memory c) private view {
        for (uint256 i; i < c.ids.length; ++i) {
            (uint8 w, uint8 h, bool set, bool locked, bool wall) = clubs.footprintOf(c.ids[i]);
            assertEq(abi.encode(w, h, set, locked, wall), abi.encode(c.w[i], c.h[i], true, false, c.wall[i]));
        }
    }
}
