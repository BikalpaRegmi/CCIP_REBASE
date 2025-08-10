// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20 ;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Bikalpa Regmi 
 * @notice This contract is a ERC20 cross-chain rebase token that incentivises users to deposit into a vault & gain intrest as reward into a vault.
 * @notice The intrest rate in the smart contract can only decrease.
 * @notice The Each user will have thier own intrest rate that is set to global intrest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl{

error RebaseToken__NewInterestRateCanOnlyDecrease(uint256 old_interest, uint256 new_interest) ;

 uint256 private s_intrestRate = 5e10 ; // The interest Rate per second.(0.00005%)
 uint256 constant PRECISION_FACTOR = 1e18 ;
 bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_GRANT_ROLE") ;
mapping(address=>uint256) private s_userInterestRates ;
mapping(address=>uint256) private s_userLastupdatedTimestamp ;

 event NewInterestRate(uint256 newinterestrate) ;
 constructor() ERC20("Rebase Token","RBT") Ownable(msg.sender){}

function grantMintAndBurnRole(address _accnt) external onlyOwner{
    _grantRole(MINT_AND_BURN_ROLE , _accnt) ;
}

/**
 * @notice set the new global interestRate in the contract.
 * @param _intrestRate The new Interest Rate.
 * @notice The interestRate can only decrease
 */
 function _setInterestate(uint256 _intrestRate) external onlyOwner{
    if(s_intrestRate <= _intrestRate){
        revert RebaseToken__NewInterestRateCanOnlyDecrease( s_intrestRate ,  _intrestRate);
    }
    s_intrestRate = _intrestRate ;

    emit NewInterestRate(_intrestRate) ;
 }

/**
 * @notice mints the user RBT.
 * @param _to address whome we are minting
 * @param _amnt amount how much we are minting
 * @param _userInterestRate setting userInterest as the owner decides in the vault but on bridge by sending via poolData
 */
 function mint(address _to , uint256 _amnt, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE){
    _mintAccuredInterest(_to);
    s_userInterestRates[_to] = _userInterestRate ;
    _mint(_to , _amnt) ;

 }

/**
 * @notice Burn the user token when they withdraw from the vault.
 * @param _form the user to burn the token from
 * @param _amt the amount of token to burn
 */
 function burn(address _form , uint256 _amt) external onlyRole(MINT_AND_BURN_ROLE){

 _mintAccuredInterest(_form) ;
 _burn(_form , _amt) ;
 
 }

/**
 * @notice Transfer token from one to another.
 * @param _receipent The address of receiver of the RBT
 * @param _amt The amount of tokens to transfer
 */
 function transfer(address _receipent , uint256 _amt) public override returns(bool){
    _mintAccuredInterest(msg.sender);
    _mintAccuredInterest(_receipent);

    if(_amt == type(uint256).max){
        _amt = balanceOf(msg.sender) ;
    }

    if(balanceOf(_receipent) == 0){
        s_userInterestRates[_receipent] = s_userInterestRates[msg.sender] ; 
    }

    return super.transfer(_receipent , _amt) ;
 }

/**
 * @notice Send the RBT from sender to receipeint.
 * @param _sender the address of the sender of RBT
 * @param _receipent the address of the receiver of RBT
 * @param _amt the amount of RBT
 */
 function transferFrom(address _sender , address _receipent , uint256 _amt) public override returns(bool){
    _mintAccuredInterest(_sender);
    _mintAccuredInterest(_receipent);

    if(_amt == type(uint256).max){
        _amt = balanceOf(msg.sender) ;
    }

    if(balanceOf(_receipent) == 0){
        s_userInterestRates[_receipent] == s_userInterestRates[_sender] ;
    }

    return super.transferFrom(_sender , _receipent, _amt) ;
 }

/**
 * @notice Returns the total ERC20 balance of user including the intrest accured on his balance.
 * @param _user The address of user to see balance.
 */
function balanceOf(address _user) public view override returns(uint256) {
 // get the current principle balance (The number of tokens that actually have been minted to the user.)
// multiply the principle balance with the interestRate that has been accumulated at the time since the balance was last updated. (principle*interestRate)
return (super.balanceOf(_user) * _calculateaccumulatedInterestOfUserSinceLastUpdate(_user)) / PRECISION_FACTOR ;
}

/**
 * @notice returns the ERC20 balance of user without including the intrest accured on his balance.
 * @param _user the address of user
 */
function principleBalanceOf(address _user) external view returns (uint256){
    return super.balanceOf(_user);
}

/**
 * @notice The current interestRate set by owner. 
 */
function getInterestRates() external view returns(uint256){
    return s_intrestRate ;
}

/**
 * @notice Calculates and returns the linear interest rate aka simpleInterestRate.
 * @param _user The address of user
 */
function _calculateaccumulatedInterestOfUserSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
//1. Calculate the time since the last update.
uint256 timeElapsed = block.timestamp - s_userLastupdatedTimestamp[_user] ;
//2. Calculate the amount of linear growth. 
// (principle + principle*interestRate*TimeElapsed)
// Taking common : principle * (1 + interesteRate * TimeElapsed)
linearInterest = PRECISION_FACTOR + (s_userInterestRates[_user] * timeElapsed)  ;

}

/**
 * @notice Calculate the interest rate that has been accumulated since the last update.
 * @param _to address of the user
 */
function _mintAccuredInterest(address _to) internal {
    //1) Find the current balance of rebase token that has been minted to them. --> principle balance
     uint256 previousBalance = super.balanceOf(_to) ;
    //2) Calculate thier current balance including thier interest. --> balanceOf
     uint256 TotalBalanceAfterIntrest = balanceOf(_to) ;
    //3) Calculate the number of token that need to be minted to the user --> 2-1
     uint256 accuredAmountToMint = TotalBalanceAfterIntrest-previousBalance ;

    // Set the user last updated timestamp.
    s_userLastupdatedTimestamp[_to] = block.timestamp ;
    
    // Call _mint to mint the token to the users.
     _mint(_to , accuredAmountToMint) ;
}

/**
 * @notice Gets the interestRate when user deposited.
 * @param _user the user address
 */
 function getUserInterestRates(address _user) external view returns(uint256){
    return s_userInterestRates[_user] ;
 }
}