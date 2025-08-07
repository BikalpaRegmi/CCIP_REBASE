// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20 ;

interface IRebaseToken {
    function mint(address _to , uint256 _amnt) external ;
    function burn(address _to , uint256 _amt) external ;
    function balanceOf(address _user) external returns(uint256) ;
}