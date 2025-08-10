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
sepoliaFork = vm.createSelectFork("sepolia-eth") ; //createSelectFork for making sepoliaFork as default.
arbSepoliaFork = vm.createFork("arb-sepolia") ;

ccipLocalSimulatorFork = new CCIPLocalSimulatorFork() ;
vm.makePersistent(address(ccipLocalSimulatorFork)) ;

//1. Deploy and configure on sepolia.
sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid) ;
vm.startPrank(owner);
sepoliaToken= new RebaseToken();
vault = new Vault(IRebaseToken(address(sepoliaToken)));
sepoliaPool = new RebaseTokenPool(IERC20(sepoliaToken), address[](0), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress) ;
sepoliaToken.grantMintAndBurnRole(vault);
sepoliaToken.grantMintAndBurnRole(sepoliaPool);
RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken)) ;
TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken),address(sepoliaPool));
vm.stopPrank();


//2. Deploy and configure on arb-sepolia.
vm.selectFork(arbSepoliaFork);
arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid) ;
vm.startPrank(owner);
arbSepoliaToken = new RebaseToken();
arbSepoliaPool = new RebaseTokenPool(IERC20(arbSepoliaPool), address[](0), arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress) ;
arbSepoliaToken.grantMintAndBurnRole(arbSepoliaPool);
arbSepoliaToken.grantMintAndBurnRole(vault);
RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(arbSepoliaToken)) ;
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(arbSepoliaToken),address(arbSepoliaPool));
vm.stopPrank();

}
}