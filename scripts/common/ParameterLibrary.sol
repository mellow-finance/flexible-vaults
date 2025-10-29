// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

library ParameterLibrary {
    struct Parameter {
        string name;
        string value;
        bool isNestedJson;
    }

    function build(string memory caller, string memory target, string memory value)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](3);
        result[0] = Parameter("caller", caller, false);
        result[1] = Parameter("target", target, false);
        result[2] = Parameter("value", value, false);
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
        result[p.length] = Parameter(name, allowedValue, false);
    }

    function add2(string memory name1, string memory value1, string memory name2, string memory value2)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](2);
        result[0] = Parameter(name1, value1, false);
        result[1] = Parameter(name2, value2, false);
    }

    function addJson(Parameter[] memory p, string memory name, string memory allowedValue)
        internal
        pure
        returns (Parameter[] memory result)
    {
        result = new Parameter[](p.length + 1);
        for (uint256 i = 0; i < p.length; i++) {
            result[i] = p[i];
        }
        result[p.length] = Parameter(name, allowedValue, true);
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
        result[p.length] = Parameter(name1, value1, false);
        result[p.length + 1] = Parameter(name2, value2, false);
    }

    function addAny(Parameter[] memory p, string memory name) internal pure returns (Parameter[] memory) {
        return add(p, name, "any");
    }

    function addAnyArray(Parameter[] memory p, string memory name, uint256 n)
        internal
        pure
        returns (Parameter[] memory)
    {
        return add(p, name, anyArray(n));
    }

    function anyArray(uint256 n) internal pure returns (string memory result) {
        for (uint256 i = 0; i < n; i++) {
            result = (i == 0 ? "any" : string(abi.encodePacked(result, ", any")));
        }
        result = string(abi.encodePacked("[", result, "]"));
    }

    function buildERC20(string memory to) internal pure returns (Parameter[] memory) {
        return add2("to", to, "amount", "any");
    }
}
