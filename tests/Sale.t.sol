pragma solidity ^0.8.23;

import "forge-std/Test.sol";

contract SaleContractTests is Test {
    
    address user;
    
    function setUp() public {
        user = address(1);
    }

    function testUser() public view {
        assertEq(user, address(1));
    }
}