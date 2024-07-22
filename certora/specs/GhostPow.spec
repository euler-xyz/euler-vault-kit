/// @doc Ghost power function that incorporates mathematical pure x^y axioms.
/// @warning Some of these axioms might be false, depending on the Solidity implementation
/// The user must bear in mind that equality-like axioms can be violated because of rounding errors.
// _ghostPow summarizes RPow.rpow, or:
// _ghostPow(x, y, scalar) = scalar * x^y
ghost _ghostPow(uint256, uint256, uint256) returns mathint {
    /// x^0 = 1
    axiom forall uint256 x. forall uint256 base. _ghostPow(x, 0, base) == to_mathint(base);
    /// 0^x = 0
    axiom forall uint256 y. forall uint256 base.  _ghostPow(0, y, base) == 0;
    /// x^1 = x
    axiom forall uint256 x. forall uint256 base. _ghostPow(x, base, base) == to_mathint(x);
    /// 1^y = 1
    axiom forall uint256 y. forall uint256 base. _ghostPow(base, y, base) == to_mathint(base);

    /// I. x > 1 && y1 > y2 => x^y1 > x^y2
    /// II. x < 1 && y1 > y2 => x^y1 < x^y2
    axiom forall uint256 x. forall uint256 y1. forall uint256 y2. forall uint256 base.
        x >= base && y1 > y2 => _ghostPow(x, y1, base) >= _ghostPow(x, y2, base);
    axiom forall uint256 x. forall uint256 y1. forall uint256 y2. forall uint256 base.
        x < base && y1 > y2 => (_ghostPow(x, y1, base) <= _ghostPow(x, y2, base) && _ghostPow(x,y2, base) <= to_mathint(base));
    axiom forall uint256 x. forall uint256 y. forall uint256 base.
        x < base && y > base => (_ghostPow(x, y, base) <= to_mathint(x));
    axiom forall uint256 x. forall uint256 y. forall uint256 base.
        x < base && y <= base => (_ghostPow(x, y, base) >= to_mathint(x));
    axiom forall uint256 x. forall uint256 y. forall uint256 base.
        x >= base && y > base => (_ghostPow(x, y, base) >= to_mathint(x));
    axiom forall uint256 x. forall uint256 y. forall uint256 base.
        x >= base && y <= base => (_ghostPow(x, y, base) <= to_mathint(x));
    /// x1 > x2 && y > 0 => x1^y > x2^y
    axiom forall uint256 x1. forall uint256 x2. forall uint256 y. forall uint256 base.
        x1 > x2 => _ghostPow(x1, y, base) >= _ghostPow(x2, y, base);
    
    /* Additional axioms - potentially unsafe
    /// x^y * x^(1-y) == x -> 0.01% relative error
    axiom forall uint256 x. forall uint256 y. forall uint256 z. 
        (0 <= y && y <= ONE18() &&  z + y == to_mathint(ONE18())) =>
        relativeErrorBound(_ghostPow(x, y) * _ghostPow(x, z), x * ONE18(), ONE18() / 10000);
    
    /// (x^y)^(1/y) == x -> 1% relative error
    axiom forall uint256 x. forall uint256 y. forall uint256 z. 
        (0 <= y && y <= ONE18() &&  z * y == ONE18()*ONE18() ) =>
        relativeErrorBound(_ghostPow(_ghostPow(x, y), z), x, ONE18() / 100);
    */
}

function CVLPow(uint256 x, uint256 y, uint256 base) returns (uint256, bool) {
    if (y == 0) {return (base, false);}
    if (x == 0) {return (0, false);}
    mathint res = _ghostPow(x, y, base);
    if (res > max_uint256) {
        uint256 havoced;
        return (havoced, true);
    }
    return (require_uint256(res), false);
}