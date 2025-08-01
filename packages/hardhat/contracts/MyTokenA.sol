// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MyTokenA is ERC20 {
    constructor() ERC20("MJPtokenA", "MJP_TKA"){	
        // for testing purposes, when using remix, we can mint some tokens to the deployer address
        _mint(msg.sender,700000e18);
               //address del verifier o del simple swap segun se use con uno u otro  _mint(address(0xd9145CCE52D386f254917e481eB44e9943F39138),700000e18);
       // _mint(address(this),1500e6);
   
    } 


     /// @notice Mints new tokens to a specified address.    
    function mint(address to, uint256 amount) public {
        require(to != address(0), "Cannot mint to the zero address");
        _mint(to, amount);
    }

    
    function getAddress() public view returns (address) {return msg.sender;}
   
    function getBalance() public view returns (uint){return balanceOf( msg.sender ); }
   
    function getTokenAAddress() public view returns (address) {
        return address(this);
    }
    
    function getTokenABalance()public view returns (uint) {
    return balanceOf(address(this));   }

}
