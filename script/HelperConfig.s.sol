//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
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
        address deployerAccount;
    }

    NetworkConfig private s_ActiveConfig;

    /// @dev Mainnet related constants
    address constant MAINNET_ETH_VRF_COORDINATOR =
        0xD7f86b4b8Cae7D942340FF628F82735b7a20893a;

    address constant MAINNET_LINK_TOKEN =
        0x514910771AF9Ca656af840dff83E8264EcF986CA;

    bytes32 constant MAINNET_ETH_GAS_LANE =
        0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9;

    address constant MAINNET_DEPLOYER_ACCOUNT =
        0x7bBb2Cfb1a2cBd319C5720eaE107E4d7d98329BE;

    /// @dev SEPOLIA Testnet related constants
    address constant SEPOLIA_ETH_VRF_COORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    address constant SEPOLIA_LINK_TOKEN =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

    bytes32 constant SEPOLIA_ETH_GAS_LANE =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint256 constant CHAINLINK_SEPOLIA_SUBSCRIPTION_ID =
        41085934845044354063341550534836621797926273166421041441715998229819555513022;

    address constant SEPOLIA_DEPLOYER_ACCOUNT =
        0x7bBb2Cfb1a2cBd319C5720eaE107E4d7d98329BE;

    /**
     * @dev This is the default address used by
     * foundry/anvil for tx.origin and msg.sender
     */
    address constant ANVIL_DEPLOYER_ACCOUNT =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    /**
     * @dev VRF Mock Constants
     */
    uint96 private constant MOCK_BASE_FEE = 0.25 ether;
    uint96 private constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 private constant MOCK_WEI_PER_UNIT_LINK = 4e15; // Link/ETH Price

    uint8 constant ETH_MAINNET_CHAINID = 1;
    uint256 constant ETH_SEPOLIA_CHAINID = 11155111;
    uint256 constant ANVIL_CHAINID = 31337;

    constructor() {
        if (block.chainid == ETH_MAINNET_CHAINID) {
            s_ActiveConfig = getMainnetEthConfig();
        } else if (block.chainid == ETH_SEPOLIA_CHAINID) {
            s_ActiveConfig = getSepoliaEthConfig();
        } else if (block.chainid == ANVIL_CHAINID) {
            s_ActiveConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getActiveConfig() public view returns (NetworkConfig memory) {
        return s_ActiveConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryFee: 0.01 ether,
                interval: 30,
                subscriptionId: 0,
                hashKey: MAINNET_ETH_GAS_LANE,
                vrfCoordinator: MAINNET_ETH_VRF_COORDINATOR,
                callbackGasLimit: 500000,
                linkToken: MAINNET_LINK_TOKEN,
                deployerAccount: MAINNET_DEPLOYER_ACCOUNT
            });
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryFee: 0.01 ether,
                interval: 30,
                subscriptionId: CHAINLINK_SEPOLIA_SUBSCRIPTION_ID,
                hashKey: SEPOLIA_ETH_GAS_LANE,
                vrfCoordinator: SEPOLIA_ETH_VRF_COORDINATOR,
                callbackGasLimit: 500000,
                linkToken: SEPOLIA_LINK_TOKEN,
                deployerAccount: SEPOLIA_DEPLOYER_ACCOUNT
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        /**
         * Implementation of this function is going to be
         * different from other config getters like getSepoliaEthConfig
         * because other networks have an existing price feed contract.
         * But for this getter, we need to deploy one locally on Anvil,
         * and then get its address.
         *
         * Also, we need to check activeConfig.priceFeed first. If it is
         * NOT null, this means a contract has already been deployed locally.
         * In that case, just return the existing config
         */

        if (s_ActiveConfig.vrfCoordinator != address(0)) {
            return s_ActiveConfig;
        }

        vm.startBroadcast(ANVIL_DEPLOYER_ACCOUNT);
        //vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );

        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        s_ActiveConfig = NetworkConfig({
            entryFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0,
            hashKey: SEPOLIA_ETH_GAS_LANE, //Does'nt matter
            vrfCoordinator: address(vrfCoordinator),
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            deployerAccount: ANVIL_DEPLOYER_ACCOUNT
        });

        return s_ActiveConfig;
    }
}
