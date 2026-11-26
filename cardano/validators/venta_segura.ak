// Misma lógica de compra que `venta_vulnerable.ak`, pero en vez de confiar 
// en la dirección del oráculo, autentica el UTXO exigiendo el NFT oficial 
// (`auth_policy`, `auth_name`) que sólo la minting policy del protocolo puede acuñar.

use aiken/collection/list
use aiken/fuzz
use cardano/address.{VerificationKey, from_script, from_verification_key}
use cardano/assets.{AssetName, PolicyId}
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

// no confía en la dirección del oráculo. busca el reference input marcado 
// con el token de autenticación (`auth_policy`, `auth_name`).
fn leer_precio_oraculo(
  reference_inputs: List<Input>,
  auth_policy: PolicyId,
  auth_name: AssetName,
) -> Option<Int> {
  when
    list.find(
      reference_inputs,
      fn(i: Input) { assets.has_nft(i.output.value, auth_policy, auth_name) },
    )
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

fn puede_comprar(
  d: Datum,
  auth_policy: PolicyId,
  auth_name: AssetName,
  tx: Transaction,
) -> Bool {
  when leer_precio_oraculo(tx.reference_inputs, auth_policy, auth_name) is {
    Some(precio) -> pago_al_vendedor(tx.outputs, d.vendedor, precio)
    None -> False
  }
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

validator venta_segura(auth_policy: PolicyId, auth_name: AssetName) {
  spend(
    datum: Option<Datum>,
    _redeemer: Void,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(d) = datum
    puede_comprar(d, auth_policy, auth_name, self)
  }

  else(_) {
    fail
  }
}

// ---------------------------------------------------------------------------
// Helpers y tests (verifican el fix, la compra legítima y ExUnits)
// ---------------------------------------------------------------------------

const vendedor_hash: ByteArray = #"a1a1"

const oracle_script_hash: ByteArray = #"00a1c1e0"

const oracle_auth_policy: PolicyId =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const oracle_auth_name: AssetName = "ORACULO_AUTH"

const precio_real: Int = 100_000_000

const min_ada: Int = 2_000_000

const tx_id: ByteArray =
  #"0000000000000000000000000000000000000000000000000000000000000000"

fn make_oracle_ref_legitimo(precio: Int) -> Input {
  Input {
    output_reference: OutputReference { transaction_id: tx_id, output_index: 0 },
    output: Output {
      address: from_script(oracle_script_hash),
      value: assets.from_lovelace(min_ada)
        |> assets.add(oracle_auth_policy, oracle_auth_name, 1), // Agrega el tóken ademas de los ADA
      datum: InlineDatum(OracleDatum { precio }),
      reference_script: None,
    },
  }
}

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

// verifica que el fix no bloquea el uso válido con
// el NFT correcto y permite medir ExUnits del camino aprobado.
test compra_legitima_pasa() {
  let tx = tx_compra(make_oracle_ref_legitimo(precio_real), precio_real)
  puede_comprar(
    Datum { vendedor: vendedor_hash },
    oracle_auth_policy,
    oracle_auth_name,
    tx,
  )
}

//  la misma tx de ataque ahora falla.
test poc_oraculo_falso_es_rechazado() {
  let tx = tx_compra(make_oracle_ref_falso(1), 1)
  !puede_comprar(
    Datum { vendedor: vendedor_hash },
    oracle_auth_policy,
    oracle_auth_name,
    tx,
  )
}

// rechazar cualquier precio falso sin NFT.
fn precio_falso_fuzzer() -> Fuzzer<Int> {
  fuzz.int_between(1, precio_real - 1)
}

test prop_oraculo_falso_es_rechazado(precio_falso via precio_falso_fuzzer()) {
  let tx = tx_compra(make_oracle_ref_falso(precio_falso), precio_falso)
  !puede_comprar(
    Datum { vendedor: vendedor_hash },
    oracle_auth_policy,
    oracle_auth_name,
    tx,
  )
}
