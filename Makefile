# Echidna
echidna:
	echidna test/invariants/Tester.t.sol --contract Tester --config ./test/invariants/_config/echidna_config.yaml --corpus-dir ./test/invariants/_corpus/echidna/default/_data/corpus

echidna-assert:
	echidna test/invariants/Tester.t.sol --test-mode assertion --contract Tester --config ./test/invariants/_config/echidna_config.yaml --corpus-dir ./test/invariants/_corpus/echidna/default/_data/corpus

# Medusa
medusa:
	medusa fuzz