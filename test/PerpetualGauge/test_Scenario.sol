// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/PerpetualGauge.sol";


///🦉Scenario Loading...  Follow Comments



// This mock simulates the voting token that was originally   `IERC20 public votingToken;`   in the main contract
//This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockVotingToken is IERC20 {
    mapping(address => uint256) public balances;
    string public name = "Mock";
    string public symbol = "MCK";
    uint8 public decimalsVal = 1;

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
//This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockStratClassifier is IStrategyClassifier {
    function getStrategyRiskLevel(uint256) external pure override returns (uint8) { return 0; }
    function getIndividualCap(uint256) external pure override returns (uint256) { return 10000; } // 100%
    function getGlobalCap(uint8) external pure override returns (uint256) { return 10000; } // 100%
}


// This mock simulates the `IAllocatorProxy` contract to satisfy the constructor
//This contract exists only to satisfy the PerpetualGauge contract's constructor, which is required during test deployment.
contract MockAllocatorProxy is IAllocatorProxy {
    event AllocCalled(uint256 strategyId, uint256 amount);
    function allocate(uint256 strategyId, uint256 amount) external override {
        emit AllocCalled(strategyId, amount);
    }
}




///@dev This mapping should be made public only for testing purposes,
///@dev Only to be able to read its value for testing purposes; otherwise, it has no effect on the function's behavior
///@dev  mapping(uint256 => mapping(uint256 => uint256)) public aggStrategyWeight;


/// @notice Flow 👇🏽
/// First, we have three users.
/// These three users cast votes (and according to the vote function logic, each vote remains active for 365 days before it expires).
/// 200 days pass.
/// Two of the three users update their votes, meaning they cast new votes.
/// The remaining user is inactive and does not update or renew their vote, so they still have 165 days left before expiry.
/// Another 200 days pass.
/// Now for the third user, 400 days have passed, meaning their vote has expired because it was neither updated nor renewed.
/// The other two users are still active because they renewed their votes and still have 165 days remaining.
/// Here is the important part: according to the vote function mechanism, the weights of active votes are recorded in the `aggStrategyWeight` variable for fund allocation or other calculations.
/// However, as you can see, the weights of expired votes are still included in the active vote variable.

///@dev use this ----->  forge test test_Scenario.sol -vv

