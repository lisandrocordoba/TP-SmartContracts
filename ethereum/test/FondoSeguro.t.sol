// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/FondoSeguro.sol";

contract FondoSeguroTest is Test {
    uint256 constant LIMITE_GAS_BLOQUE = 30_000_000;
    uint256 constant CUENTAS_ATACANTE = 4_000;

    FondoSeguro fondo;
    address alice = makeAddr("alice");

    function setUp() public {
        fondo = new FondoSeguro();
    }

    function test_RetiroIndividualNoFallaPorDoS() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        fondo.participar{value: 1 ether}();

        for (uint256 i = 0; i < CUENTAS_ATACANTE; i++) {
            address cuenta = address(uint160(i + 1_000));
            vm.deal(cuenta, 1 ether);
            vm.prank(cuenta);
            fondo.participar{value: 1 wei}();
        }

        assertEq(address(fondo).balance, 1 ether + CUENTAS_ATACANTE * 1 wei);
        uint256 balanceContratoAntes = address(fondo).balance;

        vm.prank(alice);
        fondo.retirar{gas: LIMITE_GAS_BLOQUE}();

        assertEq(alice.balance, 1 ether);
        assertEq(fondo.aportes(alice), 0);
        assertEq(address(fondo).balance, balanceContratoAntes - 1 ether);
    }
}
