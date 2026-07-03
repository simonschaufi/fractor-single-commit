# fractor-single-commit

Commit each applied Fractor rule as a single commit 

## Usage

Dry run to see which rules will be applied:

```bash
./fractor-single-commit.sh -n
```

To finally execute the migrations run:

```bash
./fractor-single-commit.sh
```

Run it with an optional git commit message prefix:

```bash
fractor-single-commit.sh "[UPGRADE] "
```

It will then create a single git commit for each Fractor rule.


## Commit messages

`fractor-single-commit.sh` expects a commit message text file for each rule in the `fractor-messages/` directory.

If such a file does not exist, it will print the expected file name and stop processing. You can then enter the commit message yourself and it will be created.


## Environment variables

- `$FRACTOR_PATH` Use the path given in this variable instead of `vendor/bin/fractor`.
- `$FRACTOR_CONFIG_PATH` Use the path to the rector config file given in this variable instead of `./fractor.php`.

## Dependencies

- `fractor` v0.5.7 or later
- `jq`
