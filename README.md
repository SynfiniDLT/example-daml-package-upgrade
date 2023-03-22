# Daml Package Upgrade Example

    Copyright (c) 2023, ASX Operations Pty Ltd. All rights reserved.
    SPDX-License-Identifier: Apache-2.0

This is an example of how to perform an upgrade of a Daml package and migrate existing contracts on the ledger to the
new package version. The example shows how to batch the upgrade of many contracts into one transaction for greater
efficiency. Currently the example is limited to a single signatory template, but in future a more complex,
multi-signatory template could be added.

## Introduction

Let us say we have a template `T` from package `P` and some contract instances of `T` are created. If we then modify
any of the source code files of `P` or modify any of its dependencies, then we have created a new template `T'` within a
new package `P'`. Note, this applies even if `T'` has exactly the same schema, choices and stakeholders as the original
`T`. The Daml ledger will treat contract instances of `T` and `T'` as though they are instances of unrelated templates,
making them incompatible. The instances of `T` must be archived and corresponding instances of `T'` should be created,
as it will be impractical to deal with instances of both `T` and `T'` on the ledger. This project provides sample Daml
code which performs the upgrade.

Note that the incompatibility of `T` and `T'` is by design: all contract stakeholders should know exactly what the (codified) terms are of the contract they are interacting with. Any changes to the package or its dependencies could
modify these terms.

## Project Structure

The project is divided into separate Daml packages within each of these directories:

- `v1`: Version 1 of the sample Daml model.
- `v2`: Version 2 of the sample Daml model.
- `upgrade`: Daml model which imports both versions of the Daml model and has a choice to upgrade contract instances.
- `scripts`: Daml scripts which can populate the ledger with test contracts and execute the upgrade of the contracts.
- `test`: Unit tests to sanity check the scripts are working as expected.

## Build

Run the following to build all of the DAR files. They will be stored under the `.build` directory.

```bash
make build
```

To run the unit tests:

```bash
make test
```

To clean all build outputs:

```bash
make clean
```

## How it works

