pragma circom 2.0.0;
include "../../../../../node_modules/circomlib/circuits/poseidon.circom";

template Circuit() {
    signal input foo;
    signal input bar;
    signal output out;

    component hasher1 = Poseidon(2);
    hasher1.inputs[0] <== foo;
    hasher1.inputs[1] <== bar;

    component hasher2 = Poseidon(1);
    hasher2.inputs[0] <== hasher1.out;
    out <== hasher2.out;
}

component main = Circuit();
