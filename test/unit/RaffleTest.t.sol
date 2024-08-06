// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public s_raffle;
    HelperConfig public s_helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCER = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (s_raffle, s_helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = s_helperConfig
            .getConfig();

        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;
    }

    modifier playerEntered() {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCER);
        // Act
        s_raffle.enterRaffle{value: entranceFee}();
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(s_raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEntranceFeeNotEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSend.selector);
        s_raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEnter() public playerEntered {
        // Assert
        assert(s_raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public playerEntered {
        // Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCER);

        vm.expectEmit(true, false, false, false, address(s_raffle));
        emit RaffleEntered(PLAYER);

        s_raffle.enterRaffle{value: entranceFee}();
    }
}
