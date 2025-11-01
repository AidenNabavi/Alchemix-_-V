
#  Smart Contract Vulnerability Report
**Alchemix V3**:

##  Vulnerability Title 

VoteWeightsNotReduced 

## 🗂 Report Type

Smart Contract


## 🔗 Target

- https://github.com/alchemix-finance/v3-poc/tree/immunefi_audit/src/PerpetualGauge.sol


## Asset

PerpetualGauge.sol



##  Rating



Severity: High

Impact: High

Likelihood: Medium ~ High

Attack Complexity : Low



##  Description
👇🏽
Although these contracts may be out of the official bug bounty scope, the identified issue reveals a critical flaw in the vote management system of the PerpetualGauge contract🐧


In the this contract, there is a vote function that allows users to allocate their voting power from a specific token pool (MYT) across multiple strategies.

This function calculates each user’s weighted vote based on their token balance and updates the `aggStrategyWeight` mapping, which determines how assets are allocated to strategies.

The problem is that expired votes are not removed automatically. Even after a vote has passed its expiry time, its weight continues to be counted in `aggStrategyWeight`. This can lead to:



##  Impact


Impact on Protocol Integrity:
Expired votes are still counted in `aggStrategyWeight`, causing allocations to strategies to be miscalculated. This can lead to disruptions in capital allocation and reduce the efficiency of the pools.


Financial Risk:
If a large number of expired votes accumulate, the aggregate weights can be artificially inflated, potentially causing allocations to exceed or fall short of the actual intended limits. This can result in financial losses for the protocol.

users who think their votes have expired, while they still influence allocations.



##  Vulnerability Details




```solidity 

    function vote(uint256 ytId, uint256[] calldata strategyIds, uint256[] calldata weights) external nonReentrant {
        require(strategyIds.length == weights.length && strategyIds.length > 0, "Invalid input");

        uint256 lastAdded = lastStrategyAddedAt[ytId];
        Vote storage existing = votes[ytId][msg.sender];
        uint256 expiry;

        if (existing.expiry > block.timestamp) {
            uint256 timeLeft = existing.expiry - block.timestamp;
            if (lastAdded > 0 && block.timestamp - lastAdded < MIN_RESET_DURATION && timeLeft < MIN_RESET_DURATION) {
                
                expiry = existing.expiry;  
            } else {
                expiry = block.timestamp + MAX_VOTE_DURATION;
            }
        } else {
            expiry = block.timestamp + MAX_VOTE_DURATION;
        }

        uint256 power = votingToken.balanceOf(msg.sender);

    
        /// 📌 This is where the problem starts
        // 📌 Here, it first checks whether the vote has not yet expired before performing operations on it
        // 📌 However, as you can see, there is no mechanism to handle expired votes

        // 1. Remove old vote contribution from aggregate
        if (existing.strategyIds.length > 0 && existing.expiry > block.timestamp) {
            for (uint256 i = 0; i < existing.strategyIds.length; i++) {
                uint256 sid = existing.strategyIds[i];
                uint256 prevWeighted = existing.weights[i] * power;
                aggStrategyWeight[ytId][sid] -= prevWeighted;
            }
        }

        // 2. Store new vote
        votes[ytId][msg.sender] = Vote({ strategyIds: strategyIds, weights: weights, expiry: expiry });

        // 3. Add new contribution
        for (uint256 i = 0; i < strategyIds.length; i++) {
            uint256 sid = strategyIds[i];
            uint256 newWeighted = weights[i] * power;
            
            aggStrategyWeight[ytId][sid] += newWeighted;
        }

        // 4. Track voter in registry
        if (voterIndex[ytId][msg.sender] == 0) {
            voters[ytId].push(msg.sender);
            voterIndex[ytId][msg.sender] = voters[ytId].length; // 1-based
        }

        emit VoteUpdated(msg.sender, ytId, strategyIds, weights, expiry);
    }

    
```




##  Proof of Concept (PoC)

Step by Step  POC 

download and run 👇🏽 from this link

``https://github.com/AidenNabavi/Alchemix-_-V``


📌i added two tests for this vulnerability — one is a full attack scenario and the other is just a Proof of Concept


🐧Full Scenario Test in 

    ../test/PerpetualGauge/test_Scenario.sol



🐧just POC Test in 

    ../test/PerpetualGauge/test.sol




```solidity 


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




    
```





## How to fix it (Recommended)

A function should be created so that for those who have already voted once and do not want to renew, update, or cast a new vote, the contract first identifies them in the `vote` function before performing any operations.


```solidity 

function _clearExpiredVotes(uint256 ytId, address voter) internal {
    Vote storage v = votes[ytId][voter];
    if (v.expiry <= block.timestamp && v.strategyIds.length > 0) {
        uint256 power = votingToken.balanceOf(voter);
        for (uint256 i = 0; i < v.strategyIds.length; i++) {
            uint256 sid = v.strategyIds[i];
            aggStrategyWeight[ytId][sid] -= v.weights[i] * power;
        }
        delete votes[ytId][voter];
        emit VoterCleared(voter, ytId);
    }
}

function vote(uint256 ytId, uint256[] calldata strategyIds, uint256[] calldata weights) external nonReentrant {
    require(strategyIds.length == weights.length && strategyIds.length > 0, "Invalid input");

    // Clear expired votes first
    _clearExpiredVotes(ytId, msg.sender);

    uint256 lastAdded = lastStrategyAddedAt[ytId];
    Vote storage existing = votes[ytId][msg.sender];
    uint256 expiry;

    if (existing.expiry > block.timestamp) {
        uint256 timeLeft = existing.expiry - block.timestamp;
        if (lastAdded > 0 && block.timestamp - lastAdded < MIN_RESET_DURATION && timeLeft < MIN_RESET_DURATION) {
            expiry = existing.expiry;  
        } else {
            expiry = block.timestamp + MAX_VOTE_DURATION;
        }
    } else {
        expiry = block.timestamp + MAX_VOTE_DURATION;
    }

    uint256 power = votingToken.balanceOf(msg.sender);

    // Remove old vote contribution from aggregate if still active
    if (existing.strategyIds.length > 0 && existing.expiry > block.timestamp) {
        for (uint256 i = 0; i < existing.strategyIds.length; i++) {
            uint256 sid = existing.strategyIds[i];
            aggStrategyWeight[ytId][sid] -= existing.weights[i] * power;
        }
    }
    ...ادامه کد 

```


## 🔗 References

- https://github.com/alchemix-finance/v3-poc/tree/immunefi_audit/src/PerpetualGauge.sol





