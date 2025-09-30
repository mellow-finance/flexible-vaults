// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library ParameterLibrary {
    struct Parameter {
        string name;
        string value;
    }

    function build(string memory caller, string memory target, string memory value)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](3);
        result[0] = Parameter("caller", caller);
        result[1] = Parameter("target", target);
        result[2] = Parameter("value", value);
    }

    function build(string memory name, string memory allowedValue) internal pure returns (Parameter[] memory result) {
        return add(result, name, allowedValue);
    }

    function buildAny(string memory name) internal pure returns (Parameter[] memory result) {
        return add(result, name, "any");
    }

    function add(Parameter[] memory p, string memory name, string memory allowedValue)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](p.length + 1);
        for (uint256 i = 0; i < p.length; i++) {
            result[i] = p[i];
        }
        result[p.length] = Parameter(name, allowedValue);
    }

    function add2(string memory name1, string memory value1, string memory name2, string memory value2)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](2);
        result[0] = Parameter(name1, value1);
        result[1] = Parameter(name2, value2);
    }

    function add2(
        Parameter[] memory p,
        string memory name1,
        string memory value1,
        string memory name2,
        string memory value2
    ) internal pure returns (Parameter[] memory result) {
        result = new Parameter[](p.length + 2);
        for (uint256 i = 0; i < p.length; i++) {
            result[i] = p[i];
        }
        result[p.length] = Parameter(name1, value1);
        result[p.length + 1] = Parameter(name2, value2);
    }

    function addAny(Parameter[] memory p, string memory name) internal pure returns (Parameter[] memory) {
        return add(p, name, "any");
    }
}
