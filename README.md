# Trabajo Final — Introducción a la Programación y Análisis de Smart Contracts (UBA DC-FCEN)

Repositorio del Trabajo Final (**"Explicá una vulnerabilidad"**), deadline **1/12** (entrevistas desde el **10/12**).

## Par asignado

- **Ethereum — E3 · DoS por gas:** un loop sin límite sobre una colección que crece indefinidamente (o un pago en loop a una dirección que revierte) excede el gas del bloque o bloquea la operación para todos los usuarios. Patrón de mitigación: *pull over push* / acotación.
- **Cardano — C1 · Missing UTxO authentication:** un validator lee un UTXO de referencia o estado (ej. oráculo) confiando únicamente en la dirección del script, sin exigir un token de autenticación acuñado por el protocolo; cualquiera puede plantar un UTXO propio con un datum válido pero falso.

## Entregables

1. **Documento breve** (2 a 3 páginas, en `docs/`).
2. **Repositorio con código que compila y pasa tests:** `ethereum/` pasa `forge test` y `cardano/` pasa `aiken check`.
3. **Presentación** de ~10 minutos mostrando el código y las herramientas corriendo en vivo.

## Estructura del repositorio

- `ethereum/`: contratos en Solidity (`src/`), tests de Foundry (`test/`), verificación simbólica (`test/halmos/`), configuración `foundry.toml` / `halmos.toml` y submódulo `lib/forge-std`.
- `cardano/`: validators y tests en Aiken (`validators/`), helpers (`lib/`) y proyecto `aiken.toml` (Plutus v3, `stdlib v3.1.0`, `fuzz v2.2.0`).
- `docs/`: documento del informe y material de presentación.

## Comandos con Podman (`curso-sc:amd64`)

Ejecutar desde la raíz del repositorio en Ubuntu WSL 2:

```bash
# Ethereum: tests unitarios, PoC y fix
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/ethereum curso-sc:amd64 forge test

# Ethereum: reporte de gas (antes vs. después del fix)
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/ethereum curso-sc:amd64 forge test --gas-report

# Ethereum: análisis estático con Slither (antes vs. después del fix)
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/ethereum curso-sc:amd64 slither src/

# Ethereum: verificación simbólica con Halmos (opcional / propiedades)
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/ethereum curso-sc:amd64 halmos

# Cardano: tests unitarios, property tests y ExUnits
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/cardano curso-sc:amd64 aiken check

# Cardano: compilación del blueprint (plutus.json)
podman run --rm --userns=keep-id -v "$PWD":/curso -w /curso/cardano curso-sc:amd64 aiken build
```

## Checklist de la consigna (para E3 y C1)

1. [ ] **Qué es:** explicación clara y simple para no especialistas.
2. [ ] **Por qué existe en ese modelo:** característica del modelo de ejecución (EVM / account-based vs. EUTXO) que la hace posible.
3. [ ] **Ejemplo mínimo:** código propio mínimo que exhibe el problema y compila (`ethereum/src/`, `cardano/validators/`).
4. [ ] **Test que la demuestra:** test en Foundry (Clase 7: explota / falla) y en Aiken (Clase 9: aprueba una tx inválida o falla propiedad) sin describir de palabra sino ejecutando.
5. [ ] **El fix y su impacto:** código corregido, análisis de si prohíbe casos de uso legítimos y medición real de costo (gas / ExUnits) invirtiendo el resultado del test del punto 4.
6. [ ] **Lectura real de herramientas (antes y después del fix):**
   - E3: `slither` sobre el contrato vulnerable y el corregido (triage de detectores de loops, severidades y ruido).
   - C1: property tests en Aiken y checklist de seguridad de la Clase 8 sobre `validators/`.
7. [ ] **¿Tiene análogo en el otro modelo?:** análisis argumentado de si existe o cómo cambia en el otro modelo (EUTXO para E3; EVM/accounts para C1).
