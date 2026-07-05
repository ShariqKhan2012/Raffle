//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5MockLocal} from "test/mocks/VRFCoordinatorV2_5MockLocal.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entryFee;
        uint256 interval;
        uint256 subscriptionId;
        bytes32 hashKey;
        address vrfCoordinator;
        uint32 callbackGasLimit;
        address linkToken;
    }

    NetworkConfig private s_ActiveConfig;

    /// @dev Mainnet related constants
    address constant MAINNET_ETH_VRF_COORDINATOR = 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a;

    address constant MAINNET_LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    bytes32 constant MAINNET_ETH_GAS_LANE = 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9;

    /// @dev SEPOLIA Testnet related constants
    address constant SEPOLIA_ETH_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    address constant SEPOLIA_LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    bytes32 constant SEPOLIA_ETH_GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    /// @dev POLYGON Testnet related constants
    address constant POLYGON_ETH_VRF_COORDINATOR = 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2;

    address constant POLYGON_LINK_TOKEN = 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    bytes32 constant POLYGON_ETH_GAS_LANE = 0x816bedba8a50b294e5cbd47842baf240c2385f2eaf719edbd4f250a137a8c899;

    uint256 constant CHAINLINK_POLYGON_SUBSCRIPTION_ID =
        41085934845044354063341550534836621797926273166421041441715998229819555513022;

    /**
     * @dev VRF Mock Constants
     */
    uint96 private constant MOCK_BASE_FEE = 0.25 ether;
    uint96 private constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 private constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint8 constant ETH_MAINNET_CHAINID = 1;
    uint256 constant ETH_SEPOLIA_CHAINID = 11155111;
    uint256 constant POLYGON_CHAINID = 80002;
    uint256 constant ANVIL_CHAINID = 31337;

    constructor() {
        if (block.chainid == ETH_MAINNET_CHAINID) {
            s_ActiveConfig = getMainnetEthConfig();
        } else if (block.chainid == ETH_SEPOLIA_CHAINID) {
            s_ActiveConfig = getSepoliaEthConfig();
        } else if (block.chainid == POLYGON_CHAINID) {
            s_ActiveConfig = getPolygonConfig();
        } else if (block.chainid == ANVIL_CHAINID) {
            s_ActiveConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return s_ActiveConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0,
            hashKey: MAINNET_ETH_GAS_LANE,
            vrfCoordinator: MAINNET_ETH_VRF_COORDINATOR,
            callbackGasLimit: 500000,
            linkToken: MAINNET_LINK_TOKEN
        });
    }

    // Reads CHAINLINK_SEPOLIA_SUBSCRIPTION_ID from .env (Foundry auto-loads .env).
    // Set it to 0 to trigger automatic subscription creation on first deploy.
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.0001 ether,
            interval: 60,
            subscriptionId: vm.envOr("CHAINLINK_SEPOLIA_SUBSCRIPTION_ID", uint256(0)),
            hashKey: SEPOLIA_ETH_GAS_LANE,
            vrfCoordinator: SEPOLIA_ETH_VRF_COORDINATOR,
            callbackGasLimit: 500000,
            linkToken: SEPOLIA_LINK_TOKEN
        });
    }

    function getPolygonConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subscriptionId: CHAINLINK_POLYGON_SUBSCRIPTION_ID,
            hashKey: POLYGON_ETH_GAS_LANE,
            vrfCoordinator: POLYGON_ETH_VRF_COORDINATOR,
            callbackGasLimit: 500000,
            linkToken: POLYGON_LINK_TOKEN
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (s_ActiveConfig.vrfCoordinator != address(0)) {
            return s_ActiveConfig;
        }

        // vm.startBroadcast() with no argument uses the --account signer automatically.
        vm.startBroadcast();
        VRFCoordinatorV2_5MockLocal vrfCoordinator =
            new VRFCoordinatorV2_5MockLocal(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        s_ActiveConfig = NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0,
            hashKey: SEPOLIA_ETH_GAS_LANE,
            vrfCoordinator: address(vrfCoordinator),
            callbackGasLimit: 500000,
            linkToken: address(linkToken)
        });

        return s_ActiveConfig;
    }
}
