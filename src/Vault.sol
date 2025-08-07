// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20 ;
import {RebaseToken} from "./RebaseToken.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    //we need to pass the rebase token as a constructor.abi
    //we need to make a deposit function and mint the RBT and gain eth
    //we need to make a redeem function that gives eth back to user and burn the RBT
    //we need to add a way to add rewards to the vault

IRebaseToken private immutable i_rebaseToken;

event Deposit(address user, uint256 value) ;
event Redeem(address user , uint256 value);
    constructor(IRebaseToken _rebaseToken) {
 i_rebaseToken = _rebaseToken ;
    }

/**
 * @notice redeem RBT and give Ethers.
 */
    function deposit() external payable{
        i_rebaseToken.mint(msg.sender , msg.value) ;
        emit Deposit(msg.sender , msg.value) ;
    }

/**
 * @notice redeem eth and burn the RBT
 * @param _amount amount of RBT to redeem.
 */
    function redeem(uint256 _amount) external{
        if(_amount == type(uint256).max){
   _amount = i_rebaseToken.balanceOf(msg.sender) ;
}
        i_rebaseToken.burn(msg.sender ,_amount) ;
        (bool sucess,) = payable(msg.sender).call{value:_amount}("") ;
         require(sucess , "Didn't Passed") ;
         emit Redeem(msg.sender , _amount) ;
    }

receive() external payable{}

/**
 * @notice returns the address of rebase token.
 */
    function getRebaseToken() external view returns(address){
        return address(i_rebaseToken) ;
    }
}