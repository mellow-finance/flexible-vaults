# Flexible (Core) Vaults

## Documentation

For a detailed explanation of how the protocol works, see the [documentation](https://www.notion.so/mellowprotocol/Flexible-Vaults-Architecture-22f02ad86276803c8fdfc694a0036d98).

Documentation per each contract:

- [Factories](https://www.notion.so/mellowprotocol/factories-23002ad862768043bf01ea94bf02272f)
- [Hooks](https://www.notion.so/mellowprotocol/hooks-23002ad862768087b602c47e816b0911)
- [Libraries](https://www.notion.so/mellowprotocol/libraries-23002ad862768013af26dae354f16651)
- [Managers](https://www.notion.so/mellowprotocol/managers-23002ad86276806bb3a9fca523807c47)
- [Modules](https://www.notion.so/mellowprotocol/Modules-23002ad8627680179696cfbe532a236d)
- [Oracles](https://www.notion.so/mellowprotocol/oracles-23002ad86276803e85dcfc6b51084f3a)
- [Permissions](https://www.notion.so/mellowprotocol/permissions-23002ad86276802b8a94ebfeee75a53d)
- [Queues](https://www.notion.so/mellowprotocol/queues-23002ad8627680c18e29ec3fa393f004)
- [Strategies](https://www.notion.so/mellowprotocol/strategies-out-of-scope-23002ad8627680a6878ef9cf95118ab1)
- [Vaults](https://www.notion.so/mellowprotocol/vaults-23002ad862768036a1e3ef0574f34def)

## Testing

### Prerequisites

- The `forge` command-line tool
- The `yarn` package manager (optional)
- An Ethereum mainnet RPC endpoint

### Running tests

1. Add the `ETH_RPC` environment variable to the `.env` file in the repository root.
2. Run the following command:

    ```bash
    yarn test
    ```

    Or run the `forge` command directly (see `package.json`):

    ```bash
    forge test --fork-url $ETH_RPC ...
    ```

## Licensing

The license for every contract is the Business Source License 1.1 (`BUSL-1.1`). See the [`LICENSE`](./LICENSES/LICENSE) file.
