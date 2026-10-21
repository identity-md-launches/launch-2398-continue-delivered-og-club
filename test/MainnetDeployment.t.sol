// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {DeployMainnet} from "../script/DeployMainnet.s.sol";
import {OGClubFurniture} from "../src/OGClubFurniture.sol";
import {OGClubFarmVault} from "../src/OGClubFarmVault.sol";
import {OGClubStaking} from "../src/OGClubStaking.sol";
import {OGClubRaffle} from "../src/OGClubRaffle.sol";
import {OGClubClubs} from "../src/OGClubClubs.sol";

contract MainnetConstructorFactory {
    function deployAll(bytes[] memory codes, bytes32[] memory salts) external returns (address[] memory created) {
        require(codes.length == 5 && salts.length == 5);
        created = new address[](5);
        for (uint256 i; i < 5; ++i) {
            bytes memory code = codes[i];
            require(code.length <= 49_152);
            bytes32 salt = salts[i];
            address app;
            assembly ("memory-safe") { app := create2(0, add(code, 32), mload(code), salt) }
            require(app != address(0) && app.code.length != 0, "constructor failed");
            created[i] = app;
        }
    }
}

/// @dev Local contract-wallet fixture, not a Safe implementation or a mainnet launch value.
contract MainnetOwnerWallet {
    address private immutable controller = msg.sender;

    function execute(address target, bytes memory data) external {
        require(msg.sender == controller);
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        }
    }
}

