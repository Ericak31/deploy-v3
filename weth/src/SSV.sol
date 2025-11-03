// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SSV is ERC20 {
    constructor(string memory n, string memory s, uint256 supply) ERC20(n, s) {
        _mint(msg.sender, supply);
    }
    
    function burn(address account, uint256 value) public {
        _burn(account, value);
    }

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }
}