//test start
contract Test_VoteLogic is Test {

    //creat varibles for mock
    PerpetualGauge Perpetual;// main contract 
    MockVotingToken token;
    MockStratClassifier classifier;
    MockAllocatorProxy allocator;



    /// @notice Here we create three users
    // Two active users
    address ActiveUser1 = address(0x001); // user1
    address ActiveUser2 = address(0x002); // user2
    // One inactive user
    address DeactiveUser = address(0x003); // user3


    function setUp() public {
        token = new MockVotingToken();
        classifier = new MockStratClassifier();
        allocator = new MockAllocatorProxy();

        Perpetual = new PerpetualGauge(address(classifier), address(allocator), address(token));


        // Mint voting tokens for test users 
        // The reason I set the token decimals to 1 is just to simplify calculations; otherwise, it makes no difference
        /// @dev If we used 18 decimals here, the vote weights, which are based on tokens, would also need to be scaled by 18 decimals. For simplicity, I set it to 1 decimal
        /// @dev This has no effect on the function's behavior
        token.mint(ActiveUser1, 1);
        token.mint(ActiveUser2, 1);
        token.mint(DeactiveUser, 1);
    }



    //test
    function test_VoteAddressNotCleared() public {
        


        //ActiveUser1
        //strategy and weight active user 1
        uint256 YTID_ActiveUser1 = 1;   //YieldToken ID
        uint256[] memory SID_ActiveUser1=new uint256[](1);
        SID_ActiveUser1[0] = 10;  // Strategy ID
        uint256[] memory WTS_ActiveUser1=new uint256[](1); 
        WTS_ActiveUser1[0] = 100; // Weight Strategy

        //ActiveUser2
        //strategy and weight active user 2
        uint256  YTID_ActiveUser2 = 2;   //YieldToken ID
        uint256[] memory SID_ActiveUser2=new uint256[](1); 
        SID_ActiveUser2[0] = 20;  // Strategy ID
        uint256[] memory WTS_ActiveUser2=new uint256[](1); 
        WTS_ActiveUser2[0] = 200; // Weight Strategy

        //DeactiveUser
        //strategy and weight deactive user 
        uint256  YTID_DeactiveUser = 3;   //YieldToken ID
        uint256[] memory SID_DeactiveUser=new uint256[](1);  
        SID_DeactiveUser[0] = 30;  // Strategy ID
        uint256[] memory WTS_DeactiveUser=new uint256[](1); 
        WTS_DeactiveUser[0] = 300; // Weight Strategy


        /// @notice Here, each user casts their vote for the first time
        //ActiveUser1
        vm.prank(ActiveUser1); 
        Perpetual.vote(YTID_ActiveUser1, SID_ActiveUser1, WTS_ActiveUser1);

        //ActiveUser2
        vm.prank(ActiveUser2); 
        Perpetual.vote(YTID_ActiveUser2, SID_ActiveUser2, WTS_ActiveUser2);

        //DeactiveUser
        vm.prank(DeactiveUser); 
        Perpetual.vote(YTID_DeactiveUser, SID_DeactiveUser, WTS_DeactiveUser);


        // 200 days passed
        vm.warp(block.timestamp + 200 days);




        /// @notice Now, after 200 days, ActiveUser1 and ActiveUser2 want to renew or update their votes, or cast new ones
        // Creating new votes for ActiveUser1 and ActiveUser2
        /// @notice The new votes are now being cast by both active users
        /// @dev📌 At this stage, the new votes overwrite the old votes, meaning the previous weights and strategies are removed and replaced by the new ones


        //strategy and weight active user 1 
        uint256  YTID_ActiveUser1_New = 1;   //YieldToken ID
        uint256[] memory SID_ActiveUser1_New=new uint256[](1);  
        SID_ActiveUser1_New[0] = 40; // Strategy ID
        uint256[] memory WTS_ActiveUser1_New=new uint256[](1); 
        WTS_ActiveUser1_New[0] = 50; // Weight Strategy

        //strategy and weight active user 2
        uint256  YTID_ActiveUser2_New = 2;   //YieldToken ID
        uint256[] memory SID_ActiveUser2_New=new uint256[](1);  
        SID_ActiveUser2_New[0] = 30; // Strategy ID
        uint256[] memory WTS_ActiveUser2_New=new uint256[](1); 
        WTS_ActiveUser2_New[0] = 50; // Weight Strategy


        // These two users cast their votes again
        //ActiveUser1
        vm.prank(ActiveUser1); 
        Perpetual.vote(YTID_ActiveUser1_New, SID_ActiveUser1_New, WTS_ActiveUser1_New);

        //ActiveUser2
        vm.prank(ActiveUser2); 
        Perpetual.vote(YTID_ActiveUser2_New, SID_ActiveUser2_New, WTS_ActiveUser2_New);


        /// @notice Here we calculate the vote weight of all three users after the first 200 days
        uint256 user1_New = Perpetual.aggStrategyWeight(YTID_ActiveUser1_New, SID_ActiveUser1_New[0]);
        uint256 user2_New = Perpetual.aggStrategyWeight(YTID_ActiveUser2_New, SID_ActiveUser2_New[0]);
        uint256 user3_NotUpdate = Perpetual.aggStrategyWeight(YTID_DeactiveUser, SID_DeactiveUser[0]);// Since this user is inactive, they still retain their original vote weight

        // Now the vote weights of the two active users are summed with the inactive user, which should be
        // 50 + 50 + 300 = 400
        // Up to this point everything is correct, and this weight is stored in the aggStrategyWeight variable in the main contract
        uint256 AllWeight_ = user1_New+user2_New+user3_NotUpdate;
        console.log("All Votes Weight after fist 200 day user1 and user 2 update their votes but user3 didnt -------------->Actived All of them  :", AllWeight_);


        // 200 days again  passed
        vm.warp(block.timestamp + 200 days);
        // Another 200 days pass, and one of the votes belonging to the inactive user expires



        /// @notice  now we sum the users' vote weights again, which should be 100 because only the two active users' weights should be counted, and the inactive user's vote has expired and his weight should be removed,
        // 50 + 50 = 100
        uint256 user1_after_200day = Perpetual.aggStrategyWeight(YTID_ActiveUser1_New, SID_ActiveUser1_New[0]);
        uint256 user2_after_200day = Perpetual.aggStrategyWeight(YTID_ActiveUser2_New, SID_ActiveUser2_New[0]);
        uint256 user3_after400day = Perpetual.aggStrategyWeight(YTID_DeactiveUser, SID_DeactiveUser[0]);

        uint256 AllWeight__ = user1_after_200day+user2_after_200day+user3_after400day;

        /// @notice However, here we see that the inactive user's vote weight is not removed, and the total votes sum up to 400 again
        console.log("tow vote actived but  one expired ------->  But this number is the sum of three votes -----> ", AllWeight__);

        // POC🐧
        assertEq(AllWeight__, 400, "Vote still Exist (ghost vote bug)");

            
    }
}





