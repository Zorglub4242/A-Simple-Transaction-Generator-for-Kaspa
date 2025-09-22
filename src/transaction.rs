use crate::config::Config;
use crate::error::Result;
use kaspa_addresses::Address;
use kaspa_consensus_core::{
    constants::TX_VERSION,
    sign::sign,
    subnets::SUBNETWORK_ID_NATIVE,
    tx::{
        MutableTransaction, Transaction, TransactionInput, TransactionOutput,
        TransactionOutpoint, UtxoEntry as CoreUtxoEntry,
    },
};
use kaspa_txscript::pay_to_address_script;
use secp256k1::Keypair;
use tracing::trace;

pub fn estimated_mass(_num_inputs: usize, _num_outputs: u64) -> u64 {
    // TODO: Implement more accurate mass estimation
    1700
}

pub fn calculate_fee(config: &Config, num_inputs: usize, num_outputs: u64, is_splitting: bool) -> u64 {
    let fee_rate = if is_splitting {
        config.fees.splitting_fee_rate
    } else {
        config.fees.base_fee_rate
    };
    fee_rate * estimated_mass(num_inputs, num_outputs)
}

pub fn create_splitting_transaction(
    keypair: &Keypair,
    utxo: &(TransactionOutpoint, CoreUtxoEntry),
    amount_per_output: u64,
    num_target_outputs: usize,
    change_value: u64,
    address: &Address,
    min_change: u64,
) -> Result<Transaction> {
    let script_public_key = pay_to_address_script(address);

    let inputs = vec![TransactionInput {
        previous_outpoint: utxo.0,
        signature_script: vec![],
        sequence: 0,
        sig_op_count: 1,
    }];

    let mut outputs = Vec::with_capacity(num_target_outputs + 1);

    // Add target outputs
    for _ in 0..num_target_outputs {
        outputs.push(TransactionOutput {
            value: amount_per_output,
            script_public_key: script_public_key.clone(),
        });
    }

    // Add change output if significant
    if change_value >= min_change {
        outputs.push(TransactionOutput {
            value: change_value,
            script_public_key: script_public_key.clone(),
        });
    }

    let unsigned_tx = Transaction::new(
        TX_VERSION,
        inputs,
        outputs,
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );

    let signed_tx = sign(
        MutableTransaction::with_entries(unsigned_tx, vec![utxo.1.clone()]),
        keypair.clone(),
    );

    trace!(
        "Created splitting transaction: {} outputs, change: {} sompi",
        num_target_outputs,
        if change_value >= min_change { change_value } else { 0 }
    );

    Ok(signed_tx.tx)
}

pub fn create_spam_transaction(
    keypair: &Keypair,
    input_outpoint: TransactionOutpoint,
    input_entry: CoreUtxoEntry,
    output_amount: u64,
    address: &Address,
) -> Result<Transaction> {
    let script_public_key = pay_to_address_script(address);

    let inputs = vec![TransactionInput {
        previous_outpoint: input_outpoint,
        signature_script: vec![],
        sequence: 0,
        sig_op_count: 1,
    }];

    let outputs = vec![TransactionOutput {
        value: output_amount,
        script_public_key,
    }];

    let unsigned_tx = Transaction::new(
        TX_VERSION,
        inputs,
        outputs,
        0,
        SUBNETWORK_ID_NATIVE,
        0,
        vec![],
    );

    let signed_tx = sign(
        MutableTransaction::with_entries(unsigned_tx, vec![input_entry]),
        keypair.clone(),
    );

    Ok(signed_tx.tx)
}