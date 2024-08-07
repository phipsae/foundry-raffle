// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /* Chainlink VRF Mock Values */
    uint96 public constant Mock_BASE_FEE = 0.25 ether;
    uint96 public constant Mock_GAS_PRICE_LINK = 20000000000;
    // Link / ETH price
    int256 public constant Mock_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address linkAddress;
    }

    NetworkConfig private s_localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) private s_networkConfigs;

    constructor() {
        s_networkConfigs[
            CodeConstants.ETH_SEPOLIA_CHAIN_ID
        ] = getSepoliaEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (s_networkConfigs[chainId].vrfCoordinator != address(0)) {
            return s_networkConfigs[chainId];
        } else if (chainId == CodeConstants.LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000, //500k gas
                subscriptionId: 0 /* 72930174600464389131371894255741454145387163935706469072633650155059978515261,*/,
                linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (s_localNetworkConfig.vrfCoordinator != address(0)) {
            return s_localNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            Mock_BASE_FEE,
            Mock_GAS_PRICE_LINK,
            Mock_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        // console.log("HERE", address(vrfCoordinatorMock));
        s_localNetworkConfig = NetworkConfig({
            entranceFee: 0.001 ether,
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            // doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, //500k gas
            subscriptionId: 0,
            linkAddress: address(linkToken)
        });
        console.log(s_localNetworkConfig.vrfCoordinator);
        return s_localNetworkConfig;
    }
}
