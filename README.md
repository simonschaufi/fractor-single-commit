# rector-single-commit
Commit each applied TYPO3 Rector rule as a single commit 

Example output
--------------

`git log --oneline` after running this tool::

```
0260f7de [UPGRADE] Reconfigure ext_emconf.php files
86d8a5f7 [UPGRADE] Add "#[\Override]" attribute to overridden methods
152c9e53 [UPGRADE] Decorate read-only properties with "readonly" attribute
3b2a47d3 [UPGRADE] Change "null" to empty string for strictly defined function arguments
639210c4 [UPGRADE] Change switch() to match()
16f4f02b [UPGRADE] Replace strpos() !== false and strstr() with str_contains()
33bbffad [UPGRADE] Convert substr() to str_starts_with()
51ce15fe [UPGRADE] Convert simple property initialization to constructor promotion
19dabac3 [UPGRADE] Remove unused variable in catch block
f4e58f07 [UPGRADE] Move optional parameters after required ones in method signatures
f2707863 [UPGRADE] Update php version in rector config
bf663a23 [UPGRADE] Change typo3-rector extension constraints
```

## Usage

Dry run to see which rules will be applied:

```bash
./rector-single-commit.sh -n
```

To finally execute the migrations run:

```bash
./rector-single-commit.sh
```

Run it with an optional git commit message prefix:

```bash
rector-single-commit.sh "[UPGRADE] "
```

It will then create a single git commit for each rector rule.


## Commit messages

`rector-single-commit.sh` expects a commit message text file for each rule in the `rector-messages/` directory.

If such a file does not exist, it will print the expected file name and stop processing. You can then enter the commit message yourself and it will be created.

The find a rule tool on rector helps to get a short description for a given rule.


Environment variables
---------------------

- `$RECTOR_PATH` Use the path given in this variable instead of `vendor/bin/rector`.
- `RECTOR_CONFIG_PATH` Use the path to the rector config file given in this variable instead of `./rector.php`.
- `$ECS_PATH` Use the path given in this variable instead of `vendor/bin/ecs`.
- `ECS_CONFIG_PATH` Use the path to the ecs config file given in this variable instead of `./ecs.php`.
- `$PHP_CS_FIXER_PATH` Use the path given in this variable instead of `vendor/bin/php-cs-fixer`.
- `PHP_CS_FIXER_CONFIG_PATH` Use the path to the ecs config file given in this variable instead of `./.php-cs-fixer.dist.php`.

The script tries to look for ECS first. If it not found, then the script tries to look for PHP-CS-Fixer. If both don't exist, it will print an error.

## Dependencies

- `rector` 2.0 or later
- `jq`
- `ecs` or `php-cs-fixer`
