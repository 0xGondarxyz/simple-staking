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
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
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
}
