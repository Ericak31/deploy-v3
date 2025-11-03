// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "../src/SSV.sol";
import "forge-std/Script.sol";

contract DeploySSV is Script {
    function run() external {
        vm.startBroadcast();
        
        SSV ssv = new SSV("SSV Token", "SSV", 1000000 * 1e18);
        
        console.log("SSV deployed to:", address(ssv));
        
        vm.stopBroadcast();
    }
}

