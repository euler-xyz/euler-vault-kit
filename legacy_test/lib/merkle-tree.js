const ethers = require('ethers');


function processDistribution(dist) {
    dist = dist.map(d => {
        return {
            account: d.account.toLowerCase(),
            token: d.token.toLowerCase(),
            claimable: d.claimable,
            leaf: ethers.utils.concat([ d.account, d.token, ethers.utils.hexZeroPad(d.claimable, 32) ]),
        };
    });

    return dist.sort((a,b) => Buffer.compare(a.leaf, b.leaf));
}

function hashLevel(level) {
    let nextLevel = [];

    for (let i = 0; i < level.length; i += 2) {
        if (i === level.length - 1) nextLevel.push(level[i]); // odd number of nodes at this level
        else nextLevel.push(ethers.utils.keccak256(ethers.utils.concat([level[i], level[i+1]].sort())));
    }

    return nextLevel;
}

function root(items) {
    if (items.length === 0) throw("can't build merkle tree with empty items");

    items = processDistribution(items);
    let level = items.map(d => ethers.utils.keccak256(d.leaf));

    while (level.length > 1) {
        level = hashLevel(level);
    }

    return level[0];
}

function proof(items, account, token) {
    account = account.toLowerCase();
    token = token.toLowerCase();

    items = processDistribution(items);
    let level = items.map(d => ethers.utils.keccak256(d.leaf));

    let origIndex = items.findIndex((i) => i.account === account && i.token == token);
    if (origIndex === -1) throw("item not found in items: " + item);

    let witnesses = [];
    let index = origIndex;

    while (level.length > 1) {
        let nextIndex = Math.floor(index / 2);

        if (nextIndex * 2 === index) { // left side
            if (index < level.length - 1) { // only if we're not the last in a level with odd number of nodes
                witnesses.push(level[index + 1]);
            }
        } else { // right side
            witnesses.push(level[index - 1]);
        }

        index = nextIndex;
        level = hashLevel(level);
    }

    return {
        item: items[origIndex],
        witnesses,
    };
}


module.exports = {
    root,
    proof,
};
