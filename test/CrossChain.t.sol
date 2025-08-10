// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract CrossChainTest is Test{
    address owner = makeAddr("Owner") ;
    uint256 sepoliaFork ;
    uint256 arbSepoliaFork ;
CCIPLocalSimulatorFork ccipLocalSimulatorFork ; //This is require for mock testing. This is an simupator for testing ccip.

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
vm.makePersistent(address(ccipLocalSimulatorFork)) ;

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
arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid) ;
vm.startPrank(owner);
//deploy the token and tokenpool in sepolia
arbSepoliaToken = new RebaseToken();
arbSepoliaPool = new RebaseTokenPool(IERC20(address(arbSepoliaPool)), allowList, arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress) ;
arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
//claim role in arbitrum
RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken)) ;
//accept role in arbitrum
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
//link token to pool in the token admin registry in sepolia
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken),address(arbSepoliaPool));
vm.stopPrank();
}
}