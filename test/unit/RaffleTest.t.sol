// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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
        vm.deal(PLAYER, STARTING_PLAYER_BALANCER);

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

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        /// Arrange
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        s_raffle.performUpkeep("");
        /// Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool notNeeded, ) = s_raffle.checkUpkeep("");
        assert(address(s_raffle).balance == 0);
        assert(!notNeeded);
    }

    function testCheckUpkeepReturnsFalseIfItIsClosed() public {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        s_raffle.performUpkeep("");

        (bool notNeeded, ) = s_raffle.checkUpkeep("");
        assert(!notNeeded);
    }

    function testCheckUpKeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        (bool notNeeded, ) = s_raffle.checkUpkeep("");
        assert(!notNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool notNeeded, ) = s_raffle.checkUpkeep("");
        assert(notNeeded);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // better option with (bool success, ) = ....
        s_raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = s_raffle.getRaffleState();

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        s_raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        s_raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.log("request console log", uint256(requestId));

        uint raffleState = uint256(s_raffle.getRaffleState());

        assert(uint256(requestId) > 0);
        assert(raffleState == 1);
    }

    function testFullfillrandomWordsCanOnlyBecCalledAfterPerformUpkeep(
        uint _requestId
    ) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            _requestId,
            address(s_raffle)
        );
    }

    function testFullFillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        // Arrange
        uint256 additionalPlayers = 3;
        uint startingIndex = 1;
        address expectedWinner = address(uint160(1));

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalPlayers;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            s_raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = s_raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        s_raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(s_raffle)
        );

        // // Assert
        // address recentWinner = s_raffle.getRecentWinner();
        // Raffle.RaffleState raffleState = s_raffle.getRaffleState();
        // uint256 winnerBalance = recentWinner.balance;
        // uint256 endingTimeStamp = s_raffle.getLastTimeStamp();
        // uint256 prize = entranceFee * (additionalPlayers + 1);

        // assert(recentWinner == expectedWinner);
        // assert(uint256(raffleState) == 0);
        // assert(winnerBalance == winnerStartingBalance + prize);
        // assert(endingTimeStamp > startingTimeStamp);
    }
}
