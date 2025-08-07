// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20 ;

import {Test} from "forge-std/Test.sol" ;
import {RebaseToken} from "../src/RebaseToken.sol" ;
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol" ;
import {Vault} from "../src/Vault.sol" ;
import {console} from "forge-std/console.sol";

contract RebaseTokenTest is Test{
RebaseToken private rebaseToken ;
Vault private vault ;
address private alice ;
address private bob ;

function setUp() external {
    rebaseToken = new RebaseToken() ;
    vault = new Vault(IRebaseToken(address(rebaseToken))) ;
    alice = makeAddr("alice");
    bob = makeAddr("bob");
}

function addRewardToVault(uint256 _rewardAmt) public {
 (bool sucess ,) = payable(address(vault)).call{value:_rewardAmt}("");
 require(sucess , "adding reward Amount failed") ; 
}

function test_GrantMintRoleAndBurn(uint256 _amt) external{
    _amt = bound(_amt , 1 , 1000);
    rebaseToken.grantMintAndBurnRole(address(alice)) ;
    
    vm.prank(alice);
    rebaseToken.mint(bob , _amt) ;

    assertEq(rebaseToken.balanceOf(bob) , _amt);

    vm.prank(bob);
    vm.expectRevert();
    rebaseToken.burn(bob , _amt);

    vm.prank(alice);
    rebaseToken.burn(bob , _amt);

    assertEq(rebaseToken.balanceOf(bob) , 0) ;
   
}

 function test_setInterestRate(uint256 _amt) external {
    _amt = bound(_amt , 1 , 4.9e10) ;
    rebaseToken._setInterestate(_amt);

vm.prank(alice);
vm.expectRevert();
rebaseToken._setInterestate(_amt);

    assertEq(rebaseToken.getInterestRates() , _amt);
 }

 function test_depositLinear(uint256 _amt) external {
    _amt = bound(_amt, 1e5, type(uint96).max) ;
    rebaseToken.grantMintAndBurnRole(address(vault)) ;

vm.startPrank(alice) ;
vm.deal(alice , _amt);
vault.deposit{value:_amt}();

uint256 initialBalance = rebaseToken.balanceOf(alice);
console.log("Initial balance: ",initialBalance) ;
console.log("initial timestamp",block.timestamp);
assertEq(initialBalance,_amt) ;

vm.warp(block.timestamp + 1 hours) ;
uint256 middleBalance = rebaseToken.balanceOf(alice) ;
console.log("Middle balance: ",middleBalance);
console.log("middle timestamp",block.timestamp) ;
assertGt(middleBalance , initialBalance) ;

vm.warp(block.timestamp + 1 hours);
uint256 finalBalance = rebaseToken.balanceOf(alice);
console.log("Final banalce: " , finalBalance) ;
console.log("Final timestamp",block.timestamp);
assertGt(finalBalance , middleBalance) ;

assertApproxEqAbs(finalBalance-middleBalance , middleBalance-initialBalance,1) ;
vm.stopPrank() ;
 }


function test_redeemStraightAway(uint256 _amt) external {
_amt = bound(_amt , 1e5 , type(uint96).max);
rebaseToken.grantMintAndBurnRole(address(vault));

vm.startPrank(alice);
vm.deal(alice , _amt);
vault.deposit{value:_amt}();

assertEq(rebaseToken.balanceOf(alice) , _amt) ;

vault.redeem(type(uint256).max) ;
vm.stopPrank();
assertEq(rebaseToken.balanceOf(alice) , 0) ;
assertEq(address(alice).balance , _amt) ;
}

function test_redeemTimePassed(uint256 _time , uint256 _amt) external {
_time = bound(_time , 1000, type(uint96).max);
_amt = bound(_amt , 1e5 , type(uint96).max);
rebaseToken.grantMintAndBurnRole(address(vault)) ;
vm.deal(alice , _amt);


vm.prank(alice);
vault.deposit{value:_amt}();

vm.warp( _time);

uint256 balance = rebaseToken.balanceOf(alice) ;

vm.deal(address(this), balance - _amt);
addRewardToVault(balance - _amt);

vm.prank(alice);
vault.redeem(balance);


uint256 balanceOfAliceInEth = address(alice).balance;

assertEq(balanceOfAliceInEth , balance);
assertGt(balanceOfAliceInEth , _amt);
}


function test_Transfer(uint256 _amt , uint256 _amt2send) external {
_amt = bound(_amt , 1e5+1e3 , type(uint96).max) ; 
_amt2send  = bound(_amt2send , 1e5 , _amt-1e3) ; 
rebaseToken.grantMintAndBurnRole(address(vault)) ;

vm.deal(alice , _amt) ;

vm.prank(alice);
vault.deposit{value:_amt}();

vm.warp(block.timestamp + 1 days) ;
vm.prank(alice) ;
rebaseToken.transfer(address(bob),_amt2send);

assertEq(rebaseToken.balanceOf(address(bob)) , _amt2send) ;
assertEq(rebaseToken.getUserInterestRates(address(bob)) , rebaseToken.getUserInterestRates(alice));

vm.warp(block.timestamp + 2 days) ;

vm.prank(alice) ;
rebaseToken.transfer(address(bob) , type(uint256).max) ;

assertEq(rebaseToken.balanceOf(alice) , 0) ;
assertGt(rebaseToken.balanceOf(bob) , _amt) ;

vm.expectRevert();
rebaseToken._setInterestate(4e18) ;

vm.prank(address(bob));
vm.expectRevert();
rebaseToken._setInterestate(4.5e10) ;

rebaseToken._setInterestate(4.5e10) ;

vm.prank(bob);
rebaseToken.approve(address(this), _amt);

rebaseToken.transferFrom(address(bob) , address(alice) , _amt2send) ;

assertEq(rebaseToken.getUserInterestRates(alice) , uint256(5e10)) ;
assertEq(rebaseToken.getInterestRates() , 4.5e10) ;
assertEq(rebaseToken.balanceOf(alice), _amt2send) ;
}

function test_getPrincipleAmt(uint256 _amt) external{
    _amt = bound(_amt , 1e5 ,  type(uint96).max) ;
 rebaseToken.grantMintAndBurnRole(address(alice)) ;

    vm.startPrank(alice) ;
    rebaseToken.mint(address(alice) , _amt) ;
    vm.stopPrank();

    vm.warp(block.timestamp+5 days);

    assertGt(rebaseToken.balanceOf(address(alice)) , _amt) ;
    assertEq(rebaseToken.principleBalanceOf(address(alice)) , _amt);
}

}