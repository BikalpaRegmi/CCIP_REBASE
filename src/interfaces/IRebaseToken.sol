// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20 ;

interface IRebaseToken {
    function mint(address _to , uint256 _amnt , uint256 _userInterestRate) external ;
    function burn(address _to , uint256 _amt) external ;
    function balanceOf(address _user) external returns(uint256) ;
    function getUserInterestRates(address _user) external view returns(uint256);
    function getInterestRates() external view returns(uint256);
}