// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PerpetualGauge.sol";

// This mock simulates the `IERC20` token to satisfy the PerpetualGauge constructor
// This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockVotingToken is IERC20 {
    mapping(address => uint256) public balances;
    string public name = "Mock";
    string public symbol = "MCK";
    uint8 public decimalsVal = 18;

    function totalSupply() external pure override returns (uint256) { return 0; }
    function balanceOf(address account) external view override returns (uint256) { return balances[account]; }
    function allowance(address, address) external pure override returns (uint256) { return 0; }
    function transfer(address, uint256) external pure override returns (bool) { revert(); }
    function approve(address, uint256) external pure override returns (bool) { revert(); }
    function transferFrom(address, address, uint256) external pure override returns (bool) { revert(); }

    function mint(address who, uint256 amount) external {
        balances[who] = balances[who] + amount;
    }
}

// This mock simulates the `IStrategyClassifier` contract to satisfy the constructor
// This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockStratClassifier is IStrategyClassifier {
    function getStrategyRiskLevel(uint256) external pure override returns (uint8) { return 0; }
    function getIndividualCap(uint256) external pure override returns (uint256) { return 10000; } // 100%
    function getGlobalCap(uint8) external pure override returns (uint256) { return 10000; } // 100%
}

// This mock simulates the `IAllocatorProxy` contract to satisfy the constructor
// This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockAllocatorProxy is IAllocatorProxy {
    event AllocCalled(uint256 strategyId, uint256 amount);
    function allocate(uint256 strategyId, uint256 amount) external override {
        emit AllocCalled(strategyId, amount);
    }
}







///@dev use this ------> forge test test.sol -vvv

contract Test_Vote is Test {
    PerpetualGauge Perpetual;
    MockVotingToken token;
    MockStratClassifier classifier;
    MockAllocatorProxy allocator;

    uint256 constant YieldTokenID = 1;   // ID of a specific token or yield pool
    uint256 constant STID = 10;          // ID of a specific strategy to be registered or allocated in the test

    address user = address(0x001);

    function setUp() public {
        token = new MockVotingToken();
        classifier = new MockStratClassifier();
        allocator = new MockAllocatorProxy();

        Perpetual = new PerpetualGauge(address(classifier), address(allocator), address(token));

        token.mint(user, 1e18); // 1 token (with 18 decimals)
    }

    // This function is made public only to be shown in tests, nothing else
    // mapping(uint256 => mapping(uint256 => uint256)) public aggStrategyWeight;

    function test_VoteAddressNotCleared() public {

        /// @notice This sets up a vote dataset
        uint256[] memory sids=new uint256[](1);
        sids[0] = STID; // ID 
        uint256[] memory wts=new uint256[](1);
        wts[0] = 100; // weight


        // User casts a vote
        vm.prank(user); 
        Perpetual.vote(YieldTokenID, sids, wts);


        // Here we check the user's vote weight before 365 days
        // Why 365 days?
        // According to the PerpetualGauge logic, votes are active for 365 days if not updated or renewed 📌
        uint256 beforeWeight = Perpetual.aggStrategyWeight(YieldTokenID, sids[0]); // vote weight


        /// @notice Now more than 365 days pass, and the vote has expired
        // User has not renewed, updated, or cast a new vote
        vm.warp(block.timestamp + 367 days);


        // 🐧 Check if the user's vote still exists even though it has expired
        uint256 afterWeight = Perpetual.aggStrategyWeight(YieldTokenID, sids[0]);

        // 🐧 As you can see, the user's vote still exists despite being expired
        console.log("Vote weight before 367 days --------------> Active :", beforeWeight);
        console.log("Vote weight after 367 days --------------> Expired :", afterWeight);

        // Expired vote still counted → indicates a bug
        assertEq(beforeWeight, afterWeight, "Vote still exists (ghost vote bug)");
    }
}