In the v1 Daml model there are two basic, single-signatory
[templates](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/v1/src/Synfini/Examples/Customer.daml).
Of these, the `Customer` template uses a
[contract key](https://docs.daml.com/daml/reference/contract-keys.html) to uniquely identifiy the customer, whereas the
`CustomerWithoutKey` template does not. In v2, the SDK version is upgraded and a new field is added to the
[templates](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/v2/src/Synfini/Examples/Customer.daml).
Both the v1 and v2 packages are used as data dependencies by the upgade package in its
[daml.yaml](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/upgrade/daml.yaml) file. The upgrade
package has a single,
[template](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/upgrade/src/Synfini/Examples/Customer/Upgrade.daml)
with non-consuming choices to upgrade the v1 contracts in batch. The daml.yaml file renames the v1 and v2 packages so
that module/template name collisions do not occur when importing. The `CustomerUpgrade_BatchUpgrade` choice first
fetches each contract by the supplied key, and creates an instance of the upgraded template using the contract arguments
of the fetched contract, while also adding an additional field. It does this for multiple contracts in one transaction.
By upgrading multiple contracts in one Daml transaction we can significantly speed up the upgrade process compared to
upgrading one contract per transaction. The `CustomerUpgrade_BatchUpgradeWithoutKey` choice is very similiar but instead
fetches the contracts by ID rather than by key.

The scripts package contains
[utility templates and Daml scripts](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/scripts/src/Synfini/Examples/Customer/BulkScripts.daml)
to generate some v1 contract instances, and also upgrade the generate instances.

Here is the dependency tree of the Daml packages:

![alt text](https://github.com/SynfiniDLT/example-daml-package-upgrade/blob/main/images/dependency-tree.png?raw=true)

In general, splitting a Daml application into separate packages like this helps to make it easier to modify one piece of
code without affecting the package ID of another part of the codebase, reducing the chance of needing to perform package
upgrades.

## Running the scripts

Make sure to build the DAR files first, as described previously. Then, upload the DAR file
`.build/synfini-examples-package-upgrade-scripts.dar` to the ledger. This can be done through the daml assistant:

```bash
daml ledger upload-dar
  --host <LEDGER HOST> \
  --port <LEDGER PORT> \
  --access-token-file <YOUR TOKEN FILE> \ # Remove this if the ledger does not have authentication turned on
  --tls \ # Remove this if the ledger is using plaintext
  .build/synfini-examples-package-upgrade-scripts.dar
```

### Upgrade of keyed contracts

You can generate the `Customer` contracts by first creating a JSON file with the following structure:

```json
{
  "operator": "Alice",
  "numContracts": 1000,
  "batchSize": 500,
  "entropy": "abc123"
}
```

Where `operator` is the single signatory for the contracts. `numContracts` contracts will be created in one or more
transactions, each of which creates `batchSize` contracts. The contract keys are prefixed with the value of `entropy` so
you can run it again with a different value of `entropy` without getting errors from duplicate contract keys.

You can then run the script, making sure to set the `--input-file` option to the path of the JSON file. You can refer
to `daml script --help` for more information on the other options. The exact options will depend on the configuration of
the ledger you are using. This is an example of how to use an input file to a Daml script. In this case, the JSON object
is converted into a Daml record.

```bash
daml script \
  --dar .build/synfini-examples-package-upgrade-scripts.dar \
  --script-name Synfini.Examples.Customer.BulkScripts:generateBulk \
  --ledger-host <LEDGER HOST> \
  --ledger-port <LEDGER PORT> \
  --input-file generate-input.json \
  --access-token-file <YOUR TOKEN FILE> \ # Remove this if the ledger does not have authentication turned on
  --tls # Remove this if the ledger is using plaintext
```

After running the above script you can run the upgrade process. You can copy the JSON file used for the contract
generation script, and modify the batch size if required. Within each transaction, `batchSize` contracts will be
upgraded. It will only upgrade contracts generated using the `entropy` specified in the JSON file. You can run the
upgrade script using:

```bash
daml script \
  --dar .build/synfini-examples-package-upgrade-scripts.dar \
  --script-name Synfini.Examples.Customer.BulkScripts:upgradeBulk \
  --ledger-host <LEDGER HOST> \
  --ledger-port <LEDGER PORT> \
  --input-file upgrade-input.json \
  --access-token-file <YOUR TOKEN FILE> \ # Remove this if the ledger does not have authentication turned on
  --tls # Remove this if the ledger is using plaintext
```

### Upgrade of keyless contracts

Similiar to above, you can create another input JSON file to generate the `CustomerWithoutKey` contracts.

```json
{
  "operator": "Alice",
  "numContracts": 1000,
  "batchSize": 500,
  "outputBatchSize": 100
}
```

Then, we can run another script from the same DAR file. We also need to specify an `--output-file` option. An output
file will be generated by the script, which will act as the input file for the upgrade script. The output file will also
be a JSON object, containing a list of contract IDs that were generated and the intended batch size of the upgrade
(controlled by the `outputBatchSize` parameter shown above).

```bash
daml script \
  --dar .build/synfini-examples-package-upgrade-scripts.dar \
  --script-name Synfini.Examples.Customer.BulkScripts:generateBulkWithoutKey \
  --ledger-host <LEDGER HOST> \
  --ledger-port <LEDGER PORT> \
  --input-file generate-input-without-key.json \
  --output-file upgrade-input-without-key.json \
  --access-token-file <YOUR TOKEN FILE> \ # Remove this if the ledger does not have authentication turned on
  --tls # Remove this if the ledger is using plaintext
```

Finally, we can run the upgrade:

```bash
daml script \
  --dar .build/synfini-examples-package-upgrade-scripts.dar \
  --script-name Synfini.Examples.Customer.BulkScripts:upgradeBulkWithoutKey \
  --ledger-host <LEDGER HOST> \
  --ledger-port <LEDGER PORT> \
  --input-file upgrade-input-without-key.json \
  --access-token-file <YOUR TOKEN FILE> \ # Remove this if the ledger does not have authentication turned on
  --tls # Remove this if the ledger is using plaintext
```

## Limitations

The example template only uses one signatory, but in practice there could be multiple signatories. In such cases we
would need to create a propose-accept workflow for each set of signatories used in the application. An acceptance
contract, signed by a set of signatories, could be used to perform a batch upgrade of all contracts which use that set
of signatories.
