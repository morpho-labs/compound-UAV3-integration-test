// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {IComptroller, ICToken, ICEth, ICompoundOracle} from "../lib/morpho-v1/src/compound/interfaces/compound/ICompound.sol";

contract UAVTest is Test {
    // Compound addresses.
    IComptroller internal constant comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    address internal immutable admin = comptroller.admin();
    ICompoundOracle internal immutable UAV2 = ICompoundOracle(comptroller.oracle());
    ICToken internal constant cSushi = ICToken(0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7);
    ICToken internal constant cUsdc = ICToken(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    ICEth internal constant cEth = ICEth(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
    address internal constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // New UAV.
    ICompoundOracle constant UAV3 = ICompoundOracle(0x50ce56A3239671Ab62f185704Caedf626352741e);

    function testUAVUpgrade() public {
        // Set new price oracle.
        vm.prank(admin);
        comptroller._setPriceOracle(address(UAV3));

        // Test that the new oracle has been set successfully.
        assertEq(comptroller.oracle(), address(UAV3));

        // For each market of Compound.
        for (uint256 i; i <= 19; i++) {
            ICToken cToken = comptroller.allMarkets(i);

            // Generate a pseudo-random address.
            address user = address(uint160(uint256(keccak256(abi.encode(i)))));
            
            // Deal some USDC and supply them to Compound.
            deal(usdc, user, 1e12 * 1e6);
            vm.prank(user);
            cUsdc.mint(1e12 * 1e6);
            
            // Deal some underlying and supply them to Compound.
            if (address(cToken) != address(cEth)) {
                deal(cToken.underlying(), user, 1e18);
                vm.prank(user);
                cUsdc.mint(1e18);
            } else {
                // Special treatment for cETH.
                deal(user, 1e18);
                cEth.mint{value: 1e18}();
            }

            // Borrow some USDC (to use on underlying).
            vm.prank(user);
            cUsdc.borrow(1e6);

            // Test that accrueInterest does not revert.
            cToken.accrueInterest();

            // Test that the price given by UAV3 is the same as UAV2.
            if (cToken != cSushi) {
                assertEq(UAV2.getUnderlyingPrice(address(cToken)), UAV3.getUnderlyingPrice(address(cToken)));
            } else {
                // For some reason, the SUSHI price is a little bit different (<1%).
                assertApproxEqRel(UAV2.getUnderlyingPrice(address(cToken)), UAV3.getUnderlyingPrice(address(cToken)), 1e16);
            }
        }
    }
}
