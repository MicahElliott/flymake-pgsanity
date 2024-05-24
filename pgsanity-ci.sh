#!/bin/bash

# Run the pgsanity linter on select hugsql files
#
# The trick is to replace all the hugs variables with strings (via sed) so
# that it looks like valid sql.

# In case you don't want to run over all your files
whitelist=(
    resources/sql/foo-queries.sql
    # ...
)

passing=true

# for f in resources/sql/*.sql; do
for f in $whitelist; do
    echo "Linting $f"
    # Detect and replace hugs variables
    if ! ( sed -r "s/([^:])((:v\*)?:[-a-z?]+)/\1'\2--\3--XXXXX'/g" $f | pgsanity )
    then echo "pgsanity failed linting of $f"
         unset passing
    fi
done

if [[ -z $passing ]]
then echo 'pgsanity detected problems'
     exit 1
else echo 'pgsanity passed all checks'
fi
