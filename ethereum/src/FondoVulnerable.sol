// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title FondoVulnerable - Ejemplo minimo de DoS por gas
/// @notice Si un atacante llena el array `participantes`, el gas utilizado supera
///         el maximo por bloque y los fondos quedan congelados.
contract FondoVulnerable {
    address public immutable organizador;
    address[] public participantes;
    mapping(address => uint256) public aportes;

    error MontoCero();
    error SoloOrganizador();
    error FalloEnvio(address destinatario);

    event Participacion(address indexed cuenta, uint256 monto);
    event Reembolso(address indexed cuenta, uint256 monto);

    constructor() {
        organizador = msg.sender;
    }

    // Registra el aporte de ETH de quien llama.
    function participar() external payable {
        if (msg.value == 0) revert MontoCero();

        if (aportes[msg.sender] == 0) {
            participantes.push(msg.sender);
        }
        aportes[msg.sender] += msg.value;

        emit Participacion(msg.sender, msg.value);
    }

    // Devuelve todos los aportes recorriendo `participantes`.
    // Vulnerable a DoS por gas: el costo escala con el largo del array, puede superar el limite por bloque.
    function reembolsarTodos() external {
        if (msg.sender != organizador) revert SoloOrganizador();

        uint256 total = participantes.length;
        for (uint256 i = 0; i < total; i++) {
            address cuenta = participantes[i];
            uint256 monto = aportes[cuenta];
            if (monto > 0) {
                aportes[cuenta] = 0;
                (bool ok, ) = cuenta.call{value: monto}("");
                if (!ok) revert FalloEnvio(cuenta);
                emit Reembolso(cuenta, monto);
            }
        }
    }

    // Cantidad de direcciones registradas en el array.
    function cantidadParticipantes() external view returns (uint256) {
        return participantes.length;
    }
}
