methods {
    function OP_DEPOSIT() external returns (uint32) envfree;
    function OP_MINT() external returns (uint32) envfree; 
}
rule bitmasks_disjoint {
    assert (OP_DEPOSIT() & OP_MINT()) == 0;
}