contract MainnetDeploymentTest is Test {
    address internal constant OWNER = 0x5b95A971B4583A5f011E9DA082acdD679b870D06;
    address internal constant TOKEN = 0xCe7EB1Ad9e2E1c784ea05F7eA4A0Fe625923D10A;
    address internal constant PEPES = 0x999ce0CE8C5f7661e0c74a568FfE27CEB9177bDB;
    address internal constant REGISTRY = 0x00000000000000447e69651d841bD8D104Bed493;
    DeployMainnet internal script;
    MainnetConstructorFactory internal factory;
    address[] internal apps;

    function setUp() public {
        vm.chainId(1);
        script = new DeployMainnet();
        factory = new MainnetConstructorFactory();
        // No forks, mocks or code at the three live dependency addresses: constructors cannot query them.
        assertEq(TOKEN.code.length, 0);
        assertEq(PEPES.code.length, 0);
        assertEq(REGISTRY.code.length, 0);
        bytes[] memory codes = new bytes[](5);
        bytes32[] memory salts = new bytes32[](5);
        address[] memory predicted = new address[](5);
        string[5] memory names =
            [string("OGClubFurniture"), "OGClubFarmVault", "OGClubStaking", "OGClubRaffle", "OGClubClubs"];
        for (uint256 i; i < 5; ++i) {
            salts[i] = bytes32(i + 1); // Local rehearsal salts; no prediction of the service's salts.
            codes[i] = abi.encodePacked(vm.getCode(string.concat(names[i], ".sol:", names[i])), _args(i, predicted));
            predicted[i] = vm.computeCreate2Address(salts[i], keccak256(codes[i]), address(factory));
        }
        apps = factory.deployAll(codes, salts); // All five constructors execute in ONE factory call.
        for (uint256 i; i < 5; ++i) {
            assertEq(apps[i], predicted[i]);
        }
    }

    function _args(uint256 i, address[] memory predicted) private pure returns (bytes memory) {
        if (i == 0) return abi.encode(OWNER, OWNER);
        if (i == 1) return abi.encode(TOKEN, OWNER);
        if (i == 2) return abi.encode(TOKEN, predicted[1], OWNER, uint256(1e18));
        if (i == 3) return abi.encode(predicted[2], predicted[0], OWNER, uint256(604800));
        return abi.encode(
            TOKEN,
            predicted[1],
            uint256(100_000e18),
            predicted[0],
            OWNER,
            OWNER,
            PEPES,
            REGISTRY,
            uint256(200_000e18),
            uint256(400_000e18),
            uint256(800_000e18)
        );
    }

    function test_MainnetFactoryConstructorsDependenciesOwnersRuntimeAndUnconfiguredState() public view {
        assertEq(block.chainid, 1);
        for (uint256 i; i < 5; ++i) {
            Ownable2Step app = Ownable2Step(apps[i]);
            assertEq(app.owner(), OWNER);
            assertEq(app.pendingOwner(), address(0));
            assertTrue(app.owner() != address(factory));
            _checkRuntime(apps[i].code);
        }
        OGClubFurniture furniture = OGClubFurniture(apps[0]);
        OGClubFarmVault vault = OGClubFarmVault(apps[1]);
        OGClubStaking staking = OGClubStaking(apps[2]);
        OGClubRaffle raffle = OGClubRaffle(apps[3]);
        OGClubClubs clubs = OGClubClubs(apps[4]);
        assertEq(address(vault.token()), TOKEN);
        assertEq(address(staking.token()), TOKEN);
        assertEq(staking.vault(), apps[1]);
        assertEq(staking.pointsPerTokenDay(), 1e18);
        assertEq(staking.accrualDenominator(), 0);
        assertEq(address(raffle.staking()), apps[2]);
        assertEq(address(raffle.furniture()), apps[0]);
        assertEq(raffle.raffleNotice(), 604800);
        assertEq(address(clubs.token()), TOKEN);
        assertEq(clubs.vault(), apps[1]);
        assertEq(address(clubs.furniture()), apps[0]);
        assertEq(address(clubs.pepes()), PEPES);
        assertEq(address(clubs.delegates()), REGISTRY);
        assertEq(clubs.price(), 100_000e18);
        assertEq(clubs.upgradePrice(1), 200_000e18);
        assertEq(clubs.upgradePrice(2), 400_000e18);
        assertEq(clubs.upgradePrice(3), 800_000e18);
        assertFalse(clubs.saleOpen());
        assertEq(clubs.baseURI(), "");
        assertEq(furniture.baseURI(), "");
        assertFalse(furniture.bootstrapped());
        assertFalse(staking.bootstrapped());
        for (uint256 id = 1; id <= 24; ++id) {
            (,, bool set,,) = clubs.footprintOf(id);
            assertFalse(set);
        }
        (address receiver, uint256 royalty) = furniture.royaltyInfo(1, 10_000);
        assertEq(receiver, OWNER);
        assertEq(royalty, 500);
        (receiver, royalty) = clubs.royaltyInfo(1, 10_000);
        assertEq(receiver, OWNER);
        assertEq(royalty, 500);
    }

    function test_PrintedOwnerCallsConfigureExactCatalogueAndPreserveDelayedLaterGrants() public {
        _ownerSetup();
        OGClubFurniture furniture = OGClubFurniture(apps[0]);
        OGClubStaking staking = OGClubStaking(apps[2]);
        address later = makeAddr("later role");
        vm.startPrank(OWNER);
        furniture.grantMinter(later);
        staking.grantSpender(later);
        vm.stopPrank();
        assertFalse(furniture.minters(later));
        assertFalse(staking.spenders(later));
        uint256 maturity = block.timestamp + 7 days;
        assertEq(furniture.pendingMinters(later), maturity);
        assertEq(staking.pendingSpenders(later), maturity);
        vm.expectRevert(abi.encodeWithSelector(OGClubFurniture.MinterDelayNotElapsed.selector, later, maturity));
        furniture.activateMinter(later);
        vm.expectRevert(abi.encodeWithSelector(OGClubStaking.SpenderDelayNotElapsed.selector, later, maturity));
        staking.activateSpender(later);
        vm.warp(maturity);
        furniture.activateMinter(later);
        staking.activateSpender(later);
        assertTrue(furniture.minters(later));
        assertTrue(staking.spenders(later));
    }

    function _ownerSetup() private {
        bytes[6] memory calls = script.setupCalldata(apps[3]);
        address[6] memory targets = [apps[0], apps[2], apps[0], apps[4], apps[4], apps[4]];
        for (uint256 i; i < 5; ++i) {
            vm.prank(OWNER);
            (bool ok, bytes memory result) = targets[i].call(calls[i]);
            assertTrue(ok, string(result));
        }
        OGClubFurniture furniture = OGClubFurniture(apps[0]);
        OGClubStaking staking = OGClubStaking(apps[2]);
        OGClubClubs clubs = OGClubClubs(apps[4]);
        assertTrue(furniture.minters(apps[3]));
        assertTrue(staking.spenders(apps[3]));
        assertTrue(furniture.bootstrapped() && staking.bootstrapped());
        assertEq(furniture.uri(23), "https://world.ogclub.online/nft/23.json");
        assertEq(clubs.baseURI(), "https://world.ogclub.online/club/");
        assertFalse(clubs.saleOpen());
        for (uint256 id = 1; id <= 24; ++id) {
            (uint8 w, uint8 h, bool set, bool locked, bool wall) = clubs.footprintOf(id);
            assertEq(w, id == 3 || id == 5 || id == 12 || id == 18 || id == 20 || id == 23 ? 2 : 1);
            assertEq(h, id == 5 ? 2 : 1);
            assertEq(wall, id == 23);
            assertTrue(set);
            assertFalse(locked);
        }
        vm.prank(OWNER);
        (bool opened,) = targets[5].call(calls[5]);
        assertTrue(opened && clubs.saleOpen());
    }

    function test_AllFiveTwoStepHandoffsToContractWalletPreserveSetupAndRoyalty() public {
        _ownerSetup();
        MainnetOwnerWallet wallet = new MainnetOwnerWallet();
        for (uint256 i; i < 5; ++i) {
            Ownable2Step app = Ownable2Step(apps[i]);
            vm.prank(OWNER);
            app.transferOwnership(address(wallet));
            assertEq(app.owner(), OWNER);
            assertEq(app.pendingOwner(), address(wallet));
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER));
            vm.prank(OWNER);
            app.acceptOwnership();
            wallet.execute(apps[i], abi.encodeCall(app.acceptOwnership, ()));
            assertEq(app.owner(), address(wallet));
            assertEq(app.pendingOwner(), address(0));
            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER));
            vm.prank(OWNER);
            app.transferOwnership(OWNER);
        }
        OGClubClubs clubs = OGClubClubs(apps[4]);
        OGClubFurniture furniture = OGClubFurniture(apps[0]);
        OGClubStaking staking = OGClubStaking(apps[2]);
        wallet.execute(apps[4], abi.encodeCall(clubs.setSaleOpen, (false)));
        assertFalse(clubs.saleOpen());
        assertTrue(furniture.minters(apps[3]) && staking.spenders(apps[3]));
        wallet.execute(apps[0], abi.encodeCall(furniture.grantMinter, (address(wallet))));
        wallet.execute(apps[2], abi.encodeCall(staking.grantSpender, (address(wallet))));
        assertFalse(furniture.minters(address(wallet)) || staking.spenders(address(wallet)));
        assertEq(furniture.pendingMinters(address(wallet)), block.timestamp + 7 days);
        assertEq(staking.pendingSpenders(address(wallet)), block.timestamp + 7 days);
        (address royalty,) = furniture.royaltyInfo(1, 10_000);
        assertEq(royalty, OWNER);
        (royalty,) = clubs.royaltyInfo(1, 10_000);
        assertEq(royalty, OWNER);
        vm.expectRevert(OGClubClubs.FootprintLocked.selector);
        wallet.execute(apps[4], abi.encodeCall(clubs.setFootprint, (uint256(1), uint8(1), uint8(1), false)));
    }

    function test_MainnetNoticeRejectsEarlyOpeningAndAcceptsSevenDayBoundary() public {
        OGClubRaffle raffle = OGClubRaffle(apps[3]);
        OGClubRaffle.PoolInput[] memory pools = new OGClubRaffle.PoolInput[](1);
        OGClubRaffle.Prize[] memory prizes = new OGClubRaffle.Prize[](1);
        prizes[0] = OGClubRaffle.Prize(23, 1);
        pools[0] = OGClubRaffle.PoolInput(0, 1e18, 1, prizes);
        vm.startPrank(OWNER);
        vm.expectRevert(OGClubRaffle.InsufficientNotice.selector);
        raffle.createRaffle(block.timestamp, block.timestamp + 1 days, pools);
        vm.expectRevert(OGClubRaffle.InsufficientNotice.selector);
        raffle.createRaffle(block.timestamp + 7 days - 1, block.timestamp + 8 days, pools);
        assertEq(raffle.createRaffle(block.timestamp + 7 days, block.timestamp + 8 days, pools), 1);
        vm.stopPrank();
    }

    function test_MainnetScriptRehearsesFiveApplicationsAndRejectsWrongChain() public {
        DeployMainnet.Applications memory result = script.run();
        assertEq(result.furniture.owner(), OWNER);
        assertEq(address(result.vault.token()), TOKEN);
        assertEq(result.staking.vault(), address(result.vault));
        assertEq(address(result.raffle.staking()), address(result.staking));
        assertEq(address(result.clubs.furniture()), address(result.furniture));
        assertFalse(result.clubs.saleOpen());
        assertFalse(result.furniture.bootstrapped());
        assertFalse(result.staking.bootstrapped());
        vm.chainId(11155111);
        vm.expectRevert(DeployMainnet.WrongChain.selector);
        script.run();
        vm.expectRevert(DeployMainnet.InvalidApplicationAddress.selector);
        script.setupCalldata(address(0));
    }

    function _checkRuntime(bytes memory code) private pure {
        assertGt(code.length, 0);
        assertLe(code.length, 24_576);
        bool reachable = true;
        for (uint256 j; j < code.length; ++j) {
            uint8 op = uint8(code[j]);
            if (op == 0x5b) reachable = true;
            if (op >= 0x60 && op <= 0x7f) {
                j += op - 0x5f;
                continue;
            }
            if (reachable) assertTrue(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden application opcode");
            if (op == 0x00 || op == 0x56 || op == 0xf3 || op == 0xfd || op == 0xfe || op == 0xff) reachable = false;
        }
    }
}
