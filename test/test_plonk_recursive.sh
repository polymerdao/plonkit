#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR=$DIR/".."
RECTEST_DIR=$DIR"/circuits/recursive_test"
SETUP_DIR=$REPO_DIR"/keys/setup"
SETUP_MK=$SETUP_DIR"/setup_2^20.key"
BIG_SETUP_MK=$SETUP_DIR"/setup_2^24.key"
DOWNLOAD_SETUP_FROM_REMOTE=false
PLONKIT_BIN=$REPO_DIR"/target/release/plonkit"
CONTRACT_TEST_DIR=$DIR"/contract/recursive"

echo "Step: build plonkit"
cargo build --release

echo "Step: universal setup"
pushd $SETUP_DIR
if ([ ! -f $SETUP_MK ] & $DOWNLOAD_SETUP_FROM_REMOTE); then
  # It is the aztec ignition trusted setup key file. Thanks to matter-labs/zksync/infrastructure/zk/src/run/run.ts
  axel -ac https://universal-setup.ams3.digitaloceanspaces.com/setup_2^${SETUP_POWER}.key -o $SETUP_MK || true
elif [ ! -f $SETUP_MK ] ; then
    $PLONKIT_BIN setup --power 20 --srs_monomial_form $SETUP_MK --overwrite
fi
if ([ ! -f $BIG_SETUP_MK ] & $DOWNLOAD_SETUP_FROM_REMOTE); then
  # It is the aztec ignition trusted setup key file. Thanks to matter-labs/zksync/infrastructure/zk/src/run/run.ts
  axel -ac https://universal-setup.ams3.digitaloceanspaces.com/setup_2^${SETUP_POWER}.key -o $BIG_SETUP_MK || true
elif [ ! -f $BIG_SETUP_MK ] ; then
    $PLONKIT_BIN setup --power 24 --srs_monomial_form $BIG_SETUP_MK --overwrite
fi
popd

echo "Step: collect old_proofs list"
OLD_PROOF_LIST=$RECTEST_DIR/old_proof_list.txt
rm $OLD_PROOF_LIST -rf
touch $OLD_PROOF_LIST
i=0
for circuit_dir in `ls $RECTEST_DIR/data`
do
  CIRCUIT_DIR=$RECTEST_DIR/data/$circuit_dir
  echo "Step: compile circuit and calculate witness"
  npx snarkit2 check $CIRCUIT_DIR --witness_type bin

  echo "Step: export verification key"
  $PLONKIT_BIN export-verification-key -m $SETUP_MK -c $CIRCUIT_DIR/circuit.r1cs -v $CIRCUIT_DIR/vk.bin --overwrite

  echo "Step: generate proof"
  $PLONKIT_BIN prove -m $SETUP_MK -c $CIRCUIT_DIR/circuit.r1cs -w $CIRCUIT_DIR/witness.wtns -p $CIRCUIT_DIR/proof.bin -j $CIRCUIT_DIR/proof.json -i $CIRCUIT_DIR/public.json -t rescue --overwrite

  echo "Step: verify proof"
  $PLONKIT_BIN verify -p $CIRCUIT_DIR/proof.bin -v $CIRCUIT_DIR/vk.bin -t rescue

  echo $CIRCUIT_DIR/proof.bin >> $OLD_PROOF_LIST
  echo $CIRCUIT_DIR/vk.bin >> $OLD_PROOF_LIST
  let "i++"
done
cat $OLD_PROOF_LIST

#echo "Step: export recursive vk"
#time ($PLONKIT_BIN export-recursive-verification-key -c $i -i 3 -m $BIG_SETUP_MK -v $RECTEST_DIR/recursive_vk.bin --overwrite)

#echo "Step: generate recursive proof"
#time ($PLONKIT_BIN recursive-prove -m $BIG_SETUP_MK -f $OLD_PROOF_LIST -v $RECTEST_DIR/vk.bin -n $RECTEST_DIR/recursive_proof.bin -j $RECTEST_DIR/recursive_proof.json --overwrite)
#
#echo "Step: verify recursive proof"
#time ($PLONKIT_BIN recursive-verify -p $RECTEST_DIR/recursive_proof.bin -v $RECTEST_DIR/recursive_vk.bin)
#
#echo "Step: check aggregation"
#$PLONKIT_BIN check-aggregation -o $OLD_PROOF_LIST -v $RECTEST_DIR/vk.bin -n $RECTEST_DIR/recursive_proof.bin
#
#echo "Step: generate recursive verifier smart contract"
#$PLONKIT_BIN generate-recursive-verifier -o $RECTEST_DIR/vk.bin -n $RECTEST_DIR/recursive_vk.bin -i 3 -s $RECTEST_DIR/verifier.sol --overwrite #-t contrib/template.sol
#
#echo "Step: verify via smart contract"
#pushd $CONTRACT_TEST_DIR
#yarn install
#mkdir -p contracts
#cp $RECTEST_DIR/recursive_proof.json $CONTRACT_TEST_DIR/test/data/proof.json
#cp $RECTEST_DIR/verifier.sol $CONTRACT_TEST_DIR/contracts/verifier.sol
#npx hardhat test
#popd
