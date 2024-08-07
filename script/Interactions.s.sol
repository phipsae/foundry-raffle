// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console.log(
            "Creating subscription using vrfCoordinator: %s",
            vrfCoordinator
        );
        console.log("On chainid: %s", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Your subsrciption Id is: %s", subId);
        return (subId, vrfCoordinator);
    }

    // addressToCreateSub: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
    // linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789 - Transfer And Call

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant LINK_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkAddress;
        fundSubscription(vrfCoordinator, subId, linkToken);
    }

    function fundSubscription(
        address _vrfCoordinator,
        uint256 _subId,
        address _linkToken
    ) public {
        console.log("Funding subscription", _subId);
        console.log("Using vrfCoordinator", _vrfCoordinator);
        console.log("On ChainId", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(
                _subId,
                LINK_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_linkToken).transferAndCall(
                _vrfCoordinator,
                LINK_AMOUNT,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
        // Fund subscription
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(
        address _mostRecentlyDeployedContract
    ) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;

        addConsumer(vrfCoordinator, subId, _mostRecentlyDeployedContract);
    }

    function addConsumer(
        address _vrfCoordinator,
        uint256 _subId,
        address _consumer
    ) public {
        console.log("Adding consumer to subId", _subId);
        console.log("Adding consumer to vrfCord", _vrfCoordinator);
        console.log("On ChainId", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subId, _consumer);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployedContract = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedContract);
    }
}
