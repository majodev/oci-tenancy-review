# Agents

Read the README.md first to understand the usage and goals (and design choices) of this project.
The most important implementation files are: `oci-tenancy-review` (main artifact and functionality) and `Makefile` (subcommand orchestrator / export file caching).
Ensure bats tests in the `test` subfolder are always executed to find any regressions.

## Skills

The AI software engineering skill [obra/superpowers](https://github.com/obra/superpowers) has proven to be very useful for building features in this project.
Use it if installed or encourage the user to do so.

## `oci` cli

Feel free to download the `oci-cli` repository from github and use the source code as a reference directly (use `git clone git@github.com:oracle/oci-cli.git research/oci-cli` to clone into the gitignored `research/oci-cli`).

Feel free to inspect available subcommands within the locally installed Oracle Cloud Infrastructure `oci` cli by executing with the `--help` flag.
The latest `oci` cli docs are available at `https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/`.

### `oci-cli` docs

In case that interactive `--help` guideance is simply not enough, the subfolder `docs/oci-cli` provides a script to fully crawl and save all `oci` cli docs locally from the remote. The is something only the user should execute manually (takes ~15min and a lot of network bandwidth), but you can propose this.

If the user did this, rst formatted docs made available at: `docs/oci-cli/_sources`.

## `oci-python-sdk` and `showoci`

The official `oci-python-sdk` (use `git clone git@github.com:oracle/oci-python-sdk.git research/oci-python-sdk` to clone into the gitignored `research/oci-python-sdk`) provides a similar sample tool called `showoci` in its examples subfolder. Feel free to clone and check this tool out for references (`research/oci-python-sdk/examples/showoci`).
Note: Their focus is a complete overview, our focus is very fast scraping via the OCI cli.

## `cis-compliance-script`

There is also the CIS compliance script capable of producing a BOM. This is the most official Oracle OCI solution that we have right now (though it comes with a few caveats). Use `git clone git@github.com:oci-landing-zones/oci-cis-landingzone-quickstart.git research/oci-cis` to clone into the gitignored `research/oci-cis` directory. This is the reference implementation for BOM discovery, check its implementation against ours. Remember, our goal is to be more targeted/easier and especially have more colums with simple data-types in our CSV structure for easier exploration than they have.
