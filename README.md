# <h1 align="center">Rio Vesting Escrow</h1>

A modified version of [Lido Vesting Escrow](https://github.com/lidofinance/lido-vesting-escrow) contracts with following changes:

- Conversion to Solidity v0.8
- Uses minimal proxies with immutable args
- Adds support for OpenZeppelin governance contracts
- Allows full revocation to be disabled after escrow deployment
- Allows the escrow deployer to provide initial delegate information

## Contract Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
