// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol"; //For mock testing
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/ccip/libraries/RateLimiter.sol"; 
import {Client} from "@ccip/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test{
    address owner = makeAddr("Owner") ;
    address alice = makeAddr("Alice");
    uint256 SEND_VALUE = 1e5 ;
    uint256 sepoliaFork ; //Fork meaning doing something staying in the particular chain.
    uint256 arbSepoliaFork ;
CCIPLocalSimulatorFork ccipLocalSimulatorFork ; //This is require for mock testing. This creates an simulator for testing ccip.

RebaseToken sepoliaToken ; //The RBT token in sepolia chain
RebaseToken arbSepoliaToken ; //The RBT token in arb sepolia chain
RebaseTokenPool sepoliaPool ; 
RebaseTokenPool arbSepoliaPool ; // We need these pool because the protocol is a rebasetoken so each user might have different interest rates.
Register.NetworkDetails sepoliaNetworkDetails ; 
Register.NetworkDetails arbSepoliaNetworkDetails ; //This registers is like the mock contract for testing crosschain transfer

Vault vault ;

function setUp() external {
address[] memory allowList= new address[](0);

//1. Setup the sepolia and arbs forks.
sepoliaFork = vm.createSelectFork("sepolia-eth") ; //createSelectFork for making sepoliaFork as default.
arbSepoliaFork = vm.createFork("arb-sepolia") ;

ccipLocalSimulatorFork = new CCIPLocalSimulatorFork() ;
vm.makePersistent(address(ccipLocalSimulatorFork)) ; //ensures the specified contract address,code and storage are preserved across different fork test during execution.

//2. Deploy and configure on source Chain:  sepolia.
sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid) ;
vm.startPrank(owner);
sepoliaToken= new RebaseToken();
//deploy the vault and set rewardBalance for the vault
vault = new Vault(IRebaseToken(address(sepoliaToken)));
vm.deal(address(vault), 1e18);
//deploy the sepolia pool 
sepoliaPool = new RebaseTokenPool(IERC20(address(sepoliaToken)), allowList, sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress) ;
sepoliaToken.grantMintAndBurnRole(address(vault));
sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));

//claim role in sepolia
RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken)) ;
//accept role in sepolia
TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
//link token to pool in the token admin registry in sepolia
TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken),address(sepoliaPool));
vm.stopPrank();


//3. Deploy and configure on destination chain: arb-sepolia.
vm.selectFork(arbSepoliaFork);
vm.startPrank(owner);
arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid) ;
//deploy the token and tokenpool in sepolia
arbSepoliaToken = new RebaseToken();
arbSepoliaPool = new RebaseTokenPool(IERC20(address(arbSepoliaToken)), allowList, arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress) ;
arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));

//claim role in arbitrum
RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken)) ;
//accept role in arbitrum
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
//link token to pool in the token admin registry in sepolia
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken),address(arbSepoliaPool));
vm.stopPrank();

configureTokenPool(sepoliaFork, address(sepoliaPool), arbSepoliaNetworkDetails.chainSelector, true, address(arbSepoliaPool),address(arbSepoliaToken)) ;
configureTokenPool(arbSepoliaFork, address(arbSepoliaPool), sepoliaNetworkDetails.chainSelector, true, address(sepoliaPool),address(sepoliaToken)) ;
}

/**
 * @notice Telling one pool how to talk to another pool
 * @param _fork  Staying on which chain to operate on. Selecting the source chain.
 * @param _localPool Address of the rebaseTokenPool contract on source chain 
 * @param _remoteChainSelector chainId of destination chain
 * @param _allowed Is the token allowed or not
 * @param _remotePool rebasePool contract address of remoteChain(Destination)
 * @param _remoteTokenAddress RBT token address on remoteChain (Destination)
 */
