// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20 ;
import {TokenPool} from "@ccip/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/ccip/libraries/Pool.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool{

/**
 * 
 * @param _token The address of the token RBT.
 * @param _allowLists  List of allowed tokens.
 * @param _rnmProxy chainlink security contract address
 * @param _router router that is to be deployed on both source and destination chain.
 */
constructor(IERC20 _token, address[] memory _allowLists, address _rmnProxy, address _router) 
TokenPool(_token, _allowLists, _rmnProxy, _router){}

/**
 * @notice Burns the token in the source chain.
 * @param lockOrBurnIn Encoded data fields for the processing of tokens on the source chain.
 * @return lockOrBurnOut Encoded data fields for the processing of tokens on the destination chain.
 */
function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns(Pool.LockOrBurnOutV1 memory lockOrBurnOut){
    //This is crucial for securitychecks in chainLink.
    _validateLockOrBurn(lockOrBurnIn);

    // Decode the original sender's address.
    address originalSender = lockOrBurnIn.originalSender  ;

    //Fetch the user current InterestRate from the rebaseToken
    uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender) ;
    IRebaseToken(address(i_token)).burn(address(this) , lockOrBurnIn.amount) ;

    //Prepare output data for CCIP
    lockOrBurnOut = Pool.LockOrBurnOutV1({
destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector) ,//address of the token contract on the destination chain --> (token)
destPoolData: abi.encode(userInterestRate)  //Encode the userInterestRate to send accross chain ---> (data)
    });
}

/**
 * @notice Releases or mints tokens to the receiver address.
 * @param releaseOrMintIn  All data required to release or mint tokens.
 * @return releaseOrMintOut The amount of tokens released or minted on the local chain, denominated.
 */
function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns(Pool.ReleaseOrMintOutV1 memory){
    _validateReleaseOrMint(releaseOrMintIn) ;
    uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData ,  (uint256)) ;
    IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver , releaseOrMintIn.amount, userInterestRate) ;
    return Pool.ReleaseOrMintOutV1({
        destinationAmount: releaseOrMintIn.amount
    });
}
}