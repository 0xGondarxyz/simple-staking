// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStaking} from "../src/SimpleStaking.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Create a simple mock ERC20 token for testing
contract MockRewardToken is ERC20 {
    constructor() ERC20("Reward Token", "RWD") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1 million tokens
    }
}

contract SimpleStakingTest is Test {
    SimpleStaking public staking;
    MockRewardToken public rewardToken;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // Deploy reward token
        rewardToken = new MockRewardToken();

        // Deploy staking contract with 10% APY
        staking = new SimpleStaking(address(rewardToken), 10); // 10 = 10% annual reward

        // Fund the staking contract with reward tokens
        rewardToken.transfer(address(staking), 100000 * 10 ** 18);

        // Give users some ETH for staking
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_Deployment() public view {
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertEq(staking.annualRewardPercent(), 10);
        assertEq(staking.owner(), owner);
    }

    function test_CanReceiveETH() public {
        vm.startPrank(user1);
        // Use a low-level call to send ETH to the contract
        (bool success,) = address(staking).call{value: 1 ether}("");
        assertEq(success, true);
        assertEq(address(staking).balance, 1 ether);
        vm.stopPrank();
    }

    //test calculateRewards
    function test_CalculateRewards() public view {
        uint256 stakedAmount = 100 ether;
        uint256 timeStaked = 365 days;
        uint256 expectedRewards = 10 ether;
        assertEq(staking.calculateRewards(stakedAmount, timeStaked), expectedRewards);
    }

    function test_stake() public {
        vm.startPrank(user1);
        staking.stake{value: 1 ether}();

        // Destructure the struct into variables
        (uint256 stakedAmount, uint256 rewardsEarned, uint256 lastUpdateTime) = staking.stakes(user1);

        assertEq(stakedAmount, 1 ether);
        assertEq(staking.totalStaked(), 1 ether);
        assertEq(rewardsEarned, 0);
        assertEq(lastUpdateTime, block.timestamp);
        //check the contract balance
        assertEq(address(staking).balance, 1 ether);
        vm.stopPrank();
    }

    function test_stake_and_unstake() public {
        vm.startPrank(user1);
        staking.stake{value: 1 ether}();
        (uint256 stakedAmount, uint256 rewardsEarned, uint256 lastUpdateTime) = staking.stakes(user1);

        assertEq(stakedAmount, 1 ether);
        assertEq(staking.totalStaked(), 1 ether);
        //10 days pass
        vm.warp(block.timestamp + 10 days);
        staking.unstake();
        (uint256 stakedAmountAfterUnstake,,) = staking.stakes(user1);
        assertEq(stakedAmountAfterUnstake, 0);
        assertEq(staking.totalStaked(), 0);
        vm.stopPrank();
    }

    function test_stake_and_withdraw() public {
        vm.startPrank(user1);
        staking.stake{value: 10 ether}();
        (uint256 stakedAmount, uint256 rewardsEarned, uint256 lastUpdateTime) = staking.stakes(user1);

        assertEq(stakedAmount, 10 ether);
        assertEq(staking.totalStaked(), 10 ether);
        //10 days pass
        vm.warp(block.timestamp + 10 days);
        staking.withdrawETH(5 ether);
        (uint256 stakedAmountAfterWithdraw,,) = staking.stakes(user1);
        assertEq(stakedAmountAfterWithdraw, 5 ether);
        assertEq(staking.totalStaked(), 5 ether);
        vm.stopPrank();
    }

    function test_stake_and_claim() public {
        vm.startPrank(user1);
        //stake 10 ether, wait 1 year, claim rewards
        staking.stake{value: 10 ether}();
        vm.warp(block.timestamp + 365 days);
        //the reward should be 10% of 10 ether
        //get user balance of reward token
        uint256 rewardsEarned = staking.pendingRewards(user1);
        staking.claimRewards();
        assertEq(rewardsEarned, 1 ether);
        vm.stopPrank();
    }
}
