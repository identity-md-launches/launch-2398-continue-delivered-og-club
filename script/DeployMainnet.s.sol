// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IDelegateRegistry} from "../src/interfaces/IDelegateRegistry.sol";
import {OGClubFurniture} from "../src/OGClubFurniture.sol";
import {OGClubFarmVault} from "../src/OGClubFarmVault.sol";
import {OGClubStaking} from "../src/OGClubStaking.sol";
import {OGClubRaffle} from "../src/OGClubRaffle.sol";
import {OGClubClubs} from "../src/OGClubClubs.sol";

/// @notice Offline constructor-only mainnet rehearsal and owner calldata printer.
/// @dev Never reads keys, starts a broadcast, calls the launch factory or performs owner setup.
contract DeployMainnet is Script {
    address public constant OG_TOKEN = 0xCe7EB1Ad9e2E1c784ea05F7eA4A0Fe625923D10A;
    address public constant SWARM_PEPES = 0x999ce0CE8C5f7661e0c74a568FfE27CEB9177bDB;
    address public constant DELEGATE_REGISTRY = 0x00000000000000447e69651d841bD8D104Bed493;
    address public constant OWNER = 0x5b95A971B4583A5f011E9DA082acdD679b870D06;
    uint256 public constant POINTS_PER_TOKEN_DAY = 1e18;
    uint256 public constant RAFFLE_NOTICE = 604800;
    uint256 public constant CLUB_PRICE = 100_000e18;
    uint256 public constant LEVEL_2_PRICE = 200_000e18;
    uint256 public constant LEVEL_3_PRICE = 400_000e18;
    uint256 public constant LEVEL_4_PRICE = 800_000e18;
    string public constant FURNITURE_URI = "https://world.ogclub.online/nft/";
    string public constant CLUBS_URI = "https://world.ogclub.online/club/";
    error WrongChain();
    error InvalidApplicationAddress();

    struct Applications {
        OGClubFurniture furniture;
        OGClubFarmVault vault;
        OGClubStaking staking;
        OGClubRaffle raffle;
        OGClubClubs clubs;
    }

    function run() external returns (Applications memory apps) {
        if (block.chainid != 1) revert WrongChain();
        apps.furniture = new OGClubFurniture(OWNER, OWNER);
        apps.vault = new OGClubFarmVault(IERC20(OG_TOKEN), OWNER);
        apps.staking = new OGClubStaking(IERC20(OG_TOKEN), address(apps.vault), OWNER, POINTS_PER_TOKEN_DAY);
        apps.raffle = new OGClubRaffle(apps.staking, apps.furniture, OWNER, RAFFLE_NOTICE);
        apps.clubs = new OGClubClubs(
            IERC20(OG_TOKEN),
            address(apps.vault),
            CLUB_PRICE,
            IERC1155(address(apps.furniture)),
            OWNER,
            OWNER,
            IERC721(SWARM_PEPES),
            IDelegateRegistry(DELEGATE_REGISTRY),
            LEVEL_2_PRICE,
            LEVEL_3_PRICE,
            LEVEL_4_PRICE
        );
        console2.log("LOCAL REHEARSAL ONLY: these addresses are not mainnet deployments.");
        printHandoff(
            address(apps.furniture),
            address(apps.vault),
            address(apps.staking),
            address(apps.raffle),
            address(apps.clubs)
        );
    }

    /// @notice Exact approved catalogue. Widths and the wall flag are final as soon as the batch succeeds.
    function catalogue()
        public
        pure
        returns (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall)
    {
        ids = new uint256[](24);
        w = new uint8[](24);
        h = new uint8[](24);
        wall = new bool[](24);
        for (uint256 i; i < 24; ++i) {
            ids[i] = i + 1;
            w[i] = 1;
            h[i] = 1;
        }
        w[2] = 2; // #3
        w[4] = 2; // #5
        h[4] = 2;
        w[11] = 2; // #12
        w[17] = 2; // #18
        w[19] = 2; // #20
        w[22] = 2; // #23, the only wall design
        wall[22] = true;
    }

    function setupCalldata(address raffle) public pure returns (bytes[6] memory calls) {
        if (raffle == address(0)) revert InvalidApplicationAddress();
        calls[0] = abi.encodeCall(OGClubFurniture.grantMinter, (raffle));
        calls[1] = abi.encodeCall(OGClubStaking.grantSpender, (raffle));
        calls[2] = abi.encodeCall(OGClubFurniture.setBaseURI, (FURNITURE_URI));
        calls[3] = abi.encodeCall(OGClubClubs.setBaseURI, (CLUBS_URI));
        (uint256[] memory ids, uint8[] memory w, uint8[] memory h, bool[] memory wall) = catalogue();
        calls[4] = abi.encodeCall(OGClubClubs.setFootprints, (ids, w, h, wall));
        calls[5] = abi.encodeCall(OGClubClubs.setSaleOpen, (true));
    }

    /// @notice Re-run with the launch service's five confirmed addresses to print wallet-ready owner calls.
    /// @dev All addresses are supplied explicitly; this function only encodes and logs, with no external calls.
    function printHandoff(address furniture, address vault, address staking, address raffle, address clubs)
        public
        pure
    {
        if (furniture == address(0) || vault == address(0) || staking == address(0) || clubs == address(0)) {
            revert InvalidApplicationAddress();
        }
        bytes[6] memory calls = setupCalldata(raffle);
        console2.log("Chain: Ethereum mainnet (1). Owner and initial royalty receiver:", OWNER);
        console2.log("OGClubFurniture", furniture);
        console2.log("Constructor arguments (owner, royaltyReceiver):");
        console2.logBytes(abi.encode(OWNER, OWNER));
        console2.log("OGClubFarmVault", vault);
        console2.log("Constructor arguments (token, owner):");
        console2.logBytes(abi.encode(OG_TOKEN, OWNER));
        console2.log("OGClubStaking", staking);
        console2.log("Constructor arguments (token, vault, owner, pointsPerTokenDay):");
        console2.logBytes(abi.encode(OG_TOKEN, vault, OWNER, POINTS_PER_TOKEN_DAY));
        console2.log("OGClubRaffle", raffle);
        console2.log("Constructor arguments (staking, furniture, owner, raffleNotice):");
        console2.logBytes(abi.encode(staking, furniture, OWNER, RAFFLE_NOTICE));
        console2.log("OGClubClubs", clubs);
        console2.log(
            "Constructor arguments (token, vault, price, furniture, owner, royaltyReceiver, pepes, delegates, level2Price, level3Price, level4Price):"
        );
        console2.logBytes(
            abi.encode(
                OG_TOKEN,
                vault,
                CLUB_PRICE,
                furniture,
                OWNER,
                OWNER,
                SWARM_PEPES,
                DELEGATE_REGISTRY,
                LEVEL_2_PRICE,
                LEVEL_3_PRICE,
                LEVEL_4_PRICE
            )
        );
        console2.log("Owner setup in order; every call sends 0 ETH:");
        _printCall("1a. FIRST furniture grantMinter(raffle)", furniture, calls[0]);
        _printCall("1b. FIRST staking grantSpender(raffle)", staking, calls[1]);
        _printCall("2a. furniture setBaseURI", furniture, calls[2]);
        _printCall("2b. clubs setBaseURI", clubs, calls[3]);
        _printCall("3. clubs setFootprints (24 final definitions, one atomic batch)", clubs, calls[4]);
        _printCall("4. ONLY WHEN LAUNCH IS ANNOUNCED: clubs setSaleOpen(true)", clubs, calls[5]);
        console2.log("Later Safe handoff: current owner calls transferOwnership(Safe) on EACH of the five contracts;");
        console2.log("the Safe calls acceptOwnership() on EACH. Accept calldata:");
        console2.logBytes(abi.encodeWithSignature("acceptOwnership()"));
    }

    function _printCall(string memory label, address target, bytes memory data) private pure {
        console2.log(label);
        console2.log("to", target);
        console2.logBytes(data);
    }
}
