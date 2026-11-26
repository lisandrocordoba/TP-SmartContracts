// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title FondoSeguro - Mitigacion de DoS por gas mediante patron pull over push
/// @notice Cada participante se encarga de retirar su propio saldo

contract FondoSeguro {
    mapping(address => uint256) public aportes;

    error MontoCero();
    error SaldoCero();
    error FalloEnvio(address destinatario);

    event Participacion(address indexed cuenta, uint256 monto);
    event Retiro(address indexed cuenta, uint256 monto);

    function participar() external payable {
        if (msg.value == 0) revert MontoCero();

        aportes[msg.sender] += msg.value;

        emit Participacion(msg.sender, msg.value);
    }

    function retirar() external {
        uint256 monto = aportes[msg.sender];
        if (monto == 0) revert SaldoCero();

        aportes[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: monto}("");
        if (!ok) revert FalloEnvio(msg.sender);
        emit Retiro(msg.sender, monto);
    }
}
