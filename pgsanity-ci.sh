#!/bin/bash

# Run the ecpg linter on select hugsql files
#
# The trick is to replace all the hug variables with strings (via sed) so
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
    # Detect and replace hug variables
    # TODO update this to be the same as logic in huglint script
    if ! ( sed -r "s/([^:])((:v\*)?:[-a-z?]+)/\1'\2--\3--XXXXX'/g" $f | ecpg )
    then echo "ecpg failed linting of $f"
         unset passing
    fi
done

if [[ -z $passing ]]
then echo 'ecpg detected problems'
     exit 1
else echo 'ecpg passed all checks'
fi