function configureTokenPool(uint256 _fork, address _localPool, uint64 _remoteChainSelector,bool _allowed, address _remotePool,address _remoteTokenAddress ) public {
    vm.selectFork(_fork) ;
    vm.prank(owner);
 
    TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1) ;
    
    chainsToAdd[0]=TokenPool.ChainUpdate({
remoteChainSelector:_remoteChainSelector, 
allowed:_allowed, 
remotePoolAddress: abi.encode(_remotePool),
remoteTokenAddress: abi.encode(_remoteTokenAddress),
outboundRateLimiterConfig : RateLimiter.Config({
    isEnabled:false,capacity:0,rate:0
}),
inboundRateLimiterConfig: RateLimiter.Config({
        isEnabled:false,capacity:0,rate:0
})
    });
  
TokenPool(_localPool).applyChainUpdates(chainsToAdd);
}

function bridgeToken(
    uint256 _amtToBridge,
 uint256 _localFork,
uint256 _remoteFork,
 Register.NetworkDetails memory _localNetworkDetails,
Register.NetworkDetails memory _remoteNetworkDetails,
 RebaseToken _localToken,
RebaseToken _remoteToken) public 
{
vm.selectFork(_localFork);

Client.EVMTokenAmount[] memory tokenAmount = new Client.EVMTokenAmount[](1);
tokenAmount[0] = Client.EVMTokenAmount({token:address(_localToken) , amount:_amtToBridge});

Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
receiver : abi.encode(alice),
data: "",
tokenAmounts: tokenAmount,
feeToken: _localNetworkDetails.linkAddress,
extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({
gasLimit:500_000
}))
});

uint256 fee = IRouterClient(_localNetworkDetails.routerAddress).getFee(_remoteNetworkDetails.chainSelector,message) ;

ccipLocalSimulatorFork.requestLinkFromFaucet(alice , fee);

vm.prank(alice);
IERC20(_localNetworkDetails.linkAddress).approve(_localNetworkDetails.routerAddress, fee);

vm.prank(alice);
IERC20(address(_localToken)).approve(_localNetworkDetails.routerAddress,fee);

uint256 localTokenBalanceBefore  = _localToken.balanceOf(address(alice));
vm.prank(alice);
IRouterClient(_localNetworkDetails.routerAddress).ccipSend(_remoteNetworkDetails.chainSelector, message);
uint256 localTokenBalanceAfter = _localToken.balanceOf(address(alice));
assertEq(localTokenBalanceAfter , localTokenBalanceBefore-_amtToBridge);
uint256 localUserInterestRate = _localToken.getUserInterestRates(address(alice)) ;

vm.selectFork(_remoteFork);
vm.warp(block.timestamp + 20 minutes);
uint256 remoteTokenBalance = _remoteToken.balanceOf(address(alice)) ;

vm.selectFork(_localFork);
ccipLocalSimulatorFork.switchChainAndRouteMessage(_remoteFork);
uint256 remoteTokenBalanceAfter = _remoteToken.balanceOf(address(alice));
assertEq(remoteTokenBalanceAfter, remoteTokenBalance + _amtToBridge);
assertEq(localUserInterestRate,  _remoteToken.getUserInterestRates(address(alice)));
}

function testBridgeAllTokens() external {
vm.selectFork(sepoliaFork);
vm.deal(alice,SEND_VALUE);
vm.prank(alice);
Vault(payable(address(vault))).deposit{value:SEND_VALUE}();
assertEq(sepoliaToken.balanceOf(alice), SEND_VALUE) ;
bridgeToken(SEND_VALUE,  sepoliaFork, arbSepoliaFork,sepoliaNetworkDetails , arbSepoliaNetworkDetails, sepoliaToken, arbSepoliaToken) ;


vm.warp(block.timestamp + 30 minutes);

vm.selectFork(arbSepoliaFork);
assertGt(arbSepoliaToken.balanceOf(alice) , SEND_VALUE);
bridgeToken(arbSepoliaToken.balanceOf(alice), arbSepoliaFork,sepoliaFork, arbSepoliaNetworkDetails, sepoliaNetworkDetails ,arbSepoliaToken, sepoliaToken) ;

}
}