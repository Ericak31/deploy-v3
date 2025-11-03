// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC18 is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**18); // 1M USDC with 18 decimals
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
